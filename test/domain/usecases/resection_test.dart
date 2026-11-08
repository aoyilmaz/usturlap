import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/domain/usecases/resection.dart';
import 'package:latlong2/latlong.dart';

/// E5: geriden kestirme (resection).
void main() {
  const me = LatLng(37.06, 37.38);
  // Gözlemcinin çevresinde bilinen noktalar (≈ 2–3 km).
  final north = GeoMath.destination(me, 2500, 0);
  final east = GeoMath.destination(me, 2000, 90);
  final southWest = GeoMath.destination(me, 3000, 220);

  Sighting exact(LatLng l, [double off = 0]) =>
      Sighting(l, GeoMath.bearing(me, l) + off);

  test('iki nişan, 90°: konum birkaç metre içinde; hata ±σ dörtgeni', () {
    final r = Resection.solve([exact(north), exact(east)]);
    expect(r.ok, isTrue);
    expect(GeoMath.distance(r.position!, me), lessThan(10));
    expect(r.bestAngle, closeTo(90, 0.5));
    expect(r.weak, isFalse);
    expect(r.errorPolygon, hasLength(4));
    // ±2° ile 2–2,5 km'de yanal hata ≈ 70–90 m.
    expect(r.errorRadius, inInclusiveRange(60, 160));
  });

  test('üç nişan: doğru kerterizlerde küçük, hatalıda büyük hata alanı', () {
    final good = Resection.solve([
      exact(north),
      exact(east),
      exact(southWest),
    ]);
    expect(GeoMath.distance(good.position!, me), lessThan(10));
    final bad = Resection.solve([
      exact(north),
      exact(east, 4), // 4° hatalı okuma
      exact(southWest),
    ]);
    expect(bad.ok, isTrue);
    expect(GeoMath.distance(bad.position!, me), lessThan(150));
    expect(bad.errorRadius, greaterThan(good.errorRadius));
    // Hata üçgeni + dörtgen tek dışbükey çokgende.
    expect(bad.errorPolygon.length, greaterThanOrEqualTo(3));
  });

  test('daha hassas pusula daha küçük hata alanı', () {
    final s = [exact(north), exact(east)];
    expect(
      Resection.solve(s, sigma: 1).errorRadius,
      lessThan(Resection.solve(s, sigma: 5).errorRadius),
    );
  });

  test('dar açı zayıf sayılır', () {
    final a = GeoMath.destination(me, 2000, 10);
    final b = GeoMath.destination(me, 2000, 30);
    final r = Resection.solve([exact(a), exact(b)]);
    expect(r.ok, isTrue);
    expect(r.bestAngle, closeTo(20, 0.5));
    expect(r.weak, isTrue);
  });

  test('çözülemeyenler: tek nişan, paralel, arkada kalan', () {
    expect(Resection.solve([exact(north)]).failure, ResectionFailure.tooFew);
    final far = GeoMath.destination(me, 5000, 0);
    expect(
      Resection.solve([exact(north), exact(far)]).failure,
      ResectionFailure.parallel,
    );
    // Ters okunan kerteriz (180° hatalı): çizgi aynı, nokta arkada.
    expect(
      Resection.solve([exact(north), exact(east, 180)]).failure,
      ResectionFailure.behind,
    );
  });
}
