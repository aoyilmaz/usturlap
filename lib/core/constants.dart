import 'package:latlong2/latlong.dart';

/// Uygulama genelindeki sabitler.
class AppConstants {
  AppConstants._();

  /// Uygulama adı (HUD/başlıkta kullanılabilir).
  static const String appName = 'Pusula';

  /// Kendi işaretçimizin varsayılan callsign'ı.
  /// (İleride ayarlardan düzenlenebilir hale gelecek.)
  static const String defaultCallsign = 'PUSULA-1';

  /// OSM kutucuk sunucusu istekleri için User-Agent paketi adı.
  /// OSM kullanım politikası gereği gerçek bir tanımlayıcı gönderilmeli.
  static const String osmUserAgent = 'com.pusula.app';

  /// Çevrimiçi OSM raster karo şablonu (Adım 1).
  /// Adım 2'de bunun yanına gömülü MBTiles katmanı eklenecek.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Harita ilk açıldığında merkezlenecek konum (Ankara civarı — geçici).
  static const LatLng initialCenter = LatLng(39.925, 32.866);

  /// Harita başlangıç yakınlaştırma seviyesi.
  static const double initialZoom = 13.0;

  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;
}
