import 'dart:math' as math;

/// Bir noktadaki yer manyetik alanı (WMM çıktısı).
class MagneticField {
  const MagneticField({
    required this.declination,
    required this.inclination,
    required this.north,
    required this.east,
    required this.down,
  });

  /// Manyetik sapma (derece). Doğu (+), batı (−).
  /// Manyetik kerteriz = coğrafi kerteriz − sapma.
  final double declination;

  /// Eğim açısı (derece). Aşağı (+).
  final double inclination;

  /// Kuzey (X), doğu (Y), aşağı (Z) bileşenleri — nanotesla.
  final double north, east, down;

  /// Yatay şiddet H (nT).
  double get horizontal => math.sqrt(north * north + east * east);

  /// Toplam şiddet F (nT).
  double get total => math.sqrt(north * north + east * east + down * down);
}

/// NOAA **World Magnetic Model 2025** (WMM2025), saf Dart.
///
/// İnternet gerektirmez: katsayılar aşağıda gömülü (NOAA/NCEI, kamu malı;
/// `WMM2025.COF`, 13 Kasım 2024). Model 2025.0–2030.0 için geçerli; dışında
/// da hesaplar ama doğruluk düşer.
///
/// Yöntem WMM teknik raporundaki standart küresel harmonik açılımı:
/// jeodezik → jeosentrik dönüşüm, Schmidt yarı-normalize Legendre
/// fonksiyonları (Gauss normunda özyineleme + dönüşüm katsayıları), alanın
/// jeodezik çerçeveye geri döndürülmesi.
class Wmm {
  Wmm._();

  /// Katsayıların referans yılı.
  static const double epoch = 2025.0;

  /// Modelin geçerli olduğu son yıl.
  static const double validUntil = 2030.0;

  static const int _nMax = 12;

