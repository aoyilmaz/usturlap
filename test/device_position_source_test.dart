import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:usturlap/data/position/device_position_source.dart';

void main() {
  group('DevicePositionSource.buildSelfContact', () {
    final t = DateTime(2026, 1, 1, 12);

    test('geçerli değerleri Contact alanlarına çevirir', () {
      final c = DevicePositionSource.buildSelfContact(
        callsign: 'USTURLAP-1',
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

  group('DevicePositionSource.normalizeCompass', () {
    const android = TargetPlatform.android, ios = TargetPlatform.iOS;

    test('Android: eksi açılar (batı yarım daire) 0–360\'a sarılır', () {
      // flutter_compass Android −180…180 verir: batı = −90.
      expect(DevicePositionSource.normalizeCompass(-90, android), 270);
      expect(DevicePositionSource.normalizeCompass(-179, android), 181);
      expect(DevicePositionSource.normalizeCompass(-1, android), 359);
      expect(DevicePositionSource.normalizeCompass(90, android), 90);
      expect(DevicePositionSource.normalizeCompass(180, android), 180);
      expect(DevicePositionSource.normalizeCompass(0, android), 0);
    });

    test('iOS: −1 "geçersiz" demektir, atılır', () {
      expect(DevicePositionSource.normalizeCompass(-1, ios), isNull);
      expect(DevicePositionSource.normalizeCompass(270, ios), 270);
    });

    test('boş ve sayı olmayan değer atılır', () {
      expect(DevicePositionSource.normalizeCompass(null, android), isNull);
      expect(
        DevicePositionSource.normalizeCompass(double.nan, android),
        isNull,
      );
    });
  });

  group('DevicePositionSource.buildLocationSettings', () {
    test('Android: saniyede bir konum ve MSL yükseklik', () {
      final s =
          DevicePositionSource.buildLocationSettings(
                background: false,
                platform: TargetPlatform.android,
              )
              as AndroidSettings;
      expect(s.intervalDuration, const Duration(seconds: 1));
      expect(s.useMSLAltitude, isTrue);
      expect(s.foregroundNotificationConfig, isNull);
    });

    test(
      'Android: arka planda ön plan servisi bildirimi, kendi simgesiyle',
      () {
        final s =
            DevicePositionSource.buildLocationSettings(
                  background: true,
                  platform: TargetPlatform.android,
                )
                as AndroidSettings;
        expect(s.foregroundNotificationConfig, isNotNull);
        expect(
          s.foregroundNotificationConfig!.notificationIcon.name,
          'ic_stat_usturlap',
        );
      },
    );

    test('iOS: arka plan güncellemesi yalnız istenince', () {
      final off =
          DevicePositionSource.buildLocationSettings(
                background: false,
                platform: TargetPlatform.iOS,
              )
              as AppleSettings;
      final on =
          DevicePositionSource.buildLocationSettings(
                background: true,
                platform: TargetPlatform.iOS,
              )
              as AppleSettings;
      expect(off.allowBackgroundLocationUpdates, isFalse);
      expect(on.allowBackgroundLocationUpdates, isTrue);
    });
  });
}
