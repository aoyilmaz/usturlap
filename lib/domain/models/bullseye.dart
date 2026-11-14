import 'package:latlong2/latlong.dart';

import '../../core/bearing_format.dart';
import '../../core/geo_math.dart';
import 'range_line.dart';

/// Bullseye (ATAK, kılavuz s.14): yerleri tek bir referans noktasına göre
/// "kerteriz / mesafe" olarak bildirmek için ortak nokta. Haritada eş
/// merkezli halkalar ve 30°'de bir kerteriz ışınları.
///
/// Usturlap'ta tek bullseye var (görev başına bir referans); ayarlarda JSON.
/// Merkez R&B ucu gibi sabit ya da bir noktaya / kendi konumuma bağlı.
/// ATAK'ta CoT tipi `u-r-b-bullseye`; paylaşımı sonraki aşamada.
class Bullseye {
  const Bullseye({
    required this.center,
    this.name = 'BULLSEYE',
    this.ringSpacing = 1000,
    this.ringCount = 5,
  });

  static const cotType = 'u-r-b-bullseye';

  /// Seçilebilecek halka aralıkları (m).
  static const spacingChoices = <double>[
    100,
    250,
    500,
    1000,
    2000,
    5000,
    10000,
  ];
  static const maxRings = 10;

  /// Işın aralığı (derece, seçili kuzeye göre).
  static const radialStep = 30;

  final RbEnd center;
  final String name;
  final double ringSpacing;
  final int ringCount;

  List<double> get radii => [
    for (var k = 1; k <= ringCount; k++) ringSpacing * k,
  ];

  double get outerRadius => ringSpacing * ringCount;

  Bullseye copyWith({
    RbEnd? center,
    String? name,
    double? ringSpacing,
    int? ringCount,
  }) => Bullseye(
    center: center ?? this.center,
    name: name ?? this.name,
    ringSpacing: ringSpacing ?? this.ringSpacing,
    ringCount: ringCount ?? this.ringCount,
  );

  /// [p]'nin bullseye'a göre çağrısı: merkezden [p]'ye kerteriz (seçili
  /// kuzey ve birimle) ve mesafe, ör. "045° / 2.30 km".
  static String call(LatLng centerAt, LatLng p, BearingFormatter fmt) {
    final b = (GeoMath.bearing(centerAt, p) % 360 + 360) % 360;
    final d = GeoMath.distance(centerAt, p);
    return '${fmt.format(b, centerAt)} / ${GeoMath.fmtDistance(d)}';
  }

  /// Işınların coğrafi kerterizleri: seçili kuzeye göre 0, 30, 60… olsun
  /// diye çevrilir (manyetik seçiliyse ışınlar manyetik kuzeye hizalı).
  static List<double> radialBearings(LatLng centerAt, NorthRef ref) => [
    for (var a = 0; a < 360; a += radialStep)
      NorthMath.toTrue(a.toDouble(), centerAt, ref),
  ];

  Map<String, Object?> toJson() => {
    'name': name,
    'lat': center.point.latitude,
    'lon': center.point.longitude,
    'ref': center.ref,
    'spacing': ringSpacing,
    'rings': ringCount,
  };

  /// Bozuk ya da eksik kayıtta null.
  static Bullseye? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'], lon = json['lon'];
    final spacing = json['spacing'], rings = json['rings'];
    if (lat is! num || lon is! num || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    if (spacing is! num || spacing <= 0 || rings is! int) return null;
    final ref = json['ref'];
    final name = json['name'];
    return Bullseye(
      center: RbEnd(
        LatLng(lat.toDouble(), lon.toDouble()),
        ref is String ? ref : null,
      ),
      name: name is String && name.trim().isNotEmpty ? name : 'BULLSEYE',
      ringSpacing: spacing.toDouble(),
      ringCount: rings.clamp(1, maxRings),
    );
  }
}
