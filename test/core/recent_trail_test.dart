import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/core/recent_trail.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 7, 12);
  const start = LatLng(39.9, 32.85);
  LatLng north(double m) => GeoMath.destination(start, m, 0);

  test('5 m\'den yakın konum (durağan titreme) eklenmez', () {
    final trail = RecentTrail();
    expect(trail.add(start, t0), isTrue);
    expect(trail.add(north(3), t0.add(const Duration(seconds: 1))), isFalse);
    expect(trail.add(north(8), t0.add(const Duration(seconds: 2))), isTrue);
    expect(trail.points, hasLength(2));
  });

  test('15 dakikadan eski noktalar atılır', () {
    final trail = RecentTrail();
    for (var i = 0; i < 20; i++) {
      trail.add(north(i * 10.0), t0.add(Duration(minutes: i)));
    }
    // Son nokta 19. dk'da: 4. dk ve öncesi (15 dk'dan eski) atıldı.
    expect(trail.points, hasLength(16));
    expect(GeoMath.distance(trail.points.first, north(40)), lessThan(0.5));
  });

  test('yer değişmese de zaman geçince eskiler atılır', () {
    final trail = RecentTrail();
    trail.add(start, t0);
    trail.add(north(20), t0.add(const Duration(minutes: 1)));
    expect(
      trail.prune(t0.add(const Duration(minutes: 15, seconds: 30))),
      isTrue,
    );
    expect(trail.points, hasLength(1));
  });
}
