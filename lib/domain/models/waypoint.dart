import 'package:latlong2/latlong.dart';

/// Kullanıcının haritada işaretlediği kalıcı bir nokta.
///
/// Saf Dart modeli (drift'e bağımlı değil); data katmanı drift satırlarını
/// bu modele çevirir (§4.3 katmanlama).
class Waypoint {
  /// Veritabanı kimliği. Henüz kaydedilmemişse null.
  final int? id;
  final String name;
  final LatLng position;
  final DateTime createdAt;
  final String? note;

  const Waypoint({
    required this.name,
    required this.position,
    required this.createdAt,
    this.id,
    this.note,
  });
}
