import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'dem_tile.dart';

/// Yükseklik dosyalarının klasörü: Belgeler/tiles_external (iOS), uygulamanın
/// dış depolama klasörü (Android). Bulunamazsa null (testte path_provider yok).
Future<Directory?> defaultElevationDirectory() async {
  try {
    final Directory? base;
    if (Platform.isIOS || Platform.isMacOS) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = await getExternalStorageDirectory();
    }
    if (base == null) return null;
    final dir = Directory('${base.path}/tiles_external');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  } catch (_) {
    return null;
  }
}

/// Cihazdaki bir yükseklik karesi.
class ElevationTileInfo {
  const ElevationTileInfo({
    required this.key,
    required this.fileName,
    required this.south,
    required this.west,
    required this.format,
    required this.sizeBytes,
    required this.resolutionArcSec,
    this.bundled = false,
  });

  /// "N37E037".
  final String key;
  final String fileName;
  final int south;
  final int west;
  final DemFormat format;
  final int sizeBytes;

  /// Nokta aralığı (yay saniyesi): 1 ≈ 30 m, 3 ≈ 90 m, 30 ≈ 900 m.
  final double resolutionArcSec;

  /// Uygulamayla gelen örnek (silinemez).
  final bool bundled;

  /// "SRTM 1″ (~30 m)" gibi kısa açıklama.
  String get description {
    final r = resolutionArcSec.round();
    final m = (resolutionArcSec * 30.87).round();
    final kind = format == DemFormat.hgt ? 'HGT' : 'DTED';
    return '$kind $r″ (~$m m)';
  }
}

/// Yükseklik dosyalarını listeler, içe aktarır, siler. Okuyucu
/// ([HgtParser]) aynı klasörü kullanır; değişiklikten sonra onun
/// önbelleği yenilenmeli.
class ElevationStore {
  ElevationStore({
    Future<Directory?> Function()? directory,
    Future<bool> Function(String key)? bundledExists,
    http.Client Function()? httpClient,
  }) : _directory = directory ?? defaultElevationDirectory,
       _bundledExists = bundledExists ?? _assetExists,
       _httpClient = httpClient ?? http.Client.new;

  final Future<Directory?> Function() _directory;
  final Future<bool> Function(String key) _bundledExists;
  final http.Client Function() _httpClient;

  /// Uygulamayla gelebilecek örnek kareler (`assets/tiles/<key>.hgt`, SRTM
  /// 3″). Listede yalnız uygulamada gerçekten varsa görünür: dosya depoda
  /// olmadığı için GitHub'da derlenen APK'da yoktu ama listede çıkıyordu.
  static const bundledKeys = {'N37E037'};

