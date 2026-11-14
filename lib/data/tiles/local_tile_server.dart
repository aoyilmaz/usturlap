import 'dart:io';
import 'dart:typed_data';

import 'package:mbtiles/mbtiles.dart';
import 'package:pmtiles/pmtiles.dart';

import 'gpkg_reader.dart';

/// Kullanıcının kendi .mbtiles / .pmtiles / .gpkg dosyalarını Mapbox motoruna sunan
/// küçük yerel HTTP sunucusu.
///
/// Mapbox SDK bu dosyaları doğrudan okuyamaz; karoları URL'den ister. Sunucu
/// yalnızca 127.0.0.1'e (cihazın kendisi) bağlanır — ağdan erişilemez.
/// Adres biçimi: `http://127.0.0.1:<port>/t/<id>/{z}/{x}/{y}`.
class LocalTileServer {
  LocalTileServer._();
  static final LocalTileServer instance = LocalTileServer._();

  HttpServer? _server;
  final Map<String, _TileSource> _sources = {};

  /// Test/teşhis için: kayıtlı kaynak kimlikleri.
  Iterable<String> get sourceIds => _sources.keys;

  Future<int> _ensureStarted() async {
    final s = _server;
    if (s != null) return s.port;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
    _server = server;
    return server.port;
  }

  String _template(int port, String id) =>
      'http://127.0.0.1:$port/t/${Uri.encodeComponent(id)}/{z}/{x}/{y}';

  /// MBTiles dosyasını kaydeder; Mapbox kaynağı için karo adresi şablonu döner.
  Future<LocalTileSourceInfo> registerMbtiles(String id, String path) async {
    final port = await _ensureStarted();
    final existing = _sources[id];
    if (existing is _MbtilesSource && existing.path == path) {
      return existing.info(_template(port, id));
    }
    await unregister(id);
    final src = _MbtilesSource(path);
    _sources[id] = src;
    return src.info(_template(port, id));
  }

  /// PMTiles dosyasını kaydeder (zoom aralığı ve tür başlıktan okunur).
  Future<LocalTileSourceInfo> registerPmtiles(String id, String path) async {
    final port = await _ensureStarted();
    final existing = _sources[id];
    if (existing is _PmtilesSource && existing.path == path) {
      return existing.info(_template(port, id));
    }
    await unregister(id);
    final src = await _PmtilesSource.open(path);
    _sources[id] = src;
    return src.info(_template(port, id));
  }

  /// GeoPackage raster dosyasını kaydeder (yalnız EPSG:3857; uymayan dosya
  /// [FormatException] verir).
  Future<LocalTileSourceInfo> registerGpkg(String id, String path) async {
    final port = await _ensureStarted();
    final existing = _sources[id];
    if (existing is _GpkgSource && existing.path == path) {
      return existing.info(_template(port, id));
    }
    await unregister(id);
    final src = _GpkgSource(path, GpkgReader.open(path));
    _sources[id] = src;
    return src.info(_template(port, id));
  }

  Future<void> unregister(String id) async {
    await _sources.remove(id)?.close();
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      // /t/<id>/<z>/<x>/<y>  (uzantı varsa yok say: 5.png, 5.pbf)
      final seg = req.uri.pathSegments;
      if (seg.length != 5 || seg[0] != 't') {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final src = _sources[seg[1]];
      final z = int.tryParse(seg[2]);
      final x = int.tryParse(seg[3]);
      final y = int.tryParse(seg[4].split('.').first);
      if (src == null || z == null || x == null || y == null) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final bytes = await src.tile(z, x, y);
      if (bytes == null || bytes.isEmpty) {
        // Kapsam dışı / eksik karo: hata değil, "boş karo".
        res.statusCode = HttpStatus.noContent;
        return;
      }
      res.headers
        ..contentType = src.contentTypeFor(bytes)
        // Dosya zaten cihazda — Mapbox önbelleğine ikinci kopya yazılmasın.
        ..set(HttpHeaders.cacheControlHeader, 'no-store');
      // gzip'li karo (vektör MBTiles'ta yaygın): imzadan anla, istemci açsın.
      if (isGzip(bytes)) {
        res.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      }
      res.add(bytes);
    } catch (_) {
      res.statusCode = HttpStatus.internalServerError;
    } finally {
      await res.close();
    }
  }
}

/// gzip imzası (1F 8B) ile mi başlıyor.
bool isGzip(List<int> b) => b.length > 2 && b[0] == 0x1f && b[1] == 0x8b;

/// Kayıtlı kaynağın Mapbox stiline yazılacak bilgileri.
class LocalTileSourceInfo {
  const LocalTileSourceInfo({
    required this.urlTemplate,
    required this.isVector,
    this.minZoom,
    this.maxZoom,
    this.bounds,
  });

