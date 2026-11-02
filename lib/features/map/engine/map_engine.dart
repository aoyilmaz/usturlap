import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'flutter_map_engine.dart';
import 'map_types.dart';

export 'map_types.dart';

/// Haritayı programdan yönetme (kamera) sözleşmesi.
abstract class MapEngineController {
  /// Harita çizildi ve kamera komutlarına hazır mı.
  bool get isReady;

  /// Anlık kamera. Harita hazır değilse başlangıç kamerasını döndürür.
  MapCameraState get camera;

  /// Kamerayı [center]'a taşır; [zoom] verilmezse mevcut zoom korunur.
  void moveTo(LatLng center, {double? zoom});

  /// Haritayı döndürür: ekranın üstü [bearingDeg] yönüne bakar (0 = kuzey).
  void rotateTo(double bearingDeg);

  /// [bounds] ekrana sığacak şekilde kamerayı ayarlar.
  void fitBounds(GeoBounds bounds, {EdgeInsets padding = const EdgeInsets.all(40)});

  /// [layerId] taban katmanı için açılmış kaynakları (dosya bağlantısı,
  /// önbellek) serbest bırakır — ör. içe aktarılmış katman silinince.
  void releaseBaseLayer(String layerId);

  void dispose();
}

typedef MapPointCallback = void Function(LatLng point);
typedef MapCameraCallback = void Function(MapCameraState camera, bool byGesture);

/// Bir harita motoru: kontrolcü + görünüm üretir.
abstract class MapEngine {
  const MapEngine();

  MapEngineController createController();

  /// Harita widget'ı. [overlays] liste sırasıyla (alttan üste) çizilir.
  Widget buildView({
    Key? key,
    required MapEngineController controller,
    required ResolvedBaseLayer baseLayer,
    required List<MapOverlay> overlays,
    required MapCameraState initialCamera,
    required double minZoom,
    required double maxZoom,
    VoidCallback? onReady,
    MapCameraCallback? onCameraChanged,
    MapPointCallback? onTap,
    MapPointCallback? onLongPress,
  });
}

/// Uygulamanın kullandığı motor — DEĞİŞTİRME NOKTASI BURASI.
///
/// Geçiş sırasında (planın 3. adımı) burası Mapbox motoruna çevrilecek.
const MapEngine kMapEngine = FlutterMapEngine();
