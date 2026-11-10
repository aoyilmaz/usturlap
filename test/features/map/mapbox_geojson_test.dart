import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/map/engine/map_types.dart';
import 'package:kerteriz/features/map/engine/mapbox_geojson.dart';
import 'package:kerteriz/features/map/engine/widget_rasterizer.dart';
import 'package:latlong2/latlong.dart';

List<dynamic> _features(String fc) =>
    (jsonDecode(fc) as Map<String, dynamic>)['features'] as List<dynamic>;

void main() {
  const a = LatLng(39.90, 32.80), b = LatLng(39.95, 32.85), c = LatLng(39.90, 32.90);

  test('mapboxColor rgba üretir (alfa dahil)', () {
    expect(mapboxColor(const Color(0xFFFF0000)), 'rgba(255, 0, 0, 1.0)');
    expect(mapboxColor(const Color(0x80000000)), 'rgba(0, 0, 0, 0.502)');
  });

  test('çizgi → LineString (lon,lat sırası), renk/kalınlık/sıra özellikleri', () {
    final d = MapboxOverlayData.from([
      const MapLine(points: [a, b], color: Color(0xFF00FF00), width: 4),
    ]);
    final f = _features(d.lines).single as Map<String, dynamic>;
    expect(f['geometry']['type'], 'LineString');
    expect(f['geometry']['coordinates'][0], [32.80, 39.90]);
    expect(f['properties']['color'], 'rgba(0, 255, 0, 1.0)');
    expect(f['properties']['width'], 4);
    expect(f['properties']['order'], 0);
    expect(_features(d.areas), isEmpty);
    expect(_features(d.markers), isEmpty);
  });

  test('alan halkası kapatılır (ilk nokta = son nokta)', () {
    final d = MapboxOverlayData.from([
      const MapArea(
          points: [a, b, c],
          fillColor: Colors.red,
          strokeColor: Colors.red),
    ]);
    final ring = (_features(d.areas).single['geometry']['coordinates'] as List)
        .single as List;
    expect(ring, hasLength(4));
    expect(ring.first, ring.last);
  });

  test('daire metre yarıçaplı poligona çevrilir', () {
    final pts = circlePolygon(a, 1000, segments: 36);
    expect(pts, hasLength(36));
    const d = Distance();
    for (final p in pts) {
      expect(d(a, p), closeTo(1000, 5));
    }
    final data = MapboxOverlayData.from([
      MapCircle(
          center: a,
          radiusMeters: 1000,
          fillColor: Colors.teal,
          strokeColor: Colors.teal),
    ]);
    expect(_features(data.areas), hasLength(1));
  });

  test('işaretçi: id/ikon/dönüş özellikleri ve dokunma eşlemesi', () {
    var tapped = false;
    final d = MapboxOverlayData.from([
      MapMarker(
        id: 'wp:1',
        imageKey: 'wp:pin',
        point: a,
        rotationDeg: 45,
        onTap: () => tapped = true,
        child: const SizedBox(),
      ),
    ]);
    final p = _features(d.markers).single['properties'] as Map<String, dynamic>;
    expect(p['id'], 'wp:1');
    expect(p['icon'], 'wp:pin');
    expect(p['rotate'], 45);
    d.markerById['wp:1']!.onTap!();
    expect(tapped, isTrue);
  });

  test('geçersiz geometri atlanır (tek noktalı çizgi, 2 noktalı alan)', () {
    final d = MapboxOverlayData.from([
      const MapLine(points: [a], color: Colors.red),
      const MapArea(points: [a, b], fillColor: Colors.red, strokeColor: Colors.red),
    ]);
    expect(_features(d.lines), isEmpty);
    expect(_features(d.areas), isEmpty);
  });

  test('liste sırası "order" ile korunur', () {
    final d = MapboxOverlayData.from([
      const MapLine(points: [a, b], color: Colors.red),
      MapMarker(id: 'm', point: a, child: const SizedBox()),
      const MapLine(points: [b, c], color: Colors.blue),
    ]);
    final orders =
        _features(d.lines).map((f) => f['properties']['order']).toList();
    expect(orders, [0, 2]);
  });

  testWidgets('widget PNG\'ye çevrilir (doğru piksel boyutu)', (tester) async {
    final png = await tester.runAsync(() => rasterizeWidgetToPng(
          const Icon(Icons.location_on, color: Colors.red, size: 30),
          size: const Size(40, 40),
          pixelRatio: 3,
        ));
    expect(png, isNotNull);
    // PNG imzası + IHDR genişlik/yükseklik (big-endian) = 120x120.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    int be32(int o) =>
        (png[o] << 24) | (png[o + 1] << 16) | (png[o + 2] << 8) | png[o + 3];
    expect(be32(16), 120);
    expect(be32(20), 120);
  });

  test('resim katmanı GeoJSON\'a girmez, ayrı listede', () {
    final im = MapImage(
      id: 'viewshed',
      north: 1,
      south: 0,
      east: 1,
      west: 0,
      width: 2,
      height: 1,
      pixels: Uint8List(8),
    );
    final d = MapboxOverlayData.from([
      im,
      const MapLine(points: [LatLng(0, 0), LatLng(1, 1)], color: Colors.red),
    ]);
    expect(d.images, [im]);
    expect(d.areas, contains('"features":[]'));
    expect(d.lines, contains('LineString'));
  });

  test('kesikli çizgi ve kenar "dashed" özelliği taşır', () {
    final d = MapboxOverlayData.from([
      const MapLine(
        points: [LatLng(0, 0), LatLng(1, 1)],
        color: Colors.red,
        dashed: true,
      ),
      const MapLine(points: [LatLng(0, 0), LatLng(1, 0)], color: Colors.red),
      const MapArea(
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        fillColor: Colors.red,
        strokeColor: Colors.red,
        dashed: true,
      ),
    ]);
    final lines = _features(d.lines);
    expect(lines[0]['properties']['dashed'], true);
    expect((lines[1]['properties'] as Map).containsKey('dashed'), isFalse);
    expect(_features(d.areas).single['properties']['dashed'], true);
  });

  test('3B alan "height" özelliği taşır; düz alanda yok', () {
    final d = MapboxOverlayData.from([
      const MapArea(
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        fillColor: Colors.red,
        strokeColor: Colors.red,
        height: 25,
      ),
      const MapArea(
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        fillColor: Colors.red,
        strokeColor: Colors.red,
      ),
    ]);
    final areas = _features(d.areas);
    expect(areas[0]['properties']['height'], 25);
    expect((areas[1]['properties'] as Map).containsKey('height'), isFalse);
  });
}
