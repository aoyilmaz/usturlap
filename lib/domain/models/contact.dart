import 'package:latlong2/latlong.dart';

/// Haritada gösterilen tek bir konum işaretçisi.
///
/// v1'de tek bir `Contact` olur: kendi cihazımız (`isSelf == true`).
/// Faz 2'de mesh düğümlerinden gelen her callsign ayrı bir `Contact` olarak
/// gelir. Harita/HUD katmanı bu modeli üretenin kim olduğunu (GPS mi, mesh mi)
/// bilmez — sadece `PositionSource` üzerinden `Contact` listesi dinler.
///
/// Not: `latlong2` saf Dart'tır (Flutter'a bağımlı değil), bu yüzden domain
/// katmanında kullanmak §4.3'teki "domain Flutter'dan bağımsız olmalı"
/// ilkesini bozmaz.
class Contact {
  /// İşaretçinin etiketi (ör. "ALFA-1"). v1'de kendi callsign'ımız.
  final String callsign;

  /// Enlem/boylam (WGS84).
  final LatLng position;

  /// Yatay hız (m/s). Bilinmiyorsa null.
  final double? speedMps;

  /// Deniz seviyesine göre yükseklik (metre, MSL). Bilinmiyorsa null.
  final double? altitudeMsl;

  /// Hareket yönü / kerteriz (derece, 0 = kuzey). Bilinmiyorsa null.
  final double? headingDeg;

  /// Yatay konum doğruluğu (± metre). Küçük = daha iyi. Bilinmiyorsa null.
  final double? accuracyMeters;

  /// Bu konum bilgisinin ölçüldüğü an.
  final DateTime timestamp;

  /// true ise bu işaretçi bizim cihazımızdır (kendi konumumuz).
  final bool isSelf;

  const Contact({
    required this.callsign,
    required this.position,
    required this.timestamp,
    this.speedMps,
    this.altitudeMsl,
    this.headingDeg,
    this.accuracyMeters,
    this.isSelf = false,
  });

  Contact copyWith({
    String? callsign,
    LatLng? position,
    double? speedMps,
    double? altitudeMsl,
    double? headingDeg,
    double? accuracyMeters,
    DateTime? timestamp,
    bool? isSelf,
  }) {
    return Contact(
      callsign: callsign ?? this.callsign,
      position: position ?? this.position,
      speedMps: speedMps ?? this.speedMps,
      altitudeMsl: altitudeMsl ?? this.altitudeMsl,
      headingDeg: headingDeg ?? this.headingDeg,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      timestamp: timestamp ?? this.timestamp,
      isSelf: isSelf ?? this.isSelf,
    );
  }

  @override
  String toString() =>
      'Contact($callsign, $position, self=$isSelf, t=$timestamp)';
}
