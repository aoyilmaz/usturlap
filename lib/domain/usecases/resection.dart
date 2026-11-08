import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Bir nişan: bilinen bir nokta ve benden ona alınan coğrafi kerteriz.
class Sighting {
  const Sighting(this.landmark, this.trueBearing);

  final LatLng landmark;

  /// Gözlemciden noktaya, coğrafi kuzeye göre derece.
  final double trueBearing;
}

/// Neden çözülemedi.
enum ResectionFailure {
  /// En az iki nişan gerekir.
  tooFew,

  /// Çizgiler (neredeyse) paralel: kesişme yok.
  parallel,

  /// Kerterizler tutarsız: bulunan yerden bakınca nokta arkada kalıyor.
  behind,
}

/// Geriden kestirme sonucu.
class ResectionResult {
  const ResectionResult.failed(this.failure)
    : position = null,
      errorPolygon = const [],
      errorRadius = 0,
      bestAngle = 0;

  const ResectionResult({
    required LatLng this.position,
    required this.errorPolygon,
    required this.errorRadius,
    required this.bestAngle,
  }) : failure = null;

  final LatLng? position;
  final ResectionFailure? failure;

  /// Hata alanı (dışbükey çokgen): pusula hassasiyetinden gelen dörtgen ve
  /// üç nişanda "hata üçgeni" birlikte.
  final List<LatLng> errorPolygon;

  /// Konumdan hata alanının en uzak köşesine (m).
  final double errorRadius;

  /// En iyi kesişen iki çizgi arasındaki açı (0–90°). 30°'nin altı zayıf.
  final double bestAngle;

  bool get ok => position != null;

  /// Kesişme açısı zayıf (sonuç güvenilmez).
  bool get weak => ok && bestAngle < Resection.weakAngle;
}

/// Geriden kestirme (ATAK Resection, kılavuz s.50): 2–3 bilinen noktaya
/// alınan kerterizlerden konum.
///
/// Noktalar çevresinde yerel düz bir düzleme geçilir (birkaç on km'de el
/// pusulasının ±2°'sinden çok küçük hata), her noktadan kerteriz
/// doğrultusunda çizgi geçirilir, çizgilere dik uzaklıkların kareleri
/// toplamını en küçük yapan nokta bulunur.
class Resection {
  Resection._();

  /// El pusulası hassasiyeti varsayılanı (±°).
  static const defaultSigma = 2.0;

  /// Bu açının altındaki kesişme zayıf sayılır.
  static const weakAngle = 30.0;

  static const _r = 6371008.8;

