import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';

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
  });

  static const defaultStrokeWidth = 3.0;

  /// Kapalı şekil mi (alan, daire, dikdörtgen).
  bool get closed => type != GraphicType.line;

  /// Daire yarıçapı (m); daire değilse 0.
  double get radiusMeters =>
      type == GraphicType.circle && points.length >= 2
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
