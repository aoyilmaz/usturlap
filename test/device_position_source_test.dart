import 'package:flutter_test/flutter_test.dart';

import 'package:pusula/data/position/device_position_source.dart';

void main() {
  group('DevicePositionSource.buildSelfContact', () {
    final t = DateTime(2026, 1, 1, 12);

    test('geçerli değerleri Contact alanlarına çevirir', () {
      final c = DevicePositionSource.buildSelfContact(
        callsign: 'PUSULA-1',
        latitude: 39.92,
        longitude: 32.86,
        timestamp: t,
        speedMps: 5.0,
        altitudeMeters: 950.0,
        headingDeg: 90.0,
      );
      expect(c.isSelf, true);
      expect(c.position.latitude, 39.92);
      expect(c.speedMps, 5.0);
      expect(c.altitudeMsl, 950.0);
      expect(c.headingDeg, 90.0);
    });

    test('geçersiz hız/kerteriz (negatif, NaN) null olur', () {
      final c = DevicePositionSource.buildSelfContact(
        callsign: 'X',
        latitude: 0,
        longitude: 0,
        timestamp: t,
        speedMps: -1.0,
        altitudeMeters: double.nan,
        headingDeg: -1.0,
      );
      expect(c.speedMps, isNull);
      expect(c.altitudeMsl, isNull);
      expect(c.headingDeg, isNull);
    });

    test('kerteriz 360 ile modlanır', () {
      final c = DevicePositionSource.buildSelfContact(
        callsign: 'X',
        latitude: 0,
        longitude: 0,
        timestamp: t,
        headingDeg: 450.0,
      );
      expect(c.headingDeg, 90.0);
    });

    test('doğruluk (accuracy) Contact\'a aktarılır; negatif null olur', () {
      final ok = DevicePositionSource.buildSelfContact(
        callsign: 'X',
        latitude: 0,
        longitude: 0,
        timestamp: t,
        accuracyMeters: 12.5,
      );
      expect(ok.accuracyMeters, 12.5);

      final bad = DevicePositionSource.buildSelfContact(
        callsign: 'X',
        latitude: 0,
        longitude: 0,
        timestamp: t,
        accuracyMeters: -1,
      );
      expect(bad.accuracyMeters, isNull);
    });
  });
}
