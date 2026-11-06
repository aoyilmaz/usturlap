import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'map_types.dart';
import 'mapbox_engine.dart';

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

  /// Yumuşak yakınlaştır/uzaklaştır (+1 = bir kademe yakın).
  void zoomBy(double delta);

  /// İki parmakla döndürmeyi kilitle/aç (ATAK Manual Orientation Lock).
  /// Harita yeniden kurulsa da korunur.
  void setRotationLocked(bool locked);

  /// [bounds] ekrana sığacak şekilde kamerayı ayarlar.
  void fitBounds(GeoBounds bounds, {EdgeInsets padding = const EdgeInsets.all(40)});

  /// Harita widget'ı içindeki [rect] (mantıksal piksel) dikdörtgeninin
  /// kapsadığı coğrafi alan (harita dönükse 4 köşeyi kapsayan dikdörtgen).
  /// Harita hazır değilse null.
  Future<GeoBounds?> boundsOfScreenRect(Rect rect);

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

  /// 3B arazi çizebilir mi.
  bool get supportsTerrain => false;

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
    bool terrain3d = false,
    bool nightMode = false,
    // Haritanın üstünü kaplayan arayüz (planlama çubuğu vb.): logo/atıf gibi
    // motor süsleri bunun dışında kalsın (Mapbox şartı: görünür olmalı).
    // GÜVENLİ ALANA EK OLARAK verilir: Mapbox iOS süslerin kenar boşluğunu
    // safeAreaLayoutGuide'dan ölçer (OrnamentsManager.swift), güvenli alanı
    // burada tekrar eklemek logoyu fazladan kaydırır.
    EdgeInsets ornamentPadding = EdgeInsets.zero,
  });
}

/// Uygulamanın kullandığı motor — DEĞİŞTİRME NOKTASI BURASI.
///
/// Sözleşme ileride başka motorlara (ör. MapLibre) geçişi kolaylaştırmak için
/// korunur; flutter_map motoru 2026-11-04'te kaldırıldı.
const MapEngine kMapEngine = MapboxEngine();
