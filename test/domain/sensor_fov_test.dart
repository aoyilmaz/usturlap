import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/domain/models/sensor_fov.dart';
import 'package:latlong2/latlong.dart';

/// E9: görüş konisi.
void main() {
  const c = LatLng(37.0, 37.0);

  test('geçerlilik', () {
    expect(SensorFov.isValid(45, 60, 1000), isTrue);
    expect(SensorFov.isValid(45, 360, 1), isTrue);
    expect(SensorFov.isValid(null, 60, 1000), isFalse);
    expect(SensorFov.isValid(45, 0, 1000), isFalse);
    expect(SensorFov.isValid(45, 361, 1000), isFalse);
    expect(SensorFov.isValid(45, 60, 0.5), isFalse);
    expect(SensorFov.isValid(45, 60, 200000), isFalse);
  });

  test('çokgen: merkez + yay, kenarlar yön ± açıklık/2, menzilde', () {
    const fov = SensorFov(azimuth: 90, width: 60, range: 1000);
    final poly = fov.polygon(c);
    expect(poly.first, c);
    final arc = poly.skip(1).toList();
    expect(GeoMath.bearing(c, arc.first) % 360, closeTo(60, 0.5));
    expect(GeoMath.bearing(c, arc.last) % 360, closeTo(120, 0.5));
    for (final p in arc) {
      expect(GeoMath.distance(c, p), closeTo(1000, 1));
    }
  });

  test('her yön (360°): tam daire', () {
    const fov = SensorFov(azimuth: 0, width: 360, range: 500);
    final arc = fov.polygon(c).skip(1).toList();
    expect(arc.length, greaterThan(100));
    expect(GeoMath.distance(arc.first, arc.last), lessThan(1));
  });

  group('depo', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('kur, kaldır; bozuk kayıt koni sayılmaz', () async {
      final repo = WaypointRepository(db);
      final id = await repo.add(name: 'SN-1', position: c);
      const fov = SensorFov(azimuth: 300, width: 90, range: 2500);
      await repo.setFov(id, fov);
      expect((await repo.watchAll().first).single.fov, fov);
      await repo.setFov(id, null);
      expect((await repo.watchAll().first).single.fov, isNull);
      // Yarım kayıt (yalnız yön) → koni yok.
      await db.customUpdate(
        'UPDATE waypoints SET fov_azimuth = 10',
        updates: {db.waypoints},
      );
      expect((await repo.watchAll().first).single.fov, isNull);
    });
  });
}
