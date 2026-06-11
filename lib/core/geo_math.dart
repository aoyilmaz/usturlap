import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Mesafe/alan/sektör hesaplama ve biçimlendirme yardımcıları (saf Dart).
class GeoMath {
  GeoMath._();

  static const Distance _d = Distance();
  static const double _earthRadius = 6371009.0; // ortalama yarıçap (m)

  /// Ardışık noktalar arası toplam yol uzunluğu (metre).
  static double pathLength(List<LatLng> pts) {
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += _d(pts[i], pts[i + 1]);
    }
    return total;
  }

  /// Poligon çevresi (kapanış kenarı dahil), metre.
  static double polygonPerimeter(List<LatLng> pts) {
    if (pts.length < 3) return pathLength(pts);
    return pathLength(pts) + _d(pts.last, pts.first);
  }

  /// Küresel poligon alanı (m²). Google SphericalUtil algoritması.
  static double polygonArea(List<LatLng> pts) {
    if (pts.length < 3) return 0;
    var total = 0.0;
    var prev = pts.last;
    var prevTan = math.tan((math.pi / 2 - _rad(prev.latitude)) / 2);
    var prevLng = _rad(prev.longitude);
    for (final p in pts) {
      final tan = math.tan((math.pi / 2 - _rad(p.latitude)) / 2);
      final lng = _rad(p.longitude);
      total += _polarTriangleArea(tan, lng, prevTan, prevLng);
      prevTan = tan;
      prevLng = lng;
    }
    return (total * _earthRadius * _earthRadius).abs();
  }

  static double _polarTriangleArea(
      double tan1, double lng1, double tan2, double lng2) {
    final deltaLng = lng1 - lng2;
    final t = tan1 * tan2;
    return 2 *
        math.atan2(t * math.sin(deltaLng), 1 + t * math.cos(deltaLng));
  }

  /// Merkez + yarıçap + iki kerteriz arası dolu sektör poligonu için noktalar.
  /// Sonuç [merkez, yay noktaları...]; poligon son nokta→merkez ile kapanır.
  static List<LatLng> sectorPolygon(
    LatLng center,
    double radiusMeters,
    double startBearing,
    double endBearing, {
    double stepDeg = 3.0,
  }) {
    var sweep = (endBearing - startBearing) % 360;
    if (sweep <= 0) sweep += 360;
    final steps = math.max(1, (sweep / stepDeg).ceil());
    final pts = <LatLng>[center];
    for (var i = 0; i <= steps; i++) {
      final b = startBearing + sweep * (i / steps);
      pts.add(_d.offset(center, radiusMeters, b));
    }
    return pts;
  }

  static double bearing(LatLng from, LatLng to) => _d.bearing(from, to);
  static double distance(LatLng a, LatLng b) => _d(a, b);

  static double _rad(double deg) => deg * math.pi / 180.0;

  // --- biçimlendirme ---

  static String fmtDistance(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(2)} km';

  static String fmtArea(double m2) {
    if (m2 < 10000) return '${m2.round()} m²';
    if (m2 < 1000000) return '${(m2 / 10000).toStringAsFixed(2)} ha';
    return '${(m2 / 1000000).toStringAsFixed(2)} km²';
  }

  static String fmtBearing(double deg) =>
      '${((deg % 360) + 360) % 360 ~/ 1}°';
}
