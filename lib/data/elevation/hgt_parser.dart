import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// HGT Dosyası Çözümleyici (Çevrimdışı Yükseklik Verisi)
/// SRTM tabanlı 1 derecelik karelaj (.hgt) dosyalarından yükseklik (DEM) okur.
class HgtParser {
  /// Yüklenen HGT dosyalarının bellek-içi önbelleği
  final Map<String, ByteData> _cache = {};

  /// Dosyaların bulunduğu ana dizin (örneğin `/tiles_external`)
  String? _externalDirectory;

  HgtParser();

  Future<void>? _ready;

  /// HGT dosyalarının bulunduğu dizini ilkler (bir kez; [getElevation]
  /// hazırlık bitmeden çağrılırsa bekler — eskiden sessizce null dönüyordu).
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    // Dizin bulunamazsa (izin, platform) okuyucu hata fırlatmaz: veri yok.
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final dir = await getApplicationDocumentsDirectory();
        _externalDirectory = '${dir.path}/tiles_external';
      } else {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          _externalDirectory = '${dir.path}/tiles_external';
        }
      }

      if (_externalDirectory != null) {
        final directory = Directory(_externalDirectory!);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    } catch (_) {
      _externalDirectory = null;
    }
  }

  /// Verilen enlem (lat) ve boylam (lon) için yüksekliği (metre) döner.
  /// Dosya bulunamazsa veya veri geçersizse null döner.
  Future<int?> getElevation(double lat, double lon) async {
    await init();
    if (_externalDirectory == null) return null;

    final fileName = _getFileName(lat, lon);
    final filePath = '$_externalDirectory/$fileName';

    ByteData? data = _cache[fileName];

    if (data == null) {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        data = bytes.buffer.asByteData();
      } else {
        // Fallback to embedded assets
        try {
          final assetData = await rootBundle.load('assets/tiles/$fileName');
          data = assetData;
        } catch (e) {
          return null; // Yükseklik verisi (dosya) yok
        }
      }
      _cache[fileName] = data; // Cache'e al (Performans için)
    }

    // Dosya boyutundan çözünürlüğü anla (1201x1201 SRTM3 veya 3601x3601 SRTM1)
    // 1201 * 1201 * 2 = 2884802 bytes
    // 3601 * 3601 * 2 = 25934402 bytes
    int resolution = 1201; // Varsayılan SRTM3
    if (data.lengthInBytes > 3000000) {
      resolution = 3601; // SRTM1
    }

    // Koordinatın 1x1 derecelik karelaj içindeki ondalık kısmını bul (0.0 ile 1.0 arası)
    double latFrac = lat - lat.floor();
    double lonFrac = lon - lon.floor();

    // HGT dosyalarında satırlar kuzeyden güneye (üstten alta) dizilir
    int row = ((1.0 - latFrac) * (resolution - 1)).round();
    int col = (lonFrac * (resolution - 1)).round();

    // Her piksel 2 byte (16-bit) kaplar
    int bytePos = (row * resolution + col) * 2;

    if (bytePos >= 0 && bytePos + 1 < data.lengthInBytes) {
      // Big Endian 16-bit signed integer (SRTM format standardı)
      int elevation = data.getInt16(bytePos, Endian.big);
      // Geçersiz veri (-32768) boşluklarını kontrol et
      if (elevation <= -32768) return null;
      return elevation;
    }
    return null;
  }

  /// Enlem ve boylamdan HGT dosya ismini üretir (Örn: N41E028.hgt)
  String _getFileName(double lat, double lon) {
    int latInt = lat.floor();
    int lonInt = lon.floor();

    String latStr = latInt >= 0
        ? 'N${latInt.toString().padLeft(2, '0')}'
        : 'S${latInt.abs().toString().padLeft(2, '0')}';

    String lonStr = lonInt >= 0
        ? 'E${lonInt.toString().padLeft(3, '0')}'
        : 'W${lonInt.abs().toString().padLeft(3, '0')}';

    return '$latStr$lonStr.hgt';
  }
}
