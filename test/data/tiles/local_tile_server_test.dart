import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/tiles/local_tile_server.dart';
import 'package:kerteriz/features/map/engine/mapbox_local_style.dart';
import 'package:mbtiles/mbtiles.dart';

/// 1x1 PNG (geçerli imza yeterli; içerik önemli değil).
final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
);

Future<(int, String?, List<int>)> _get(String url) async {
  final c = HttpClient();
  try {
    final res = await (await c.getUrl(Uri.parse(url))).close();
    final body = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    return (res.statusCode, res.headers.contentType?.mimeType, body);
  } finally {
    c.close();
  }
}

void main() {
  late Directory dir;
  late String mbPath;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('pz_tiles_');
    mbPath = '${dir.path}/test.mbtiles';
    final db = MbTiles.create(
      mbtilesPath: mbPath,
      metadata: const MbTilesMetadata(
        name: 'test',
        format: 'png',
        bounds: MbTilesBounds(left: 32.7, bottom: 39.8, right: 33.0, top: 40.0),
        minZoom: 10,
        maxZoom: 12,
      ),
    );
    // XYZ (z=10, x=605, y=388) → TMS y = 2^10-1-388 = 635
    db.putTile(z: 10, x: 605, y: 635, bytes: _png);
    db.dispose();
  });

  tearDownAll(() async {
    await LocalTileServer.instance.unregister('mb');
    dir.deleteSync(recursive: true);
  });

  test(
    'MBTiles karosu XYZ adresiyle (TMS çevrimi) PNG olarak sunulur',
    () async {
      final info = await LocalTileServer.instance.registerMbtiles('mb', mbPath);
      expect(info.isVector, isFalse);
      expect(info.minZoom, 10);
      expect(info.maxZoom, 12);
      expect(info.bounds, [32.7, 39.8, 33.0, 40.0]);
      expect(info.urlTemplate, startsWith('http://127.0.0.1:'));

      final url = info.urlTemplate
          .replaceAll('{z}', '10')
          .replaceAll('{x}', '605')
          .replaceAll('{y}', '388');
      final (status, mime, body) = await _get(url);
      expect(status, 200);
      expect(mime, 'image/png');
      expect(body, _png);
    },
  );

  test('olmayan karo → 204 (boş), bilinmeyen kaynak → 404', () async {
    final info = await LocalTileServer.instance.registerMbtiles('mb', mbPath);
    final missing = info.urlTemplate
        .replaceAll('{z}', '11')
        .replaceAll('{x}', '0')
        .replaceAll('{y}', '0');
    expect((await _get(missing)).$1, 204);

    final unknown = missing.replaceFirst('/t/mb/', '/t/yok/');
    expect((await _get(unknown)).$1, 404);
  });

  test('kayıt silinince karo sunulmaz', () async {
    final info = await LocalTileServer.instance.registerMbtiles('mb2', mbPath);
    await LocalTileServer.instance.unregister('mb2');
    final url = info.urlTemplate
        .replaceAll('{z}', '10')
        .replaceAll('{x}', '605')
        .replaceAll('{y}', '388');
    expect((await _get(url)).$1, 404);
  });

  test('isGzip imzayı tanır', () {
    expect(isGzip([0x1f, 0x8b, 0x08]), isTrue);
    expect(isGzip(_png), isFalse);
  });

  // Gerçek PMTiles dosyasıyla duman testi (dosya git dışı; yoksa atlanır).
  const realPm = 'tiles_external/gaziantep.pmtiles';
  test(
    'gerçek PMTiles: vektör karo sunulur',
    () async {
      final info = await LocalTileServer.instance.registerPmtiles('pm', realPm);
      expect(info.isVector, isTrue);
      expect(info.maxZoom, greaterThan(0));
      // Gaziantep merkezi (37.066N, 37.383E) — en yüksek zoom'da karo.
      final z = info.maxZoom!;
      final n = 1 << z;
      final x = ((37.383 + 180) / 360 * n).floor();
      final lat = 37.066 * 3.141592653589793 / 180;
      final y =
          ((1 - (log(tan(lat) + 1 / cos(lat)) / 3.141592653589793)) / 2 * n)
              .floor();
      final (status, mime, body) = await _get(
        info.urlTemplate
            .replaceAll('{z}', '$z')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y'),
      );
      expect(status, 200);
      expect(mime, 'application/x-protobuf');
      expect(body, isNotEmpty);
      expect(isGzip(body), isFalse); // sunucu açılmış MVT verir
      await LocalTileServer.instance.unregister('pm');
    },
    skip: File(realPm).existsSync() ? false : 'gerçek PMTiles dosyası yok',
  );

  group('Mapbox yerel stil', () {
    const info = LocalTileSourceInfo(
      urlTemplate: 'http://127.0.0.1:1/t/x/{z}/{x}/{y}',
      isVector: true,
      minZoom: 0,
      maxZoom: 14,
    );

    test('raster stil: tek raster kaynak + zemin', () {
      final s =
          jsonDecode(
                localRasterStyle(
                  const LocalTileSourceInfo(
                    urlTemplate: 'u',
                    isVector: false,
                    maxZoom: 16,
                  ),
                  attribution: '© X',
                ),
              )
              as Map<String, dynamic>;
      final src = s['sources']['pz-base'] as Map<String, dynamic>;
      expect(src['type'], 'raster');
      expect(src['tiles'], ['u']);
      expect(src['maxzoom'], 16);
      expect(src.containsKey('minzoom'), isFalse);
      expect(src['attribution'], '© X');
      expect((s['layers'] as List).map((l) => l['type']), [
        'background',
        'raster',
      ]);
    });

    test('vektör stil: kaynaklar yerele yönlenir, glyph + font tamamlanır', () {
      final style = {
        'version': 8,
        'sources': {
          'protomaps': {'type': 'vector', 'url': 'pmtiles://eski'},
        },
        'layers': [
          {
            'id': 'places',
            'type': 'symbol',
            'source': 'protomaps',
            'layout': {
              'text-field': ['get', 'name'],
            },
          },
          {
            'id': 'custom-font',
            'type': 'symbol',
            'source': 'protomaps',
            'layout': {
              'text-field': 'x',
              'text-font': ['Noto Sans'],
            },
          },
        ],
      };
      final s =
          jsonDecode(localVectorStyle(style, info)) as Map<String, dynamic>;
      final src = s['sources']['protomaps'] as Map<String, dynamic>;
      expect(src['tiles'], [info.urlTemplate]);
      expect(src.containsKey('url'), isFalse);
      expect(src['maxzoom'], 14);
      expect(s['glyphs'], mapboxGlyphs);
      final layers = s['layers'] as List;
      expect(layers[0]['layout']['text-font'], defaultTextFont);
      expect(layers[1]['layout']['text-font'], ['Noto Sans']); // korunur
      // Orijinal stil değişmemeli.
      expect(style['sources'], {
        'protomaps': {'type': 'vector', 'url': 'pmtiles://eski'},
      });
    });
  });
}
