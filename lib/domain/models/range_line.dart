import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';

/// R&B (mesafe-kerteriz) çizgisinin bir ucu: konum + isteğe bağlı bağ.
///
/// Bağlı uç ([ref] dolu) bağlandığı nesneyi izler: kendi konumum hareket
/// edince ya da nokta taşınınca çizgi kendiliğinden güncellenir (ATAK
/// "dynamic R&B", kılavuz s.12). [point] bağsız uçta sabit konum, bağlı uçta
/// çizginin kurulduğu andaki konumdur: nesne silinirse ya da konum yoksa
/// (GPS kapalı) uç orada kalır.
class RbEnd {
  const RbEnd(this.point, [this.ref]);

  /// Kendi konumuma bağlı uç.
  static const selfRef = 'self';

  /// Bir noktaya (waypoint uid'i) bağlı uç.
  static String waypointRef(String uid) => 'wp:$uid';

  final LatLng point;
  final String? ref;

  bool get isSelf => ref == selfRef;

  String? get waypointUid =>
      ref != null && ref!.startsWith('wp:') ? ref!.substring(3) : null;

  /// Bağlandığı nesnenin şimdiki konumu; yoksa [point].
  LatLng resolve({LatLng? self, Map<String, LatLng> waypoints = const {}}) {
    if (isSelf) return self ?? point;
    final uid = waypointUid;
    if (uid != null) return waypoints[uid] ?? point;
    return point;
  }

  @override
  bool operator ==(Object other) =>
      other is RbEnd && other.point == point && other.ref == ref;

  @override
  int get hashCode => Object.hash(point, ref);
}

/// Kalıcı R&B çizgisi (ATAK R&B Line, kılavuz s.12). Haritada iki uç
/// arasında çizgi ve ortasında "kerteriz · mesafe" etiketi.
///
/// ATAK'ta CoT tipi `u-rb-a` (TAK CoT kataloğu "Azimuth line"); paylaşımı
/// sonraki aşamada.
class RangeLine {
  const RangeLine({
    required this.uid,
    required this.name,
    required this.start,
    required this.end,
    required this.colorValue,
    required this.createdAt,
    this.id,
  });

  static const cotType = 'u-rb-a';

  /// Varsayılan renk: pembe. Ölçüm aracının sarısından, canlı izin
  /// turuncusundan ve kayıtlı izin camgöbeğinden ayrılsın.
  static const defaultColor = 0xFFFF4FA3;

  final int? id;
  final String uid;
  final String name;
  final RbEnd start;
  final RbEnd end;
  final int colorValue;
  final DateTime createdAt;
}

/// İki uç arasındaki ölçüm: mesafe, ileri / ters kerteriz (coğrafi) ve iki
/// ucun yüksekliği biliniyorsa eğim açısı.
class RbMeasure {
  const RbMeasure({
    required this.meters,
    required this.bearing,
    this.elevationFrom,
    this.elevationTo,
  });

  factory RbMeasure.between(
    LatLng from,
    LatLng to, {
    double? elevationFrom,
    double? elevationTo,
  }) {
    final b = GeoMath.bearing(from, to);
    return RbMeasure(
      meters: GeoMath.distance(from, to),
      bearing: (b % 360 + 360) % 360,
      elevationFrom: elevationFrom,
      elevationTo: elevationTo,
    );
  }

  final double meters;

  /// Coğrafi kuzeye göre 0–360°.
  final double bearing;

  /// Uçların deniz seviyesinden yüksekliği (m); bilinmiyorsa null.
  final double? elevationFrom;
  final double? elevationTo;

  double get backBearing => (bearing + 180) % 360;

  /// Yükseklik farkı (m, + = karşı uç daha yüksek).
  double? get rise => elevationFrom == null || elevationTo == null
      ? null
      : elevationTo! - elevationFrom!;

  /// Eğim (yükselme +, depresyon −) açısı, derece. Uçlar 1 m'den yakınsa
  /// anlamsız → null. Dünya eğriliği yok sayılır (birkaç km'de < 0,1°).
  double? get slopeDeg {
    final r = rise;
    if (r == null || meters < 1) return null;
    return math.atan2(r, meters) * 180 / math.pi;
  }
}
