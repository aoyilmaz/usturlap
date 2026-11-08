import 'package:latlong2/latlong.dart';

/// Kayıtlı harita görünümü (ATAK Favorites, kılavuz s.22): merkez,
/// yakınlık, dönüş ve harita kaynağı. Saf Dart; ayarlarda JSON listesi.
class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.center,
    required this.zoom,
    required this.createdAt,
    this.bearing = 0,
    this.layerId,
  });

  final String id;
  final String name;
  final LatLng center;
  final double zoom;
  final double bearing;

  /// Seçili harita kaynağı (gömülü ya da içe aktarılmış katman kimliği).
  final String? layerId;
  final DateTime createdAt;

  SavedView renamed(String newName) => SavedView(
    id: id,
    name: newName,
    center: center,
    zoom: zoom,
    bearing: bearing,
    layerId: layerId,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'lat': center.latitude,
    'lon': center.longitude,
    'zoom': zoom,
    'bearing': bearing,
    'layer': ?layerId,
    'created': createdAt.millisecondsSinceEpoch,
  };

  /// Eksik/bozuk kayıt null (liste okunurken atlanır).
  static SavedView? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    final lat = j['lat'], lon = j['lon'], zoom = j['zoom'];
    if (id is! String || name is! String) return null;
    if (lat is! num || lon is! num || zoom is! num) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    final bearing = j['bearing'], layer = j['layer'], created = j['created'];
    return SavedView(
      id: id,
      name: name,
      center: LatLng(lat.toDouble(), lon.toDouble()),
      zoom: zoom.toDouble(),
      bearing: bearing is num ? bearing.toDouble() : 0,
      layerId: layer is String ? layer : null,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