  /// [n, m, g, h, ġ, ḣ] — g/h nT, ġ/ḣ nT/yıl.
  static const List<List<double>> _cof = [
    [1, 0, -29351.8, 0.0, 12.0, 0.0],
    [1, 1, -1410.8, 4545.4, 9.7, -21.5],
    [2, 0, -2556.6, 0.0, -11.6, 0.0],
    [2, 1, 2951.1, -3133.6, -5.2, -27.7],
    [2, 2, 1649.3, -815.1, -8.0, -12.1],
    [3, 0, 1361.0, 0.0, -1.3, 0.0],
    [3, 1, -2404.1, -56.6, -4.2, 4.0],
    [3, 2, 1243.8, 237.5, 0.4, -0.3],
    [3, 3, 453.6, -549.5, -15.6, -4.1],
    [4, 0, 895.0, 0.0, -1.6, 0.0],
    [4, 1, 799.5, 278.6, -2.4, -1.1],
    [4, 2, 55.7, -133.9, -6.0, 4.1],
    [4, 3, -281.1, 212.0, 5.6, 1.6],
    [4, 4, 12.1, -375.6, -7.0, -4.4],
    [5, 0, -233.2, 0.0, 0.6, 0.0],
    [5, 1, 368.9, 45.4, 1.4, -0.5],
    [5, 2, 187.2, 220.2, 0.0, 2.2],
    [5, 3, -138.7, -122.9, 0.6, 0.4],
    [5, 4, -142.0, 43.0, 2.2, 1.7],
    [5, 5, 20.9, 106.1, 0.9, 1.9],
    [6, 0, 64.4, 0.0, -0.2, 0.0],
    [6, 1, 63.8, -18.4, -0.4, 0.3],
    [6, 2, 76.9, 16.8, 0.9, -1.6],
    [6, 3, -115.7, 48.8, 1.2, -0.4],
    [6, 4, -40.9, -59.8, -0.9, 0.9],
    [6, 5, 14.9, 10.9, 0.3, 0.7],
    [6, 6, -60.7, 72.7, 0.9, 0.9],
    [7, 0, 79.5, 0.0, -0.0, 0.0],
    [7, 1, -77.0, -48.9, -0.1, 0.6],
    [7, 2, -8.8, -14.4, -0.1, 0.5],
    [7, 3, 59.3, -1.0, 0.5, -0.8],
    [7, 4, 15.8, 23.4, -0.1, 0.0],
    [7, 5, 2.5, -7.4, -0.8, -1.0],
    [7, 6, -11.1, -25.1, -0.8, 0.6],
    [7, 7, 14.2, -2.3, 0.8, -0.2],
    [8, 0, 23.2, 0.0, -0.1, 0.0],
    [8, 1, 10.8, 7.1, 0.2, -0.2],
    [8, 2, -17.5, -12.6, 0.0, 0.5],
    [8, 3, 2.0, 11.4, 0.5, -0.4],
    [8, 4, -21.7, -9.7, -0.1, 0.4],
    [8, 5, 16.9, 12.7, 0.3, -0.5],
    [8, 6, 15.0, 0.7, 0.2, -0.6],
    [8, 7, -16.8, -5.2, -0.0, 0.3],
    [8, 8, 0.9, 3.9, 0.2, 0.2],
    [9, 0, 4.6, 0.0, -0.0, 0.0],
    [9, 1, 7.8, -24.8, -0.1, -0.3],
    [9, 2, 3.0, 12.2, 0.1, 0.3],
    [9, 3, -0.2, 8.3, 0.3, -0.3],
    [9, 4, -2.5, -3.3, -0.3, 0.3],
    [9, 5, -13.1, -5.2, 0.0, 0.2],
    [9, 6, 2.4, 7.2, 0.3, -0.1],
    [9, 7, 8.6, -0.6, -0.1, -0.2],
    [9, 8, -8.7, 0.8, 0.1, 0.4],
    [9, 9, -12.9, 10.0, -0.1, 0.1],
    [10, 0, -1.3, 0.0, 0.1, 0.0],
    [10, 1, -6.4, 3.3, 0.0, 0.0],
    [10, 2, 0.2, 0.0, 0.1, -0.0],
    [10, 3, 2.0, 2.4, 0.1, -0.2],
    [10, 4, -1.0, 5.3, -0.0, 0.1],
    [10, 5, -0.6, -9.1, -0.3, -0.1],
    [10, 6, -0.9, 0.4, 0.0, 0.1],
    [10, 7, 1.5, -4.2, -0.1, 0.0],
    [10, 8, 0.9, -3.8, -0.1, -0.1],
    [10, 9, -2.7, 0.9, -0.0, 0.2],
    [10, 10, -3.9, -9.1, -0.0, -0.0],
    [11, 0, 2.9, 0.0, 0.0, 0.0],
    [11, 1, -1.5, 0.0, -0.0, -0.0],
    [11, 2, -2.5, 2.9, 0.0, 0.1],
    [11, 3, 2.4, -0.6, 0.0, -0.0],
    [11, 4, -0.6, 0.2, 0.0, 0.1],
    [11, 5, -0.1, 0.5, -0.1, -0.0],
    [11, 6, -0.6, -0.3, 0.0, -0.0],
    [11, 7, -0.1, -1.2, -0.0, 0.1],
    [11, 8, 1.1, -1.7, -0.1, -0.0],
    [11, 9, -1.0, -2.9, -0.1, 0.0],
    [11, 10, -0.2, -1.8, -0.1, 0.0],
    [11, 11, 2.6, -2.3, -0.1, 0.0],
    [12, 0, -2.0, 0.0, 0.0, 0.0],
    [12, 1, -0.2, -1.3, 0.0, -0.0],
    [12, 2, 0.3, 0.7, -0.0, 0.0],
    [12, 3, 1.2, 1.0, -0.0, -0.1],
    [12, 4, -1.3, -1.4, -0.0, 0.1],
    [12, 5, 0.6, -0.0, -0.0, -0.0],
    [12, 6, 0.6, 0.6, 0.1, -0.0],
    [12, 7, 0.5, -0.1, -0.0, -0.0],
    [12, 8, -0.1, 0.8, 0.0, 0.0],
    [12, 9, -0.4, 0.1, 0.0, -0.0],
    [12, 10, -0.2, -1.0, -0.1, -0.0],
    [12, 11, -1.3, 0.1, -0.0, 0.0],
    [12, 12, -0.7, 0.2, -0.1, -0.1],
  ];

  /// [date] için ondalık yıl (ör. 2026-07-02 → ~2026.5).
  static double decimalYear(DateTime date) {
    final d = date.toUtc();
    final start = DateTime.utc(d.year);
    final end = DateTime.utc(d.year + 1);
    return d.year +
        d.difference(start).inMicroseconds /
            end.difference(start).inMicroseconds;
  }

