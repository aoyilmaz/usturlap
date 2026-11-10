import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// Harita motorundan bağımsız tipler.
///
/// Harita ekranı (map_screen) yalnızca bu tiplerle konuşur; hangi motorun
/// çizdiğini bilmez. Bkz. docs/harita-motoru-gecis-plani.md.

/// Kameranın anlık durumu.
@immutable
class MapCameraState {
  const MapCameraState({
    required this.center,
    required this.zoom,
    this.bearing = 0,
  });

  final LatLng center;
  final double zoom;

  /// Ekranın üstünün baktığı yön, kuzeyden saat yönünde derece
  /// (0 = kuzey-yukarı). Mapbox'taki `bearing` ile aynı anlam.
  final double bearing;
}

/// Basit coğrafi dikdörtgen (güney-batı / kuzey-doğu).
@immutable
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Noktaları kapsayan en küçük dikdörtgen. [points] boş olamaz.
  factory GeoBounds.fromPoints(Iterable<LatLng> points) {
    final it = points.iterator;
    if (!it.moveNext()) {
      throw ArgumentError.value(points, 'points', 'boş olamaz');
    }
    var s = it.current.latitude, n = s;
    var w = it.current.longitude, e = w;
    while (it.moveNext()) {
      final p = it.current;
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    return GeoBounds(south: s, west: w, north: n, east: e);
  }

  final double south, west, north, east;

  LatLng get southWest => LatLng(south, west);
  LatLng get northEast => LatLng(north, east);

  bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() => 'GeoBounds($south,$west → $north,$east)';
}

// --------------------------------------------------------------------------
// Harita üstü çizimler (overlay). Liste sırası = çizim sırası (alttan üste).
// --------------------------------------------------------------------------

sealed class MapOverlay {
  const MapOverlay();
}

/// Çizgi (iz, ölçüm, navigasyon çizgisi).
class MapLine extends MapOverlay {
  const MapLine({
    required this.points,
    required this.color,
    this.width = 3,
    this.dashed = false,
  });

  final List<LatLng> points;
  final Color color;
  final double width;

  /// Kesikli çizgi.
  final bool dashed;
}

/// Coğrafi sınırlara gerilmiş resim (ör. görüş alanı, eğim haritası):
/// ön-çarpılmış RGBA pikseller, satırlar kuzeyden güneye. Bütün çizimlerin
/// altında, taban haritanın üstünde çizilir.
class MapImage extends MapOverlay {
  MapImage({
    required this.id,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.width,
    required this.height,
    required this.pixels,
    this.opacity = 1,
  }) : assert(pixels.length == 4 * width * height);

  /// Kaynak kimliği (aynı id = aynı katman; pikseller değişince güncellenir).
  final String id;
  final double north;
  final double south;
  final double east;
  final double west;
  final int width;
  final int height;
  final Uint8List pixels;
  final double opacity;
}

/// Kapalı alan (poligon, sektör).
class MapArea extends MapOverlay {
  const MapArea({
    required this.points,
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 3,
    this.dashed = false,
    this.height,
  });

  final List<LatLng> points;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  /// Kesikli kenar.
  final bool dashed;

  /// 3B yükseklik (m): harita eğikken kutu olarak yükselir; null = düz.
  final double? height;
}

/// Metre cinsinden yarıçaplı daire (ör. röle kapsama alanı).
class MapCircle extends MapOverlay {
  const MapCircle({
    required this.center,
    required this.radiusMeters,
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 1.5,
  });

  final LatLng center;
  final double radiusMeters;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
}

/// Haritaya sabitlenmiş işaretçi (waypoint, NATO sembolü, kendi konum oku).
///
/// [child] yalnızca GÖRÜNÜMDÜR (dokunma/döndürme içermez): Mapbox motoru onu
/// bir kez resme çevirip native sembol olarak çizer. Dokunma [onTap], yön
/// [rotationDeg] ile verilir ki her motor kendi yoluyla uygulasın.
class MapMarker extends MapOverlay {
  const MapMarker({
    required this.id,
    required this.point,
    required this.child,
    String? imageKey,
    this.width = 32,
    this.height = 32,
    this.rotationDeg,
    this.onTap,
  }) : imageKey = imageKey ?? id;

  /// Bu işaretçinin benzersiz kimliği (dokunma eşlemesi için).
  final String id;

  /// Görünümün önbellek anahtarı: aynı görünen işaretçiler (ör. tüm röleler)
  /// aynı anahtarı paylaşır → tek kez resme çevrilir.
  ///
  /// [volatilePrefix] ile başlayan anahtar "değişken"dir (ör. içinde ölçüm
  /// yazan etiket): hiçbir işaretçi kullanmayınca motor resmi atar.
  final String imageKey;

  static const volatilePrefix = 'v:';

  static bool isVolatileKey(String key) => key.startsWith(volatilePrefix);

  final LatLng point;
  final Widget child;
  final double width;
  final double height;

  /// Harita kuzeyine göre saat yönünde döndürme (ör. kerteriz oku). null → yok.
  final double? rotationDeg;

  final VoidCallback? onTap;
}

// --------------------------------------------------------------------------
// Taban katman — dosyası bulunmuş / adresi belli, çizilmeye hazır hali.
// (Katman tanımı: base_layer.dart; çözümleme: base_layer_resolver.dart)
// --------------------------------------------------------------------------

sealed class ResolvedBaseLayer {
  const ResolvedBaseLayer({required this.id, this.attribution});

  /// Katman kimliği (BaseLayerDef.id).
  final String id;

  /// Haritada gösterilecek kaynak atfı (lisans gereği).
  final String? attribution;
}

/// Henüz hazır olmayan / boş taban katman.
class NoBaseLayer extends ResolvedBaseLayer {
  const NoBaseLayer() : super(id: '');
}

/// İnternetten {z}/{x}/{y} adresiyle gelen raster karolar.
class RasterUrlBaseLayer extends ResolvedBaseLayer {
  const RasterUrlBaseLayer({
    required super.id,
    required this.urlTemplate,
    required this.maxNativeZoom,
    this.tileDimension = 256,
    this.zoomOffset = 0,
    this.additionalOptions = const {},
    super.attribution,
  });

  final String urlTemplate;

  /// Kaynağın sunduğu en yüksek zoom; üstünde son karo büyütülür.
  final int maxNativeZoom;
  final int tileDimension;
  final double zoomOffset;

  /// urlTemplate içindeki ek {yer tutucular} (ör. accessToken).
  final Map<String, String> additionalOptions;
}

/// Cihazdaki .mbtiles dosyası (raster).
class MbtilesBaseLayer extends ResolvedBaseLayer {
  const MbtilesBaseLayer({
    required super.id,
    required this.path,
    required this.maxNativeZoom,
    super.attribution,
  });

  final String path;
  final int maxNativeZoom;
}

/// Cihazdaki .pmtiles dosyası (vektör) + MapLibre stil JSON asset'i.
class PmtilesBaseLayer extends ResolvedBaseLayer {
  const PmtilesBaseLayer({
    required super.id,
    required this.path,
    required this.stylePath,
    super.attribution,
  });

  final String path;
  final String stylePath;
}
