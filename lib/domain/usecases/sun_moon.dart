import 'dart:math' as math;

/// Bir gün için güneş saatleri (UTC; gösterirken yerel saate çevrilir).
/// Kutup gecesi / gündüzünde ilgili saat null.
class SunTimes {
  const SunTimes({
    this.bmnt,
    this.bmct,
    this.sunrise,
    this.noon,
    this.sunset,
    this.eect,
    this.eent,
  });

  /// Sabah denizci alacakaranlığı başı (güneş −12°; BMNT).
  final DateTime? bmnt;

  /// Sabah sivil alacakaranlığı başı (−6°; BMCT).
  final DateTime? bmct;
  final DateTime? sunrise;
  final DateTime? noon;
  final DateTime? sunset;

  /// Akşam sivil alacakaranlığı sonu (−6°; EECT).
  final DateTime? eect;

  /// Akşam denizci alacakaranlığı sonu (−12°; EENT).
  final DateTime? eent;

  Duration? get daylight =>
      sunrise != null && sunset != null ? sunset!.difference(sunrise!) : null;
}

/// Ayın evresi.
enum MoonPhase {
  newMoon('Yeni Ay'),
  waxingCrescent('Büyüyen hilal'),
  firstQuarter('İlk dördün'),
  waxingGibbous('Büyüyen şişkin ay'),
  full('Dolunay'),
  waningGibbous('Küçülen şişkin ay'),
  lastQuarter('Son dördün'),
  waningCrescent('Küçülen hilal');

  const MoonPhase(this.label);
  final String label;

  /// Güneş–ay boylam farkından (0 yeni ay, 90 ilk dördün, 180 dolunay).
  static MoonPhase fromAngle(double e) {
    final a = e % 360;
    if (a < 10 || a >= 350) return newMoon;
    if (a < 80) return waxingCrescent;
    if (a < 100) return firstQuarter;
    if (a < 170) return waxingGibbous;
    if (a < 190) return full;
    if (a < 260) return waningGibbous;
    if (a < 280) return lastQuarter;
    return waningCrescent;
  }
}

/// Bir gün için ay bilgisi (doğuş / batış UTC; o gün yoksa null).
class MoonInfo {
  const MoonInfo({
    required this.phase,
    required this.illumination,
    this.rise,
    this.set,
  });

  final MoonPhase phase;

  /// Aydınlık kısım (0–1).
  final double illumination;
  final DateTime? rise;
  final DateTime? set;
}

/// Şu anki ışık durumu (gece operasyonu planı).
enum LightCondition {
  day('Gündüz'),
  civilTwilight('Sivil alacakaranlık'),
  nauticalTwilight('Denizci alacakaranlığı'),
  night('Gece');

  const LightCondition(this.label);
  final String label;
}

/// Güneş ve ay hesapları (internetsiz, cihazda). Güneş: "gün doğumu
/// denklemi" (≈1 dk); ay: Astronomical Almanac düşük duyarlıklı formülleri
/// (konum ≈0,3°, doğuş / batış birkaç dakika).
class SunMoon {
  SunMoon._();

  static const _rad = math.pi / 180;
  static const _deg = 180 / math.pi;

  static double _sin(double d) => math.sin(d * _rad);
  static double _cos(double d) => math.cos(d * _rad);

