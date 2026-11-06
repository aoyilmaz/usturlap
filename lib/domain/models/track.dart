import 'package:latlong2/latlong.dart';

/// Kaydedilmiş bir rota izinin tek noktası.
class TrackPoint {
  final LatLng position;
  final DateTime timestamp;
  final double? altitude; // metre
  final double? speedMps;

  const TrackPoint({
    required this.position,
    required this.timestamp,
    this.altitude,
    this.speedMps,
  });
}

/// Bir rota izi (başlat/durdur arası kaydedilen nokta dizisi).
class Track {
  final int? id;

  /// Kalıcı, cihazlar arası kimlik (UUID v4) — veri paketinde izi tanımak için.
  final String uid;

  final String name;
  final DateTime startedAt;
  final DateTime? endedAt; // null ise hâlâ kaydediliyor
  final int pointCount;

  const Track({
    required this.uid,
    required this.name,
    required this.startedAt,
    this.id,
    this.endedAt,
    this.pointCount = 0,
  });

  bool get isRecording => endedAt == null;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
}
