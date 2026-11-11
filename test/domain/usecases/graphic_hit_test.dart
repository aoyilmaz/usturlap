import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/usecases/graphic_hit.dart';
import 'package:latlong2/latlong.dart';

/// Haritada dokunulan çizimi bulma.
void main() {
  final t0 = DateTime.utc(2026, 11, 11);
  const o = LatLng(39.0, 32.0);

  MapGraphic g(String name, GraphicType type, List<LatLng> pts) => MapGraphic(
    uid: name,
    name: name,
    type: type,
    points: pts,
    colorValue: 0xFFFF0000,
    createdAt: t0,
  );

  List<LatLng> square(double side) => [
    o,
    GeoMath.destination(o, side, 90),
    GeoMath.destination(GeoMath.destination(o, side, 90), side, 0),
    GeoMath.destination(o, side, 0),
  ];

  test('çizgiye uzaklık: yanında isabet, uzağında yok', () {
    final line = g('HAT', GraphicType.line, [
      o,
      GeoMath.destination(o, 1000, 90),
    ]);
    final near = GeoMath.destination(GeoMath.destination(o, 500, 90), 15, 0);
    expect(distanceToOutline(near, line), closeTo(15, 0.5));
    expect(hitGraphic(near, [line], 20)?.name, 'HAT');
    expect(hitGraphic(near, [line], 10), isNull);
    // Ucun ötesinde: uca uzaklık.
    final beyond = GeoMath.destination(o, 30, 270);
    expect(
      distanceToSegment(beyond, line.points[0], line.points[1]),
      closeTo(30, 0.5),
    );
  });

  test('kenar öncelikli; içeride iç içe olanların küçüğü', () {
    final big = g('BÜYÜK', GraphicType.area, square(1000));
    final small = g('KÜÇÜK', GraphicType.rectangle, [
      for (final p in square(200))
        GeoMath.destination(GeoMath.destination(p, 400, 90), 400, 0),
    ]);
    final center = GeoMath.destination(GeoMath.destination(o, 500, 90), 500, 0);
    expect(hitGraphic(center, [big, small], 20)?.name, 'KÜÇÜK');
    // Büyüğün kenarına yakın: kenar kazanır.
    final edge = GeoMath.destination(GeoMath.destination(o, 500, 90), 5, 0);
    expect(hitGraphic(edge, [small, big], 20)?.name, 'BÜYÜK');
    // Hiçbirinde değil.
    expect(
      hitGraphic(GeoMath.destination(o, 300, 225), [big, small], 20),
      isNull,
    );
  });

  test('daire: çevreye yakın ya da içeride', () {
    final c = g('DAİRE', GraphicType.circle, [
      o,
      GeoMath.destination(o, 500, 0),
    ]);
    expect(
      distanceToOutline(GeoMath.destination(o, 510, 90), c),
      closeTo(10, 0.5),
    );
    expect(hitGraphic(GeoMath.destination(o, 200, 45), [c], 20)?.name, 'DAİRE');
    expect(hitGraphic(GeoMath.destination(o, 600, 45), [c], 20), isNull);
  });

  test('piksel başına metre (512 px karo)', () {
    expect(metersPerPixel(0, 0), closeTo(78271.5, 0.1));
    expect(metersPerPixel(16, 60), closeTo(78271.5 / 65536 / 2, 0.01));
  });
}