  static double julian(DateTime t) =>
      t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  static DateTime fromJulian(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - 2440587.5) * 86400000).round(),
    isUtc: true,
  );

  // ------------------------------------------------------------------ güneş

  /// Güneşin görünür ekliptik boylamı (°) ve dik açıklığı (°).
  static ({double lambda, double dec}) _sun(double jd) {
    final d = jd - 2451545.0;
    final m = (357.5291 + 0.98560028 * d) % 360;
    final c = 1.9148 * _sin(m) + 0.0200 * _sin(2 * m) + 0.0003 * _sin(3 * m);
    final lambda = (m + c + 180 + 102.9372) % 360;
    final dec = math.asin(_sin(lambda) * _sin(23.4397)) * _deg;
    return (lambda: lambda, dec: dec);
  }

  /// [day] (yerel tarih; yalnız yıl/ay/gün kullanılır) için güneş saatleri.
  /// [lon] doğu pozitif.
  static SunTimes sunTimes(DateTime day, double lat, double lon) {
    final jDate = julian(DateTime.utc(day.year, day.month, day.day, 12));
    final n = (jDate - 2451545.0 + 0.0008).roundToDouble();
    final jStar = n - lon / 360;
    final m = (357.5291 + 0.98560028 * jStar) % 360;
    final c = 1.9148 * _sin(m) + 0.0200 * _sin(2 * m) + 0.0003 * _sin(3 * m);
    final lambda = (m + c + 180 + 102.9372) % 360;
    final transit =
        2451545.0 + jStar + 0.0053 * _sin(m) - 0.0069 * _sin(2 * lambda);
    final dec = math.asin(_sin(lambda) * _sin(23.4397)) * _deg;

    ({DateTime? rise, DateTime? set}) at(double h0) {
      final cosW = (_sin(h0) - _sin(lat) * _sin(dec)) / (_cos(lat) * _cos(dec));
      if (cosW < -1 || cosW > 1) return (rise: null, set: null);
      final w = math.acos(cosW) * _deg;
      return (
        rise: fromJulian(transit - w / 360),
        set: fromJulian(transit + w / 360),
      );
    }

    final official = at(-0.833);
    final civil = at(-6);
    final nautical = at(-12);
    return SunTimes(
      bmnt: nautical.rise,
      bmct: civil.rise,
      sunrise: official.rise,
      noon: fromJulian(transit),
      sunset: official.set,
      eect: civil.set,
      eent: nautical.set,
    );
  }

  /// Güneşin [t] anındaki yüksekliği (°).
  static double sunAltitude(DateTime t, double lat, double lon) {
    final jd = julian(t);
    final s = _sun(jd);
    final ra =
        math.atan2(_cos(23.4397) * _sin(s.lambda), _cos(s.lambda)) * _deg;
    return _altitude(jd, lat, lon, ra, s.dec);
  }

  static LightCondition lightAt(DateTime t, double lat, double lon) {
    final a = sunAltitude(t, lat, lon);
    if (a > -0.833) return LightCondition.day;
    if (a > -6) return LightCondition.civilTwilight;
    if (a > -12) return LightCondition.nauticalTwilight;
    return LightCondition.night;
  }

  // -------------------------------------------------------------------- ay

  /// Ayın ekliptik boylam / enlemi ve yatay paralaksı (°).
  static ({double lambda, double beta, double parallax}) _moonEcliptic(
    double jd,
  ) {
    final t = (jd - 2451545.0) / 36525;
    final lambda =
        (218.32 +
            481267.881 * t +
            6.29 * _sin(135.0 + 477198.87 * t) -
            1.27 * _sin(259.3 - 413335.36 * t) +
            0.66 * _sin(235.7 + 890534.22 * t) +
            0.21 * _sin(269.9 + 954397.74 * t) -
            0.19 * _sin(357.5 + 35999.05 * t) -
            0.11 * _sin(186.5 + 966404.03 * t)) %
        360;
    final beta =
        5.13 * _sin(93.3 + 483202.02 * t) +
        0.28 * _sin(228.2 + 960400.89 * t) -
        0.28 * _sin(318.3 + 6003.15 * t) -
        0.17 * _sin(217.6 - 407332.21 * t);
    final parallax =
        0.9508 +
        0.0518 * _cos(135.0 + 477198.87 * t) +
        0.0095 * _cos(259.3 - 413335.36 * t) +
        0.0078 * _cos(235.7 + 890534.22 * t) +
        0.0028 * _cos(269.9 + 954397.74 * t);
    return (lambda: lambda, beta: beta, parallax: parallax);
  }

  static double _altitude(
    double jd,
    double lat,
    double lon,
    double ra,
    double dec,
  ) {
    final gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0);
    final h = gmst + lon - ra;
    return math.asin(_sin(lat) * _sin(dec) + _cos(lat) * _cos(dec) * _cos(h)) *
        _deg;
  }

  /// Ayın yer merkezli yüksekliği (°) ve paralaksı.
  static ({double alt, double parallax}) _moonAlt(
    double jd,
    double lat,
    double lon,
  ) {
    final m = _moonEcliptic(jd);
    final t = (jd - 2451545.0) / 36525;
    final eps = 23.4393 - 0.0130 * t;
    final sinDec =
        _sin(m.beta) * _cos(eps) + _cos(m.beta) * _sin(eps) * _sin(m.lambda);
    final dec = math.asin(sinDec) * _deg;
    final ra =
        math.atan2(
          _sin(m.lambda) * _cos(eps) - _sin(m.beta) / _cos(m.beta) * _sin(eps),
          _cos(m.lambda),
        ) *
        _deg;
    return (alt: _altitude(jd, lat, lon, ra, dec), parallax: m.parallax);
  }

  /// [t] anındaki ay evresi ve aydınlık kısmı.
  static ({MoonPhase phase, double illumination, double angle}) moonPhaseAt(
    DateTime t,
  ) {
    final jd = julian(t);
    final e = (_moonEcliptic(jd).lambda - _sun(jd).lambda) % 360;
    return (
      phase: MoonPhase.fromAngle(e),
      illumination: (1 - _cos(e)) / 2,
      angle: e,
    );
  }

  /// [day] (yerel gün; [dayStart] o günün yerel 00:00'ı) için ay bilgisi.
  /// Doğuş / batış 10 dk adımla taranıp ara değerle bulunur.
  static MoonInfo moonInfo(DateTime dayStart, double lat, double lon) {
    DateTime? rise, set;
    double f(DateTime t) {
      final m = _moonAlt(julian(t), lat, lon);
      // Ufuk: yer merkezli yükseklik için h0 = 0,7275·π − 34′ (Meeus).
      return m.alt - (0.7275 * m.parallax - 0.5667);
    }

    const step = Duration(minutes: 10);
    var prevT = dayStart;
    var prev = f(prevT);
    for (var i = 1; i <= 144; i++) {
      final t = dayStart.add(step * i);
      final v = f(t);
      if (prev.sign != v.sign) {
        final frac = prev / (prev - v);
        final at = prevT.add(
          Duration(milliseconds: (step.inMilliseconds * frac).round()),
        );
        if (prev < 0 && v >= 0) {
          rise ??= at.toUtc();
        } else if (prev >= 0 && v < 0) {
          set ??= at.toUtc();
        }
      }
      prevT = t;
      prev = v;
    }
    final p = moonPhaseAt(dayStart.add(const Duration(hours: 12)));
    return MoonInfo(
      phase: p.phase,
      illumination: p.illumination,
      rise: rise,
      set: set,
    );
  }
}
