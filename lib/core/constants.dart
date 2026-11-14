import 'package:latlong2/latlong.dart';

/// Uygulama genelindeki sabitler.
class AppConstants {
  AppConstants._();

  /// Uygulama adı (HUD/başlıkta kullanılabilir).
  static const String appName = 'Usturlap';

  /// Kendi işaretçimizin varsayılan callsign'ı.
  /// (İleride ayarlardan düzenlenebilir hale gelecek.)
  static const String defaultCallsign = 'USTURLAP-1';

  /// OSM kutucuk sunucusu istekleri için User-Agent paketi adı.
  /// OSM kullanım politikası gereği gerçek bir tanımlayıcı gönderilmeli.
  static const String osmUserAgent = 'com.usturlap.app';

  /// Çevrimiçi OSM raster karo şablonu (Adım 1).
  /// Adım 2'de bunun yanına gömülü MBTiles katmanı eklenecek.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Harita ilk açıldığında merkezlenecek konum (Ankara civarı — geçici).
  static const LatLng initialCenter = LatLng(39.925, 32.866);

  /// Harita başlangıç yakınlaştırma seviyesi.
  static const double initialZoom = 13.0;

  static const double minZoom = 3.0;

  /// Harita en fazla bu zoom'a yaklaşır. Karo kaynağının kendi sınırının
  /// (maxNativeZoom) ötesinde son karo büyütülür → boş/gri karo yerine
  /// görüntü yumuşakça büyür.
  static const double maxZoom = 22.0;

  /// Mapbox erişim anahtarı (public `pk.` token). Koda gömülmez; derlemede
  /// verilir: `flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx`.
  /// Boşsa çevrimiçi uydu katmanı devre dışı görünür.
  static const String mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  /// Mapbox uydu + yol/yer adı (raster, 512px @2x — retina ekranda keskin).
  static const String mapboxSatelliteStreetsUrl =
      'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/512/{z}/{x}/{y}@2x?access_token={accessToken}';

  /// OpenTopoMap en fazla z17 karo sunar.
  static const String openTopoMapUrl =
      'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
}
