import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'gpkg_grid.dart';

/// GeoPackage (.gpkg) raster karo okuyucu (Aşama H). Salt okunur açılır.
/// İlk karo tablosu (`gpkg_contents.data_type = 'tiles'`) kullanılır; yalnız
/// Web Mercator (EPSG:3857). Uymayan dosya Türkçe [FormatException] verir.
class GpkgReader {
  GpkgReader._(this._db, this.table, this.grid, this._tile);

  final Database _db;

  /// Karo tablosu adı.
  final String table;
  final GpkgTileGrid grid;
  final PreparedStatement _tile;

  static GpkgReader open(String path) {
    final Database db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
    } on SqliteException {
      throw const FormatException('GeoPackage açılamadı.');
    }
    try {
      final ResultSet contents;
      try {
        contents = db.select(
          "SELECT table_name, srs_id, min_x, min_y, max_x, max_y "
          "FROM gpkg_contents WHERE data_type = 'tiles' ORDER BY table_name",
        );
      } on SqliteException {
        throw const FormatException('Bu bir GeoPackage dosyası değil.');
      }
      if (contents.isEmpty) {
        throw const FormatException(
          'GeoPackage\'da karo (raster) tablosu yok; yalnız raster desteklenir.',
        );
      }
      final c = contents.first;
      final table = c['table_name'] as String;
      final set = db.select(
        'SELECT srs_id, min_x, min_y, max_x, max_y '
        'FROM gpkg_tile_matrix_set WHERE table_name = ?',
        [table],
      );
      if (set.isEmpty) {
        throw const FormatException('GeoPackage karo matrisi yok.');
      }
      final s = set.first;
      if (!_isWebMercator(db, (s['srs_id'] as num).toInt())) {
        throw const FormatException(
          'Yalnız Web Mercator (EPSG:3857) karolu GeoPackage desteklenir; '
          'QGIS ya da gdal ile dönüştürün.',
        );
      }
      double d(Object? v) => (v as num).toDouble();
      final matrices = [
        for (final r in db.select(
          'SELECT zoom_level, matrix_width, matrix_height '
          'FROM gpkg_tile_matrix WHERE table_name = ? ORDER BY zoom_level',
          [table],
        ))
          (
            zoomLevel: (r['zoom_level'] as num).toInt(),
            matrixWidth: (r['matrix_width'] as num).toInt(),
            matrixHeight: (r['matrix_height'] as num).toInt(),
          ),
      ];
      List<double>? contentBounds;
      if (c['min_x'] != null &&
          c['max_x'] != null &&
          (c['srs_id'] as num?)?.toInt() == (s['srs_id'] as num).toInt()) {
        contentBounds = [
          d(c['min_x']),
          d(c['min_y']),
          d(c['max_x']),
          d(c['max_y']),
        ];
      }
      final grid = GpkgTileGrid.build(
        matrixSet: [d(s['min_x']), d(s['min_y']), d(s['max_x']), d(s['max_y'])],
        matrices: matrices,
        contents: contentBounds,
      );
      final quoted = '"${table.replaceAll('"', '""')}"';
      final stmt = db.prepare(
        'SELECT tile_data FROM $quoted '
        'WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
      );
      return GpkgReader._(db, table, grid, stmt);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  static bool _isWebMercator(Database db, int srsId) {
    if (srsId == 3857 || srsId == 900913) return true;
    try {
      final r = db.select(
        'SELECT organization, organization_coordsys_id '
        'FROM gpkg_spatial_ref_sys WHERE srs_id = ?',
        [srsId],
      );
      if (r.isEmpty) return false;
      final org = '${r.first['organization']}'.toUpperCase();
      final code = (r.first['organization_coordsys_id'] as num?)?.toInt();
      return org == 'EPSG' && (code == 3857 || code == 900913);
    } on SqliteException {
      return false;
    }
  }

  /// Harita karosu (yoksa / kapsam dışıysa null).
  Uint8List? tile(int z, int x, int y) {
    final at = grid.locate(z, x, y);
    if (at == null) return null;
    final r = _tile.select([at.zoomLevel, at.col, at.row]);
    if (r.isEmpty) return null;
    final data = r.first['tile_data'];
    return data is Uint8List ? data : null;
  }

  void close() {
    _tile.dispose();
    _db.dispose();
  }
}
