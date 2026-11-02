import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/map/base_layer.dart';
import 'package:kerteriz/features/map/base_layer_resolver.dart';
import 'package:kerteriz/features/map/engine/flutter_map_engine.dart';
import 'package:kerteriz/features/map/engine/map_types.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoBounds', () {
    test('fromPoints en küçük kapsayan dikdörtgeni verir', () {
      final b = GeoBounds.fromPoints(const [
        LatLng(39.9, 32.8),
        LatLng(40.1, 32.7),
        LatLng(39.8, 33.0),
      ]);
      expect(b, const GeoBounds(south: 39.8, west: 32.7, north: 40.1, east: 33.0));
    });

    test('contains sınırları dahil eder, dışarıyı dışlar', () {
      const b = GeoBounds(south: 39, west: 32, north: 40, east: 33);
      expect(b.contains(const LatLng(39.5, 32.5)), isTrue);
      expect(b.contains(const LatLng(39, 32)), isTrue); // köşe
      expect(b.contains(const LatLng(40.01, 32.5)), isFalse);
      expect(b.contains(const LatLng(39.5, 33.01)), isFalse);
    });

    test('boş nokta listesi hata verir', () {
      expect(() => GeoBounds.fromPoints(const []), throwsArgumentError);
    });
  });

  group('buildFlutterMapOverlayLayers', () {
    const a = LatLng(39.9, 32.8), b = LatLng(39.95, 32.85);
    final line = MapLine(points: const [a, b], color: Colors.red);
    final area = MapArea(
        points: const [a, b, LatLng(39.9, 32.9)],
        fillColor: Colors.red,
        strokeColor: Colors.red);
    final marker = MapMarker(id: 'm', point: a, child: const SizedBox());
    final circle = MapCircle(
        center: a,
        radiusMeters: 100,
        fillColor: Colors.teal,
        strokeColor: Colors.teal);

    test('ardışık aynı türler tek katmanda toplanır, sıra korunur', () {
      final layers = buildFlutterMapOverlayLayers(
          [area, line, line, circle, marker, marker]);
      expect(layers.map((w) => w.runtimeType).toList(),
          [PolygonLayer, PolylineLayer, CircleLayer, MarkerLayer]);
      expect((layers[1] as PolylineLayer).polylines, hasLength(2));
      expect((layers[3] as MarkerLayer).markers, hasLength(2));
    });

    test('araya giren tür grubu böler (çizim sırası bozulmaz)', () {
      final layers = buildFlutterMapOverlayLayers([line, marker, line]);
      expect(layers.map((w) => w.runtimeType).toList(),
          [PolylineLayer, MarkerLayer, PolylineLayer]);
    });

    test('daire metre cinsinden yarıçapla çizilir', () {
      final layer = buildFlutterMapOverlayLayers([circle]).single as CircleLayer;
      expect(layer.circles.single.useRadiusInMeter, isTrue);
      expect(layer.circles.single.radius, 100);
    });

    test('boş liste → katman yok', () {
      expect(buildFlutterMapOverlayLayers(const []), isEmpty);
    });
  });

  group('BaseLayerResolver.resolveOnline', () {
    const resolver = BaseLayerResolver();

    test('OSM ve topo kendi zoom tavanlarıyla çözülür', () {
      final osm = kBaseLayers.firstWhere((l) => l.id == 'online_street');
      final topo = kBaseLayers.firstWhere((l) => l.id == 'online_topo');
      final r1 = resolver.resolveOnline(osm) as RasterUrlBaseLayer;
      final r2 = resolver.resolveOnline(topo) as RasterUrlBaseLayer;
      expect(r1.maxNativeZoom, 19);
      expect(r2.maxNativeZoom, 17);
      expect(r2.attribution, contains('OpenTopoMap'));
    });

    test('token yoksa uydu katmanı çözülmez (test ortamında token yok)', () {
      final sat = kBaseLayers.firstWhere((l) => l.id == 'online_satellite');
      expect(resolver.resolveOnline(sat), isNull);
    });

    test('dosya tabanlı katman online çözülmez', () {
      final vec = kBaseLayers.firstWhere((l) => l.id == 'vec_turkiye');
      expect(resolver.resolveOnline(vec), isNull);
    });
  });
}
