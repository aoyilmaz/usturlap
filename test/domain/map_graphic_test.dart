import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:latlong2/latlong.dart';

/// G1: çizim türleri.
void main() {
  const c = LatLng(37.0, 37.0);
  MapGraphic g(GraphicType t, List<LatLng> pts) => MapGraphic(
    uid: 'g',
    name: 'G',
    type: t,
    points: pts,
    colorValue: 0xFFFF0000,
    createdAt: DateTime(2026),
  );

  test('daire: merkez + kenar → 72 çevre noktası, yarıçap', () {
    final edge = GeoMath.destination(c, 500, 90);
    final circle = g(GraphicType.circle, [c, edge]);
    expect(circle.closed, isTrue);
    expect(circle.radiusMeters, closeTo(500, 0.5));
    expect(circle.outline, hasLength(72));
    for (final p in circle.outline) {
      expect(GeoMath.distance(c, p), closeTo(500, 0.5));
    }
  });

  test('dikdörtgen köşeleri, çizgi açık; varsayılan stil', () {
    final b = GeoMath.destination(GeoMath.destination(c, 1000, 0), 500, 90);
    final corners = GeoMath.rectangleCorners(c, b);
    expect(corners, hasLength(4));
    expect(corners[1].latitude, c.latitude);
    expect(corners[1].longitude, b.longitude);
    final rect = g(GraphicType.rectangle, corners);
    expect(rect.closed, isTrue);
    expect(rect.outline, corners);
    expect(GeoMath.polygonArea(corners), closeTo(500000, 5000));
    final line = g(GraphicType.line, [c, b]);
    expect(line.closed, isFalse);
    expect(line.strokeWidth, 3);
    expect(line.dashed, isFalse);
    expect(GraphicType.fromName('circle'), GraphicType.circle);
  });
}
