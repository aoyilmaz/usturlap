import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../usecases/lasso.dart';

import 'cot_type.dart';
import 'map_item.dart';

/// Kalıcı taktik grafik türü (ATAK Drawing Tools, kılavuz s.40–42).
/// line = açık çizgi (sınır / eksen / serbest çizim), area = kapalı poligon,
/// circle = merkez + kenar noktası, rectangle = 4 köşe (enlem/boylam eksenli).
enum GraphicType {
  line('Çizgi'),
  area('Alan'),
  circle('Daire'),
  rectangle('Dikdörtgen');

  const GraphicType(this.label);
  final String label;

  static GraphicType fromName(String? name) {
    for (final t in GraphicType.values) {
      if (t.name == name) return t;
    }
    return GraphicType.line;
  }
}

/// Geofence uyarısı (ATAK Geofencing, kılavuz s.43): kapalı şekle giriş /
/// çıkış.
enum GeofenceTrigger {
  entry('Girişte'),
  exit('Çıkışta'),
  both('Giriş ve çıkışta');

  const GeofenceTrigger(this.label);
  final String label;

  bool get onEntry => this != exit;
  bool get onExit => this != entry;

  static GeofenceTrigger? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// Haritaya kalıcı çizilen taktik grafik (çizgi/alan).
///
/// Saf Dart modeli — renk, presentation'a bağımlı kalmamak için ARGB `int`
/// olarak tutulur (data katmanı drift satırına çevirir).
class MapGraphic implements MapItem {
  final int? id;

  @override
  final String uid;

  final String name;
  final GraphicType type;
  final List<LatLng> points;

  /// ARGB renk değeri (ör. 0xFFE03131).
  final int colorValue;

  /// Çizgi / kenar kalınlığı (mantıksal piksel).
  final double strokeWidth;

  /// Kesikli çizgi / kenar.
  final bool dashed;

  /// 3B yükseklik (m, yerden; ATAK 3D Shapes). Yalnız kapalı şekillerde;
  /// null = düz alan.
  final double? height;

  /// Geofence uyarısı (yalnız kapalı şekillerde); null = yok.
  final GeofenceTrigger? geofence;

  @override
  final DateTime createdAt;

  const MapGraphic({
    required this.uid,
    required this.name,
    required this.type,
    required this.points,
    required this.colorValue,
    required this.createdAt,
    this.id,
    this.strokeWidth = defaultStrokeWidth,
    this.dashed = false,
    this.height,
    this.geofence,
  });

  static const defaultStrokeWidth = 3.0;

  /// Kapalı şekil mi (alan, daire, dikdörtgen).
  bool get closed => type != GraphicType.line;

  /// Konum şeklin içinde mi (dairede yarıçap, diğerlerinde çokgen).
  bool contains(LatLng p) {
    if (!closed) return false;
    if (type == GraphicType.circle) {
      return points.length >= 2 &&
          GeoMath.distance(points[0], p) <= radiusMeters;
    }
    return pointInPolygon(p, points);
  }

  /// Noktanın şeklin kenarına uzaklığı (m; içeride de dışarıda da pozitif).
  /// Geofence'in sınırda GPS titremesiyle gidip gelmemesi için.
  double distanceToEdge(LatLng p) {
    if (type == GraphicType.circle) {
      return (GeoMath.distance(points[0], p) - radiusMeters).abs();
    }
    final pts = points;
    if (pts.length < 2) return double.infinity;
    // Kısa mesafelerde yeterli: noktanın çevresinde düzlem yaklaşımı (m).
    const mPerDeg = 111320.0;
    final kx = mPerDeg * math.cos(p.latitude * math.pi / 180);
    (double, double) xy(LatLng q) =>
        ((q.longitude - p.longitude) * kx, (q.latitude - p.latitude) * mPerDeg);
    var best = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final (ax, ay) = xy(pts[i]);
      final (bx, by) = xy(pts[(i + 1) % pts.length]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
    }
    return best;
  }

  /// Şeklin kabaca en küçük boyutu (m): sınır tamponu küçük şekillerde
  /// şeklin kendisini yutmasın.
  double get minSpanMeters {
    if (type == GraphicType.circle) return 2 * radiusMeters;
    if (points.isEmpty) return 0;
    var minLat = points.first.latitude, maxLat = minLat;
    var minLon = points.first.longitude, maxLon = minLon;
    for (final q in points) {
      minLat = math.min(minLat, q.latitude);
      maxLat = math.max(maxLat, q.latitude);
      minLon = math.min(minLon, q.longitude);
      maxLon = math.max(maxLon, q.longitude);
    }
    final midLat = (minLat + maxLat) / 2;
    final h = (maxLat - minLat) * 111320.0;
    final w = (maxLon - minLon) * 111320.0 * math.cos(midLat * math.pi / 180);
    return math.min(h, w);
  }

  /// Daire yarıçapı (m); daire değilse 0.
  double get radiusMeters => type == GraphicType.circle && points.length >= 2
      ? GeoMath.distance(points[0], points[1])
      : 0;

  /// Çizilecek / dışa aktarılacak noktalar: dairede çevre noktaları,
  /// diğerlerinde [points].
  List<LatLng> get outline => type == GraphicType.circle && points.length >= 2
      ? GeoMath.circlePoints(points[0], radiusMeters)
      : points;

  /// ATAK serbest çizim; alanlar ilk = son noktayla kapanır. Daire ve
  /// dikdörtgen de (çokgen olarak) bu tiple paylaşılır.
  @override
  String get cotType => CotType.freeform;

  @override
  String get title => name;
}
