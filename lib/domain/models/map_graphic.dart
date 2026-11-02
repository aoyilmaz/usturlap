import 'package:latlong2/latlong.dart';

/// Kalıcı taktik grafik türü.
/// line = açık çizgi (sınır/eksen), area = kapalı poligon (bölge).
enum GraphicType {
  line('Çizgi'),
  area('Alan');

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
class MapGraphic {
  final int? id;
  final String name;
  final GraphicType type;
  final List<LatLng> points;

  /// ARGB renk değeri (ör. 0xFFE03131).
  final int colorValue;
  final DateTime createdAt;

  const MapGraphic({
    required this.name,
    required this.type,
    required this.points,
    required this.colorValue,
    required this.createdAt,
    this.id,
  });
}