  static ResectionResult solve(
    List<Sighting> sightings, {
    double sigma = defaultSigma,
  }) {
    if (sightings.length < 2) {
      return const ResectionResult.failed(ResectionFailure.tooFew);
    }
    final lat0 =
        sightings.map((s) => s.landmark.latitude).reduce((a, b) => a + b) /
        sightings.length;
    final lon0 =
        sightings.map((s) => s.landmark.longitude).reduce((a, b) => a + b) /
        sightings.length;
    final cos0 = math.cos(lat0 * math.pi / 180);
    _V toXY(LatLng p) => _V(
      _r * (p.longitude - lon0) * math.pi / 180 * cos0,
      _r * (p.latitude - lat0) * math.pi / 180,
    );
    LatLng toLatLng(_V v) => LatLng(
      lat0 + v.y / _r * 180 / math.pi,
      lon0 + v.x / (_r * cos0) * 180 / math.pi,
    );

    final lines = [
      for (final s in sightings) _Line(toXY(s.landmark), s.trueBearing),
    ];

    // En küçük kareler: Σ (n·P − n·L)² en küçük → A·P = b.
    var a11 = 0.0, a12 = 0.0, a22 = 0.0, b1 = 0.0, b2 = 0.0;
    for (final l in lines) {
      final n = l.normal;
      final c = n.dot(l.point);
      a11 += n.x * n.x;
      a12 += n.x * n.y;
      a22 += n.y * n.y;
      b1 += n.x * c;
      b2 += n.y * c;
    }
    final det = a11 * a22 - a12 * a12;
    // det = Σ sin²(çizgiler arası açı) (çiftler üzerinden): ~5°'nin altı paralel.
    if (det < math.pow(math.sin(5 * math.pi / 180), 2)) {
      return const ResectionResult.failed(ResectionFailure.parallel);
    }
    final p = _V((a22 * b1 - a12 * b2) / det, (a11 * b2 - a12 * b1) / det);

    // Her nokta bulunan yerden kerteriz yönünde (önde) olmalı.
    for (final l in lines) {
      if ((l.point - p).dot(l.dir) <= 0) {
        return const ResectionResult.failed(ResectionFailure.behind);
      }
    }

    // En iyi kesişen çift: açısı 90°'ye en yakın.
    var best = (0, 1);
    var bestAngle = -1.0;
    final corners = <_V>[];
    for (var i = 0; i < lines.length; i++) {
      for (var j = i + 1; j < lines.length; j++) {
        final ang = _angleBetween(lines[i].bearing, lines[j].bearing);
        if (ang > bestAngle) {
          bestAngle = ang;
          best = (i, j);
        }
        // Üç ve fazla nişanda çiftlerin kesişimleri: hata üçgeni.
        if (lines.length >= 3) {
          final x = _intersect(lines[i], lines[j]);
          if (x != null) corners.add(x);
        }
      }
    }
    // Pusula hassasiyeti: en iyi çiftin ±σ çizgilerinin kesişimleri.
    final (i, j) = best;
    for (final di in [-sigma, sigma]) {
      for (final dj in [-sigma, sigma]) {
        final x = _intersect(
          _Line(lines[i].point, lines[i].bearing + di),
          _Line(lines[j].point, lines[j].bearing + dj),
        );
        if (x != null) corners.add(x);
      }
    }
    final hull = _convexHull(corners);
    var radius = 0.0;
    for (final c in hull) {
      radius = math.max(radius, (c - p).length);
    }
    return ResectionResult(
      position: toLatLng(p),
      errorPolygon: [for (final c in hull) toLatLng(c)],
      errorRadius: radius,
      bestAngle: bestAngle,
    );
  }

  /// İki doğrultu arasındaki açı (0–90°).
  static double _angleBetween(double b1, double b2) {
    final d = ((b1 - b2) % 180 + 180) % 180;
    return d > 90 ? 180 - d : d;
  }

  static _V? _intersect(_Line l1, _Line l2) {
    // l1.point + t·d1 = l2.point + u·d2
    final d1 = l1.dir, d2 = l2.dir;
    final den = d1.x * d2.y - d1.y * d2.x;
    if (den.abs() < 1e-9) return null;
    final w = l2.point - l1.point;
    final t = (w.x * d2.y - w.y * d2.x) / den;
    return l1.point + d1 * t;
  }

  /// Andrew'un monoton zincir yöntemi.
  static List<_V> _convexHull(List<_V> pts) {
    if (pts.length < 3) return List.of(pts);
    final s = List.of(pts)
      ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    double cross(_V o, _V a, _V b) =>
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    final lower = <_V>[];
    for (final p in s) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <_V>[];
    for (final p in s.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }
}

/// Düzlemde vektör (x doğu, y kuzey; metre).
class _V {
  const _V(this.x, this.y);
  final double x, y;
  _V operator +(_V o) => _V(x + o.x, y + o.y);
  _V operator -(_V o) => _V(x - o.x, y - o.y);
  _V operator *(double k) => _V(x * k, y * k);
  double dot(_V o) => x * o.x + y * o.y;
  double get length => math.sqrt(x * x + y * y);
}

/// Noktadan geçen, kerteriz doğrultusundaki çizgi.
class _Line {
  _Line(this.point, this.bearing);

  final _V point;
  final double bearing;

  late final _V dir = _V(
    math.sin(bearing * math.pi / 180),
    math.cos(bearing * math.pi / 180),
  );

  /// Birim normal.
  late final _V normal = _V(dir.y, -dir.x);
}