  static Future<bool> _assetExists(String key) async {
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      return m.listAssets().contains('assets/tiles/$key.hgt');
    } catch (_) {
      return false;
    }
  }

  /// Tek bir karenin en büyük boyutu: SRTM 1″ HGT 25,9 MB, DTED 2 ~26 MB.
  static const maxTileBytes = 32 * 1024 * 1024;

  /// İçe aktarılabilecek en büyük dosya (birçok kare içeren zip).
  static const maxFileBytes = 400 * 1024 * 1024;

  /// Zip içinde en çok kaç kare.
  static const maxZipTiles = 400;

  static const _exts = ['hgt', 'dt2', 'dt1', 'dt0'];

  static final _name = RegExp(
    r'^([NS]\d{2}[EW]\d{3})\.(hgt|dt0|dt1|dt2)$',
    caseSensitive: false,
  );

  Future<List<ElevationTileInfo>> list() async {
    final out = <ElevationTileInfo>[];
    final dir = await _directory();
    if (dir != null && await dir.exists()) {
      for (final e in dir.listSync().whereType<File>()) {
        final name = e.uri.pathSegments.last;
        final m = _name.firstMatch(name);
        if (m == null) continue;
        final info = await _info(e, name, m.group(1)!.toUpperCase());
        if (info != null) out.add(info);
      }
    }
    for (final key in bundledKeys) {
      if (out.any((t) => t.key == key)) continue;
      if (!await _bundledExists(key)) continue;
      final (s, w) = DemTile.parseKey(key)!;
      out.add(
        ElevationTileInfo(
          key: key,
          fileName: '$key.hgt',
          south: s,
          west: w,
          format: DemFormat.hgt,
          sizeBytes: 1201 * 1201 * 2,
          resolutionArcSec: 3,
          bundled: true,
        ),
      );
    }
    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  Future<ElevationTileInfo?> _info(File f, String name, String key) async {
    try {
      final size = await f.length();
      final (s, w) = DemTile.parseKey(key)!;
      if (name.toLowerCase().endsWith('.hgt')) {
        final n = math.sqrt(size / 2).round();
        if (n * n * 2 != size) return null;
        return ElevationTileInfo(
          key: key,
          fileName: name,
          south: s,
          west: w,
          format: DemFormat.hgt,
          sizeBytes: size,
          resolutionArcSec: 3600 / (n - 1),
        );
      }
      // DTED: başlıktan nokta sayısı (dosyanın tamamını okumadan).
      final raf = await f.open();
      final head = await raf.read(80);
      await raf.close();
      final rows = int.tryParse(String.fromCharCodes(head.sublist(51, 55)));
      if (rows == null || rows < 2) return null;
      return ElevationTileInfo(
        key: key,
        fileName: name,
        south: s,
        west: w,
        format: DemFormat.dted,
        sizeBytes: size,
        resolutionArcSec: 3600 / (rows - 1),
      );
    } catch (_) {
      return null;
    }
  }

  /// Bir dosyayı içe aktarır. HGT'de konum dosya adından ("N37E037…"),
  /// DTED'de başlıktan. Aynı karenin eski dosyası (başka biçim dahil)
  /// değiştirilir. Bozuksa [FormatException] (Türkçe ileti).
  Future<ElevationTileInfo> importBytes(
    Uint8List bytes,
    String originalName,
  ) async {
    final dir = await _directory();
    if (dir == null) {
      throw const FormatException('Yükseklik klasörü bulunamadı');
    }
    final lower = originalName.toLowerCase();
    final key = DemTile.parseKey(originalName);
    final tile = DemTile.parse(bytes, south: key?.$1, west: key?.$2);
    final tileKey = DemTile.keyFor(tile.south, tile.west);
    final String ext;
    if (tile.format == DemFormat.hgt) {
      ext = 'hgt';
    } else {
      final m = RegExp(r'\.dt([012])$').firstMatch(lower);
      ext = m != null
          ? 'dt${m.group(1)}'
          : tile.rows >= 3601
          ? 'dt2'
          : tile.rows >= 1201
          ? 'dt1'
          : 'dt0';
    }
    // Önce geçici ada yaz: disk dolarsa eski (çalışan) kare silinmemiş olur.
    final dest = File('${dir.path}/$tileKey.$ext');
    final part = File('${dest.path}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    }
    for (final e in _exts) {
      final old = File('${dir.path}/$tileKey.$e');
      if (e != ext && await old.exists()) await old.delete();
    }
    await part.rename(dest.path);
    return ElevationTileInfo(
      key: tileKey,
      fileName: '$tileKey.$ext',
      south: tile.south,
      west: tile.west,
      format: tile.format,
      sizeBytes: bytes.length,
      resolutionArcSec: tile.resolutionArcSec,
    );
  }

  /// Seçilen dosyayı içe aktarır: açılmış kare (.hgt / .dtN), gzip ile
  /// sıkıştırılmış kare (.hgt.gz; AWS Terrain Tiles böyle verir) ya da
  /// birçok kare içeren zip (viewfinderpanoramas, USGS). İçeriğe bakılır,
  /// uzantıya değil. Eklenen kareler; zip'te karesi olmayan dosyalar
  /// yok sayılır. Hiç kare bulunamazsa [FormatException].
  Future<List<ElevationTileInfo>> importFile(
    Uint8List bytes,
    String originalName,
  ) async {
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Dosya çok büyük (en çok 400 MB).');
    }
    if (_isGzip(bytes)) {
      final name = originalName.replaceFirst(
        RegExp(r'\.gz$', caseSensitive: false),
        '',
      );
      return [await importBytes(gunzipCapped(bytes), name)];
    }
    if (_isZip(bytes)) return _importZip(bytes);
    return [await importBytes(bytes, originalName)];
  }

  static bool _isGzip(Uint8List b) =>
      b.length > 2 && b[0] == 0x1F && b[1] == 0x8B;

  static bool _isZip(Uint8List b) =>
      b.length > 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 3 && b[3] == 4;

  /// gzip'i açar; çıktı [max]'ı aşarsa durur (kötü niyetli küçük dosya
  /// belleği şişirmesin).
  static Uint8List gunzipCapped(Uint8List data, {int max = maxTileBytes}) {
    final out = BytesBuilder(copy: false);
    final sink = gzip.decoder.startChunkedConversion(_CappedSink(out, max));
    try {
      const step = 4096;
      for (var i = 0; i < data.length; i += step) {
        sink.add(data.sublist(i, math.min(i + step, data.length)));
      }
      sink.close();
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Sıkıştırılmış dosya bozuk.');
    }
    return out.takeBytes();
  }

  Future<List<ElevationTileInfo>> _importZip(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, throwOnError: true);
    } catch (_) {
      throw const FormatException('Zip dosyası bozuk.');
    }
    final out = <ElevationTileInfo>[];
    var seen = 0;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final base = f.name.split('/').last;
      final gz = base.toLowerCase().endsWith('.gz');
      final name = gz ? base.substring(0, base.length - 3) : base;
      if (!_name.hasMatch(name)) continue;
      if (++seen > maxZipTiles) {
        throw const FormatException('Zip içinde çok fazla kare var.');
      }
      if (f.size > maxTileBytes) continue;
      final Uint8List data;
      try {
        final raw = f.readBytes();
        if (raw == null) continue;
        data = gz
            ? gunzipCapped(Uint8List.fromList(raw))
            : Uint8List.fromList(raw);
      } on FormatException {
        continue;
      } catch (_) {
        continue;
      }
      try {
        out.add(await importBytes(data, name));
      } on FormatException {
        continue; // bozuk kare: ötekiler eklensin
      }
    }
    if (out.isEmpty) {
      throw const FormatException(
        'Zip içinde yükseklik karesi (.hgt / .dt0–.dt2) bulunamadı.',
      );
    }
    return out;
  }

  /// İndirme kaynağı: AWS Açık Veri Kaydı'ndaki Terrain Tiles (Mapzen /
  /// Tilezen), "skadi" biçimi: kare başına gzip'li SRTM HGT, 1″ (~30 m).
  /// Türkiye için kaynak NASA/USGS SRTM (kamu malı). Hesap gerekmez.
  static Uri downloadUri(String key) => Uri.https(
    's3.amazonaws.com',
    '/elevation-tiles-prod/skadi/${key.substring(0, 3)}/$key.hgt.gz',
  );

  /// [key] karesini internetten indirip ekler. [onProgress]: 0–1 (boyut
  /// biliniyorsa). Veri olmayan kare (deniz, kapsam dışı) [FormatException].
  Future<ElevationTileInfo> download(
    String key, {
    void Function(double progress)? onProgress,
  }) async {
    if (DemTile.parseKey(key) == null) {
      throw FormatException('Geçersiz kare adı: $key');
    }
    final client = _httpClient();
    try {
      final res = await client
          .send(http.Request('GET', downloadUri(key)))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 403 || res.statusCode == 404) {
        throw FormatException(
          '$key için yükseklik verisi yok (deniz ya da kapsam dışı).',
        );
      }
      if (res.statusCode != 200) {
        throw FormatException('İndirilemedi (sunucu: ${res.statusCode}).');
      }
      final total = res.contentLength;
      if (total != null && total > maxTileBytes) {
        throw const FormatException('Dosya beklenenden büyük.');
      }
      final buf = BytesBuilder(copy: false);
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 30),
      )) {
        buf.add(chunk);
        if (buf.length > maxTileBytes) {
          throw const FormatException('Dosya beklenenden büyük.');
        }
        if (total != null && total > 0) onProgress?.call(buf.length / total);
      }
      return await importBytes(gunzipCapped(buf.takeBytes()), '$key.hgt');
    } finally {
      client.close();
    }
  }

  Future<void> delete(String fileName) async {
    final dir = await _directory();
    if (dir == null || !_name.hasMatch(fileName)) return;
    final f = File('${dir.path}/$fileName');
    if (await f.exists()) await f.delete();
  }
}

/// Çıktıyı biriktirir; sınırı aşınca durdurur.
class _CappedSink implements Sink<List<int>> {
  _CappedSink(this._out, this._max);
  final BytesBuilder _out;
  final int _max;

  @override
  void add(List<int> chunk) {
    _out.add(chunk);
    if (_out.length > _max) {
      throw const FormatException('Açılan dosya bir kare için çok büyük.');
    }
  }

  @override
  void close() {}
}
