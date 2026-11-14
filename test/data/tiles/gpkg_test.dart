import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/tiles/gpkg_grid.dart';
import 'package:usturlap/data/tiles/gpkg_reader.dart';
import 'package:usturlap/data/tiles/local_tile_server.dart';
import 'package:sqlite3/sqlite3.dart';

const _h = webMercatorHalf;
final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
final _jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2]);

/// Testte küçük bir GeoPackage üretir (gdal GoogleMapsCompatible gibi).
String _makeGpkg(
  Directory dir, {
  int srs = 3857,
  List<double> set = const [-_h, -_h, _h, _h],
  bool tiles = true,
}) {
  final path = '${dir.path}/t_${DateTime.now().microsecondsSinceEpoch}.gpkg';
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE gpkg_spatial_ref_sys (srs_name TEXT, srs_id INTEGER PRIMARY KEY,
      organization TEXT, organization_coordsys_id INTEGER, definition TEXT);
    CREATE TABLE gpkg_contents (table_name TEXT PRIMARY KEY, data_type TEXT,
      identifier TEXT, min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE,
      srs_id INTEGER);
    CREATE TABLE gpkg_tile_matrix_set (table_name TEXT PRIMARY KEY,
      srs_id INTEGER, min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE);
    CREATE TABLE gpkg_tile_matrix (table_name TEXT, zoom_level INTEGER,
      matrix_width INTEGER, matrix_height INTEGER, tile_width INTEGER,
      tile_height INTEGER, pixel_x_size DOUBLE, pixel_y_size DOUBLE);
    CREATE TABLE "pafta" (id INTEGER PRIMARY KEY, zoom_level INTEGER,
      tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
  ''');
  db.execute(
    "INSERT INTO gpkg_spatial_ref_sys VALUES ('x', ?, 'EPSG', ?, '')",
    [srs, srs],
  );
  db.execute(
    "INSERT INTO gpkg_contents VALUES ('pafta', ?, 'pafta', ?, ?, ?, ?, ?)",
    [tiles ? 'tiles' : 'features', ...set, srs],
  );
  db.execute('INSERT INTO gpkg_tile_matrix_set VALUES (?, ?, ?, ?, ?, ?)', [
    'pafta',
    srs,
    ...set,
  ]);
  for (var z = 0; z <= 2; z++) {
    db.execute(
      "INSERT INTO gpkg_tile_matrix VALUES ('pafta', ?, ?, ?, 256, 256, 1, 1)",
      [z, 1 << z, 1 << z],
    );
  }
  db.execute(
    'INSERT INTO "pafta" (zoom_level, tile_column, tile_row, tile_data) '
    'VALUES (1, 1, 0, ?), (2, 3, 3, ?)',
    [_png, _jpg],
  );
  db.dispose();
  return path;
}

void main() {
  group('GpkgTileGrid', () {
    test('dünya kapsamı: düzey = XYZ zoom, satır üstten', () {
      final g = GpkgTileGrid.build(
        matrixSet: const [-_h, -_h, _h, _h],
        matrices: [
          for (var z = 0; z <= 3; z++)
            (zoomLevel: z, matrixWidth: 1 << z, matrixHeight: 1 << z),
        ],
      );
      expect(g.minZoom, 0);
      expect(g.maxZoom, 3);
      expect(g.locate(3, 5, 2), (zoomLevel: 3, col: 5, row: 2));
      expect(g.locate(3, 8, 0), isNull);
      expect(g.locate(9, 0, 0), isNull);
      final b = g.boundsWgs84;
      expect(b[0], closeTo(-180, 1e-9));
      expect(b[3], closeTo(85.0511, 1e-4));
    });

    test('hizalı alt küme: ofsetler, düzey ≠ zoom', () {
      const span2 = 2 * _h / 4; // z2 karo açıklığı
      final g = GpkgTileGrid.build(
        // z2'de sütun 1–2, satır 1–2.
        matrixSet: const [
          -_h + span2,
          _h - 3 * span2,
          -_h + 3 * span2,
          _h - span2,
        ],
        matrices: [
          (zoomLevel: 0, matrixWidth: 2, matrixHeight: 2), // z2
          (zoomLevel: 1, matrixWidth: 4, matrixHeight: 4), // z3
        ],
      );
      expect(g.minZoom, 2);
      expect(g.maxZoom, 3);
      expect(g.locate(2, 1, 1), (zoomLevel: 0, col: 0, row: 0));
      expect(g.locate(2, 2, 2), (zoomLevel: 0, col: 1, row: 1));
      expect(g.locate(2, 0, 1), isNull);
      expect(g.locate(3, 2, 2), (zoomLevel: 1, col: 0, row: 0));
    });

    test('hizasız ya da kare olmayan matris reddedilir', () {
      // z1'de üçte bir karo kaymış (gerçek hizasızlık).
      const third = 2 * _h / 2 / 3;
      expect(
        () => GpkgTileGrid.build(
          matrixSet: const [-_h + third, -_h, _h + third, _h],
          matrices: [(zoomLevel: 0, matrixWidth: 2, matrixHeight: 2)],
        ),
        throwsFormatException,
      );
      expect(
        () => GpkgTileGrid.build(
          matrixSet: const [-_h, -_h, _h, _h],
          matrices: [(zoomLevel: 0, matrixWidth: 2, matrixHeight: 1)],
        ),
        throwsFormatException,
      );
    });
  });

  group('GpkgReader + yerel sunucu', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('gpkg_'));
    tearDown(() async => dir.delete(recursive: true));

    test('karo okunur; kapsam dışı ve eksik karo null', () {
      final r = GpkgReader.open(_makeGpkg(dir));
      addTearDown(r.close);
      expect(r.table, 'pafta');
      expect(r.grid.maxZoom, 2);
      expect(r.tile(1, 1, 0), _png);
      expect(r.tile(1, 0, 0), isNull);
      expect(r.tile(7, 0, 0), isNull);
    });

    test('Web Mercator olmayan, karosuz ve GeoPackage olmayan reddedilir', () {
      expect(
        () => GpkgReader.open(_makeGpkg(dir, srs: 4326)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mesaj',
            contains('Web Mercator'),
          ),
        ),
      );
      expect(
        () => GpkgReader.open(_makeGpkg(dir, tiles: false)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mesaj',
            contains('raster'),
          ),
        ),
      );
      final plain = '${dir.path}/duz.sqlite';
      sqlite3.open(plain)
        ..execute('CREATE TABLE x (a)')
        ..dispose();
      expect(() => GpkgReader.open(plain), throwsFormatException);
    });

    test('yerel sunucu: içerik türü imzadan, eksik karo 204', () async {
      final info = await LocalTileServer.instance.registerGpkg(
        'test-gpkg',
        _makeGpkg(dir),
      );
      addTearDown(() => LocalTileServer.instance.unregister('test-gpkg'));
      expect(info.isVector, isFalse);
      expect(info.maxZoom, 2);
      final client = HttpClient();
      addTearDown(client.close);
      Future<HttpClientResponse> get(String zxy) async {
        final url = info.urlTemplate.replaceAll('{z}/{x}/{y}', zxy);
        return (await client.getUrl(Uri.parse(url))).close();
      }

      final png = await get('1/1/0');
      expect(png.statusCode, 200);
      expect(png.headers.contentType?.mimeType, 'image/png');
      await png.drain<void>();
      final jpg = await get('2/3/3');
      expect(jpg.headers.contentType?.mimeType, 'image/jpeg');
      await jpg.drain<void>();
      final none = await get('1/0/1');
      expect(none.statusCode, 204);
      await none.drain<void>();
    });
  });
}
