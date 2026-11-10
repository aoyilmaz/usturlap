import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'dem_tile.dart';

/// Yükseklik dosyalarının klasörü: Belgeler/tiles_external (iOS; Dosyalar
/// uygulamasından da görünür). Bulunamazsa null (testte path_provider yok).
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
  ElevationStore({Future<Directory?> Function()? directory})
    : _directory = directory ?? defaultElevationDirectory;

  final Future<Directory?> Function() _directory;

  /// Uygulamayla gelen örnek kareler (`assets/tiles/<key>.hgt`, SRTM 3″).
  static const bundledKeys = {'N37E037'};

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
    for (final e in _exts) {
      final old = File('${dir.path}/$tileKey.$e');
      if (await old.exists()) await old.delete();
    }
    final dest = File('${dir.path}/$tileKey.$ext');
    await dest.writeAsBytes(bytes, flush: true);
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

  Future<void> delete(String fileName) async {
    final dir = await _directory();
    if (dir == null || !_name.hasMatch(fileName)) return;
    final f = File('${dir.path}/$fileName');
    if (await f.exists()) await f.delete();
  }
}
