import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';

/// Görüş konisi (ATAK Sensor FOV, kılavuz s.9): bir noktadan [azimuth]
/// yönünde, [width] açıklığında, [range] menzilinde bakış alanı (sensör,
/// gözetleme noktası, kamera).
class SensorFov {
  const SensorFov({
    required this.azimuth,
    required this.width,
    required this.range,
  });

  /// Bakış yönü (coğrafi, 0–360°).
  final double azimuth;

  /// Açıklık (derece, 1–360; 360 = her yön).
  final double width;

  /// Menzil (m).
  final double range;

  static const minRange = 1.0;
  static const maxRange = 100000.0;

  /// Hızlı seçim açıklıkları (°).
  static const widthChoices = <double>[30, 60, 90, 120, 180];

  /// Geçerli değerlerle mi (bozuk kayıt / giriş elenir).
  static bool isValid(double? azimuth, double? width, double? range) =>
      azimuth != null &&
      width != null &&
      range != null &&
      azimuth.isFinite &&
      width > 0 &&
      width <= 360 &&
      range >= minRange &&
      range <= maxRange;

  /// Haritada çizilecek çokgen: merkez + yay (360°'de tam daire).
  List<LatLng> polygon(LatLng center) {
    final half = width / 2;
    return GeoMath.sectorPolygon(center, range, azimuth - half, azimuth + half);
  }

  @override
  bool operator ==(Object other) =>
      other is SensorFov &&
      other.azimuth == azimuth &&
      other.width == width &&
      other.range == range;

  @override
  int get hashCode => Object.hash(azimuth, width, range);
}