  /// Tam alan hesabı. [altitudeKm]: WGS84 elipsoidi üstü yükseklik (km).
  static MagneticField field(
    double latitudeDeg,
    double longitudeDeg, {
    double altitudeKm = 0,
    required double decimalYear,
  }) {
    const a = 6378.137; // WGS84 büyük yarı eksen (km)
    const f = 1 / 298.257223563; // WGS84 basıklık
    const e2 = f * (2 - f);
    const re = 6371.2; // jeomanyetik referans yarıçapı (km)
    const n1 = _nMax + 1;

    final phi = latitudeDeg * math.pi / 180;
    final lambda = longitudeDeg * math.pi / 180;

    // 1) Jeodezik → jeosentrik küresel koordinat.
    final sinPhi = math.sin(phi), cosPhi = math.cos(phi);
    final rc = a / math.sqrt(1 - e2 * sinPhi * sinPhi);
    final p = (rc + altitudeKm) * cosPhi;
    final z = (rc * (1 - e2) + altitudeKm) * sinPhi;
    final r = math.sqrt(p * p + z * z);
    final phiC = math.asin(z / r); // jeosentrik enlem

    // 2) Zamana göre katsayılar, Schmidt → Gauss normuna çevrilmiş.
    final dt = decimalYear - epoch;
    final g = List.generate(n1, (_) => List<double>.filled(n1, 0));
    final h = List.generate(n1, (_) => List<double>.filled(n1, 0));
    final s = List.generate(n1, (_) => List<double>.filled(n1, 0));
    s[0][0] = 1;
    for (var n = 1; n <= _nMax; n++) {
      s[n][0] = s[n - 1][0] * (2 * n - 1) / n;
      for (var m = 1; m <= n; m++) {
        final j = m == 1 ? 2 : 1;
        s[n][m] = s[n][m - 1] * math.sqrt((n - m + 1) * j / (n + m));
      }
    }
    for (final c in _cof) {
      final n = c[0].toInt(), m = c[1].toInt();
      g[n][m] = (c[2] + dt * c[4]) * s[n][m];
      h[n][m] = (c[3] + dt * c[5]) * s[n][m];
    }

    // 3) Legendre fonksiyonları ve θ'ya (kutup uzaklığı) göre türevleri.
    final ct = math.sin(phiC); // cos θ
    final st = math.cos(phiC); // sin θ
    final pnm = List.generate(n1, (_) => List<double>.filled(n1, 0));
    final dp = List.generate(n1, (_) => List<double>.filled(n1, 0));
    pnm[0][0] = 1;
    for (var n = 1; n <= _nMax; n++) {
      for (var m = 0; m <= n; m++) {
        if (n == m) {
          pnm[n][m] = st * pnm[n - 1][m - 1];
          dp[n][m] = st * dp[n - 1][m - 1] + ct * pnm[n - 1][m - 1];
        } else if (n == 1) {
          pnm[n][m] = ct * pnm[0][0];
          dp[n][m] = ct * dp[0][0] - st * pnm[0][0];
        } else {
          final k = ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
          final p2 = m <= n - 2 ? pnm[n - 2][m] : 0.0;
          final d2 = m <= n - 2 ? dp[n - 2][m] : 0.0;
          pnm[n][m] = ct * pnm[n - 1][m] - k * p2;
          dp[n][m] = ct * dp[n - 1][m] - st * pnm[n - 1][m] - k * d2;
        }
      }
    }

    // 4) Alan bileşenleri (küresel çerçeve).
    var br = 0.0, bt = 0.0, bp = 0.0;
    for (var n = 1; n <= _nMax; n++) {
      final ar = math.pow(re / r, n + 2).toDouble();
      for (var m = 0; m <= n; m++) {
        final cm = math.cos(m * lambda), sm = math.sin(m * lambda);
        final t1 = g[n][m] * cm + h[n][m] * sm;
        final t2 = g[n][m] * sm - h[n][m] * cm;
        br += ar * (n + 1) * t1 * pnm[n][m];
        bt -= ar * t1 * dp[n][m];
        bp += ar * m * t2 * pnm[n][m];
      }
    }
    // Coğrafi kutupta sin θ = 0: doğu bileşeni tanımsız (Pusula için önemsiz).
    if (st.abs() > 1e-10) bp /= st;

    final xs = -bt, ys = bp, zs = -br;

    // 5) Jeosentrik → jeodezik çerçeve.
    final psi = phiC - phi;
    final x = xs * math.cos(psi) - zs * math.sin(psi);
    final y = ys;
    final zz = xs * math.sin(psi) + zs * math.cos(psi);

    const deg = 180 / math.pi;
    return MagneticField(
      declination: math.atan2(y, x) * deg,
      inclination: math.atan2(zz, math.sqrt(x * x + y * y)) * deg,
      north: x,
      east: y,
      down: zz,
    );
  }

  // Son hesap (HUD saniyede onlarca kez sorar; sapma çok yavaş değişir).
  static String? _lastKey;
  static double _lastDecl = 0;

  /// [latitudeDeg], [longitudeDeg] için manyetik sapma (derece, doğu +).
  /// ~1 km ve 1 gün hassasiyetle önbelleğe alınır.
  static double declination(
    double latitudeDeg,
    double longitudeDeg, {
    DateTime? date,
  }) {
    final d = date ?? DateTime.now();
    final key =
        '${(latitudeDeg * 100).round()}:${(longitudeDeg * 100).round()}'
        ':${d.year}-${d.month}-${d.day}';
    if (key == _lastKey) return _lastDecl;
    _lastDecl = field(
      latitudeDeg,
      longitudeDeg,
      decimalYear: decimalYear(d),
    ).declination;
    _lastKey = key;
    return _lastDecl;
  }
}
