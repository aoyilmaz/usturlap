import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../core/nav_math.dart';

/// Rota boyunca bir örnek: başlangıçtan mesafe, konum, yükseklik (yoksa null).
class RouteProfileSample {
  const RouteProfileSample(this.distance, this.point, this.elevation);

  final double distance;
  final LatLng point;
  final double? elevation;
}

/// Bir rota ya da çizgi boyunca yükseklik profili (ATAK Routes s.15–19,
/// Elevation Tools s.48): toplam çıkış / iniş, en yüksek / en alçak, en dik
/// çıkış / iniş eğimi. Yükseklik kaynağı dışarıdan verilir (arazi verisi),
/// hesap saf Dart.
class RouteProfile {
  const RouteProfile(this.samples, this.pointDistances);

  final List<RouteProfileSample> samples;

  /// Her rota noktasının başlangıçtan mesafesi (grafikteki dikey çizgiler).
  final List<double> pointDistances;

  double get length => samples.isEmpty ? 0 : samples.last.distance;

  Iterable<double> get _known => samples.map((s) => s.elevation).nonNulls;

  bool get hasData => _known.isNotEmpty;

  double? get minElevation => hasData ? _known.reduce(math.min) : null;
  double? get maxElevation => hasData ? _known.reduce(math.max) : null;

  /// Toplam çıkış (m): ardışık bilinen yükseklikler arasındaki artışlar.
  double get ascent => _sum(up: true);

  /// Toplam iniş (m, pozitif).
  double get descent => _sum(up: false);

  double _sum({required bool up}) {
    var total = 0.0;
    double? prev;
    for (final e in samples.map((s) => s.elevation)) {
      if (e == null) continue;
      if (prev != null) {
        final d = e - prev;
        if (up ? d > 0 : d < 0) total += d.abs();
      }
      prev = e;
    }
    return total;
  }

  /// Ardışık bilinen örnekler arasındaki eğimler (%; + çıkış), örnek
  /// çiftinin başlangıç mesafesiyle.
  List<(double distance, double grade)> get grades {
    final out = <(double, double)>[];
    RouteProfileSample? prev;
    for (final s in samples) {
      if (s.elevation == null) {
        prev = null; // boşluğun üstünden eğim hesaplanmaz
        continue;
      }
      final p = prev;
      if (p != null && s.distance - p.distance >= 1) {
        out.add((
          p.distance,
          (s.elevation! - p.elevation!) / (s.distance - p.distance) * 100,
        ));
      }
      prev = s;
    }
    return out;
  }

  /// En dik çıkış (%, ≥ 0) ve en dik iniş (%, ≤ 0).
  double get maxClimb => grades.fold(0.0, (m, g) => math.max(m, g.$2));
  double get maxDescent => grades.fold(0.0, (m, g) => math.min(m, g.$2));

  /// Örnek aralığı: uzunluğun 1/200'ü, 20 m ile 500 m arası (SRTM ~30 m).
  static double defaultStep(double length) => (length / 200).clamp(20, 500);

  /// Her köşe ve aralarında [step] m'de bir nokta (başlangıçtan mesafesiyle).
  static List<(double, LatLng)> sampleAlong(List<LatLng> pts, double step) {
    if (pts.isEmpty) return const [];
    final out = <(double, LatLng)>[(0, pts.first)];
    var base = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final leg = NavMath.distance(a, b);
      final brg = NavMath.bearing(a, b);
      for (var d = step; d < leg; d += step) {
        out.add((base + d, GeoMath.destination(a, d, brg)));
      }
      base += leg;
      out.add((base, b));
    }
    return out;
  }

  /// Profili kurar; [elevationAt] her örnek için çağrılır (null = veri yok).
  static Future<RouteProfile> build(
    List<LatLng> pts,
    Future<double?> Function(LatLng) elevationAt, {
    double? step,
  }) async {
    var length = 0.0;
    final pointDistances = <double>[0];
    for (var i = 0; i < pts.length - 1; i++) {
      length += NavMath.distance(pts[i], pts[i + 1]);
      pointDistances.add(length);
    }
    final samples = <RouteProfileSample>[];
    for (final (d, p) in sampleAlong(pts, step ?? defaultStep(length))) {
      samples.add(RouteProfileSample(d, p, await elevationAt(p)));
    }
    return RouteProfile(samples, pointDistances);
  }
}
