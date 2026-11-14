import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/usecases/sun_moon.dart';

/// Güneş ve ay: referans ABD Deniz Gözlemevi (USNO) API'si, Ankara
/// (39.9334 K, 32.8597 D), UTC+3; ±2 dk.
void main() {
  const lat = 39.9334, lon = 32.8597;
  const tz = Duration(hours: 3);

  void near(DateTime? t, int h, int m, {String? why}) {
    expect(t, isNotNull, reason: why);
    final local = t!.toUtc().add(tz);
    final want = DateTime.utc(local.year, local.month, local.day, h, m);
    expect(
      local.difference(want).inSeconds.abs(),
      lessThanOrEqualTo(120),
      reason: '$why: ${local.hour}:${local.minute} ≠ $h:$m',
    );
  }

  DateTime dayStart(int y, int mo, int d) =>
      DateTime.utc(y, mo, d).subtract(tz);

  test('15 Kasım 2026: güneş ve ay', () {
    final s = SunMoon.sunTimes(DateTime(2026, 11, 15), lat, lon);
    near(s.bmct, 7, 4, why: 'sivil alacakaranlık başı');
    near(s.sunrise, 7, 33, why: 'doğuş');
    near(s.noon, 12, 33, why: 'öğle');
    near(s.sunset, 17, 33, why: 'batış');
    near(s.eect, 18, 2, why: 'sivil alacakaranlık sonu');
    // Denizci alacakaranlığı sivilden önce / sonra.
    expect(s.bmnt!.isBefore(s.bmct!), isTrue);
    expect(s.eent!.isAfter(s.eect!), isTrue);
    final m = SunMoon.moonInfo(dayStart(2026, 11, 15), lat, lon);
    near(m.rise, 12, 42, why: 'ay doğuşu');
    near(m.set, 22, 26, why: 'ay batışı');
    expect(m.illumination, closeTo(0.30, 0.03));
    expect(m.phase, MoonPhase.waxingCrescent);
  });

  test('21 Haziran 2026: güneş ve ay (gece yarısından sonra batış)', () {
    final s = SunMoon.sunTimes(DateTime(2026, 6, 21), lat, lon);
    near(s.bmct, 4, 47, why: 'sivil alacakaranlık başı');
    near(s.sunrise, 5, 20, why: 'doğuş');
    near(s.noon, 12, 50, why: 'öğle');
    near(s.sunset, 20, 21, why: 'batış');
    near(s.eect, 20, 53, why: 'sivil alacakaranlık sonu');
    expect(s.daylight!.inMinutes, closeTo(15 * 60, 5));
    final m = SunMoon.moonInfo(dayStart(2026, 6, 21), lat, lon);
    near(m.set, 0, 15, why: 'ay batışı');
    near(m.rise, 12, 23, why: 'ay doğuşu');
    expect(m.illumination, closeTo(0.45, 0.03));
  });

  test('kutup gecesi: güneş doğmaz; ışık durumu', () {
    final s = SunMoon.sunTimes(DateTime(2026, 12, 21), 78.2, 15.6);
    expect(s.sunrise, isNull);
    expect(s.sunset, isNull);
    expect(
      SunMoon.lightAt(DateTime.utc(2026, 11, 15, 9, 33), lat, lon),
      LightCondition.day,
    );
    expect(
      SunMoon.lightAt(DateTime.utc(2026, 11, 15, 21), lat, lon),
      LightCondition.night,
    );
    // Gün batımından ~15 dk sonra sivil alacakaranlık.
    expect(
      SunMoon.lightAt(DateTime.utc(2026, 11, 15, 14, 48), lat, lon),
      LightCondition.civilTwilight,
    );
  });

  test('ay evresi adları', () {
    expect(MoonPhase.fromAngle(2), MoonPhase.newMoon);
    expect(MoonPhase.fromAngle(90), MoonPhase.firstQuarter);
    expect(MoonPhase.fromAngle(180), MoonPhase.full);
    expect(MoonPhase.fromAngle(300), MoonPhase.waningCrescent);
  });
}
