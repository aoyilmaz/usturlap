import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../models/map_graphic.dart';

/// Haritada dokunulan çizimi bulur (ATAK: şekle dokun → radyal menü).
///
/// Önce kenarı / çizgisi [toleranceMeters] içinde olanlar (en yakını);
/// yoksa içine dokunulan kapalı şekiller (en küçüğü: iç içe şekillerde
/// küçük olan seçilebilsin).
MapGraphic? hitGraphic(
  LatLng p,
  Iterable<MapGraphic> graphics,
  double toleranceMeters,
) {
  MapGraphic? edge;
  var edgeDist = double.infinity;
  MapGraphic? inside;
  var insideArea = double.infinity;
  for (final g in graphics) {
    final d = distanceToOutline(p, g);
    if (d <= toleranceMeters && d < edgeDist) {
      edge = g;
      edgeDist = d;
    }
    if (g.closed && g.contains(p)) {
      final a = g.type == GraphicType.circle
          ? math.pi * g.radiusMeters * g.radiusMeters
          : GeoMath.polygonArea(g.points);
      if (a < insideArea) {
        inside = g;
        insideArea = a;
      }
    }
  }
  return edge ?? inside;
}

/// [p]'nin çizimin çizgisine / kenarına uzaklığı (m).
double distanceToOutline(LatLng p, MapGraphic g) {
  if (g.type == GraphicType.circle) {
    if (g.points.length < 2) return double.infinity;
    return (GeoMath.distance(g.points[0], p) - g.radiusMeters).abs();
  }
  final pts = g.points;
  if (pts.isEmpty) return double.infinity;
  if (pts.length == 1) return GeoMath.distance(pts.first, p);
  var best = double.infinity;
  final n = g.closed ? pts.length : pts.length - 1;
  for (var i = 0; i < n; i++) {
    final d = distanceToSegment(p, pts[i], pts[(i + 1) % pts.length]);
    if (d < best) best = d;
  }
  return best;
}

/// [p]'nin [a]–[b] doğru parçasına uzaklığı (m). Kısa mesafeler için
/// [p] çevresinde düzlem yaklaşımı (dokunma toleransı ölçeğinde yeterli).
double distanceToSegment(LatLng p, LatLng a, LatLng b) {
  const r = 6371008.8;
  final k = math.cos(p.latitude * math.pi / 180);
  math.Point<double> xy(LatLng q) => math.Point(
    (q.longitude - p.longitude) * math.pi / 180 * r * k,
    (q.latitude - p.latitude) * math.pi / 180 * r,
  );
  final pa = xy(a), pb = xy(b);
  final dx = pb.x - pa.x, dy = pb.y - pa.y;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : -(pa.x * dx + pa.y * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = pa.x + t * dx, cy = pa.y + t * dy;
  return math.sqrt(cx * cx + cy * cy);
}

/// Mapbox'ta bir mantıksal pikselin yerdeki karşılığı (m): 512 px karo.
double metersPerPixel(double zoom, double latitude) =>
    40075016.686 *
    math.cos(latitude * math.pi / 180) /
    (512 * math.pow(2, zoom));