  final String urlTemplate;

  /// true: vektör (MVT) karolar; false: raster (png/jpg/webp).
  final bool isVector;
  final int? minZoom;
  final int? maxZoom;

  /// [batı, güney, doğu, kuzey] — kapsam dışına istek atılmasın diye.
  final List<double>? bounds;
}

abstract class _TileSource {
  String get path;
  ContentType get contentType;

  /// Karonun içerik türü (karışık biçimli kaynaklarda imzadan).
  ContentType contentTypeFor(Uint8List bytes) => contentType;
  Future<Uint8List?> tile(int z, int x, int y);
  LocalTileSourceInfo info(String urlTemplate);
  Future<void> close();
}

class _MbtilesSource extends _TileSource {
  _MbtilesSource(this.path) : _db = MbTiles(mbtilesPath: path) {
    try {
      final m = _db.getMetadata();
      _format = m.format.toLowerCase();
      final b = m.bounds;
      if (b != null) _bounds = [b.left, b.bottom, b.right, b.top];
      _minZoom = m.minZoom?.round();
      _maxZoom = m.maxZoom?.round();
    } catch (_) {/* metadata eksik → varsayılanlar */}
  }

  @override
  final String path;
  final MbTiles _db;
  String _format = 'png';
  List<double>? _bounds;
  int? _minZoom, _maxZoom;

  bool get _isVector => _format == 'pbf' || _format == 'mvt';

  @override
  ContentType get contentType => switch (_format) {
        'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
        'webp' => ContentType('image', 'webp'),
        'pbf' || 'mvt' => ContentType('application', 'x-protobuf'),
        _ => ContentType('image', 'png'),
      };

  @override
  Future<Uint8List?> tile(int z, int x, int y) async {
    // MBTiles TMS şemasında saklar: xyz y → tms y.
    final tmsY = ((1 << z) - 1) - y;
    return _db.getTile(z: z, x: x, y: tmsY);
  }

  @override
  LocalTileSourceInfo info(String urlTemplate) => LocalTileSourceInfo(
        urlTemplate: urlTemplate,
        isVector: _isVector,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        bounds: _bounds,
      );

  @override
  Future<void> close() async => _db.dispose();
}

class _PmtilesSource extends _TileSource {
  _PmtilesSource._(this.path, this._archive);

  static Future<_PmtilesSource> open(String path) async =>
      _PmtilesSource._(path, await PmTilesArchive.from(path));

  @override
  final String path;
  final PmTilesArchive _archive;

  @override
  ContentType get contentType => switch (_archive.tileType) {
        TileType.mvt => ContentType('application', 'x-protobuf'),
        TileType.jpeg => ContentType('image', 'jpeg'),
        TileType.webp => ContentType('image', 'webp'),
        _ => ContentType('image', 'png'),
      };

  @override
  Future<Uint8List?> tile(int z, int x, int y) async {
    try {
      final t = await _archive.tile(ZXY(z, x, y).toTileId());
      // bytes() sıkıştırmayı çözer → ham MVT / resim.
      return Uint8List.fromList(t.bytes());
    } catch (_) {
      return null; // kapsam dışı / eksik
    }
  }

  @override
  LocalTileSourceInfo info(String urlTemplate) {
    final h = _archive.header;
    return LocalTileSourceInfo(
      urlTemplate: urlTemplate,
      isVector: _archive.tileType == TileType.mvt,
      minZoom: h.minZoom,
      maxZoom: h.maxZoom,
    );
  }

  @override
  Future<void> close() => _archive.close();
}

/// Resim imzasından içerik türü (PNG / JPEG / WebP).
ContentType imageContentType(Uint8List b) {
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) {
    return ContentType('image', 'jpeg');
  }
  if (b.length > 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return ContentType('image', 'webp');
  }
  return ContentType('image', 'png');
}

class _GpkgSource extends _TileSource {
  _GpkgSource(this.path, this._reader);

  @override
  final String path;
  final GpkgReader _reader;

  @override
  ContentType get contentType => ContentType('image', 'png');

  @override
  ContentType contentTypeFor(Uint8List bytes) => imageContentType(bytes);

  @override
  Future<Uint8List?> tile(int z, int x, int y) async => _reader.tile(z, x, y);

  @override
  LocalTileSourceInfo info(String urlTemplate) => LocalTileSourceInfo(
    urlTemplate: urlTemplate,
    isVector: false,
    minZoom: _reader.grid.minZoom,
    maxZoom: _reader.grid.maxZoom,
    bounds: _reader.grid.boundsWgs84,
  );

  @override
  Future<void> close() async => _reader.close();
}
