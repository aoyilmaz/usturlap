import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/utils/kalman_filter.dart';
import '../../core/wmm.dart';
import '../../domain/models/contact.dart';
import '../../domain/ports/position_source.dart';

/// v1 `PositionSource` implementasyonu: telefonun GPS'i + pusulası.
///
/// Tek bir `Contact` (kendi konumumuz, `isSelf == true`) yayar. Konum
/// güncellemesi (geolocator) ve kerteriz (flutter_compass) ayrı akışlardan
/// gelir; ikisinin en son değeri birleştirilip her değişimde yeni bir
/// `Contact` üretilir.
class DevicePositionSource implements PositionSource {
  DevicePositionSource({this.callsign = AppConstants.defaultCallsign});

  final String callsign;

  final StreamController<List<Contact>> _controller =
      StreamController<List<Contact>>.broadcast();

  StreamSubscription<Position>? _posSub;
  StreamSubscription<CompassEvent>? _headingSub;

  final KalmanFilter _headingFilter = KalmanFilter();

  Position? _lastPosition;
  double? _lastHeading;
  bool _started = false;

  /// true iken arka planda (ekran kapalı) da konum gelir. Sadece iz kaydında.
  bool _backgroundEnabled = false;

  @override
  Stream<List<Contact>> get contacts => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1) Konum servisi açık mı + izin var mı?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _controller.addError(
          StateError('Konum servisi kapalı. Ayarlardan açın.'));
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _controller.addError(StateError('Konum izni verilmedi.'));
      return;
    }

    // 2) Konum akışı (ön plan; kayıt başlayınca arka plana yükseltilir)
    _subscribePosition();

    // 3) Pusula akışı (her cihazda olmayabilir; null gelebilir)
    final compass = FlutterCompass.events;
    if (compass != null) {
      _headingSub = compass.listen((event) {
        final raw = event.heading;
        // iOS konum yokken trueHeading'i -1 (geçersiz) verir.
        if (raw == null || raw < 0) return;
        _lastHeading = _headingFilter.update(_toTrueNorth(raw));
        _emit();
      });
    }
  }

  /// Pusula okumasını coğrafi kuzeye çevirir. Uygulamanın bütün hesapları
  /// coğrafi kuzeye göre yapılır.
  /// - iOS: flutter_compass zaten `trueHeading` verir (sapmayı iOS uygular).
  /// - Android: rotation-vector sensörü manyetik kuzey verir → WMM2025
  ///   sapması eklenir. Konum henüz yoksa manyetik değer kullanılır.
  double _toTrueNorth(double heading) {
    if (defaultTargetPlatform != TargetPlatform.android) return heading;
    final pos = _lastPosition;
    if (pos == null) return heading;
    final d = Wmm.declination(pos.latitude, pos.longitude);
    return ((heading + d) % 360 + 360) % 360;
  }

  /// Konum akışına (yeniden) abone olur — güncel ayarlarla.
  void _subscribePosition() {
    _posSub?.cancel();
    _posSub =
        Geolocator.getPositionStream(locationSettings: _buildLocationSettings())
            .listen((pos) {
      _lastPosition = pos;
      _emit();
    }, onError: _controller.addError);
  }

  @override
  Future<void> setBackgroundEnabled(bool enabled) async {
    if (_backgroundEnabled == enabled) return;
    _backgroundEnabled = enabled;
    // Çalışıyorsa yeni ayarlarla (arka plan açık/kapalı) yeniden abone ol.
    if (_started && _posSub != null) {
      _subscribePosition();
    }
  }

  /// Platforma göre konum ayarları. `_backgroundEnabled` true ise (iz kaydı ya
  /// da arka planda izlenen geofence) iOS arka plan güncellemeleri + gösterge,
  /// Android foreground servis bildirimi açılır. Aksi halde ön-plan (batarya
  /// dostu).
  LocationSettings _buildLocationSettings() {
    const accuracy = LocationAccuracy.best;
    // Batarya optimizasyonu için Mesafe Filtresi (Distance Filter)
    // 2 metre hareket etmeden yeni konum akışı tetiklenmez.
    const int distanceFilterMeters = 0;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: _backgroundEnabled,
          showBackgroundLocationIndicator: _backgroundEnabled,
        );
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
          foregroundNotificationConfig: _backgroundEnabled
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'Usturlap',
                  notificationText: 'Konum izleniyor (iz kaydı / geofence)',
                  notificationIcon: AndroidResource(
                      name: 'ic_stat_usturlap', defType: 'drawable'),
                  enableWakeLock: true,
                )
              : null,
        );
      default:
        return const LocationSettings(
            accuracy: accuracy, distanceFilter: distanceFilterMeters);
    }
  }

  void _emit() {
    final pos = _lastPosition;
    if (pos == null) return;
    _controller.add([
      buildSelfContact(
        callsign: callsign,
        latitude: pos.latitude,
        longitude: pos.longitude,
        // geolocator: hız m/s, yükseklik metre. heading'i pusuladan alıyoruz;
        // pusula yoksa GPS'in rota açısına (course) düşeriz.
        speedMps: pos.speed,
        altitudeMeters: pos.altitude,
        headingDeg: _lastHeading ?? (pos.heading.isFinite ? pos.heading : null),
        accuracyMeters: pos.accuracy,
        timestamp: pos.timestamp,
      ),
    ]);
  }

  @override
  Future<void> stop() async {
    await _posSub?.cancel();
    await _headingSub?.cancel();
    _posSub = null;
    _headingSub = null;
    _started = false;
  }

  /// Kaynakları serbest bırakır. Bir daha kullanılamaz.
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  /// Saf yardımcı (test edilebilir): ham değerlerden bir `Contact` üretir.
  ///
  /// geolocator geçersiz değerleri bazen negatif/NaN olarak verir; burada
  /// temizleyip makul `Contact` alanlarına çeviriyoruz.
  static Contact buildSelfContact({
    required String callsign,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? speedMps,
    double? altitudeMeters,
    double? headingDeg,
    double? accuracyMeters,
  }) {
    double? cleanSpeed = speedMps;
    if (cleanSpeed == null || !cleanSpeed.isFinite || cleanSpeed < 0) {
      cleanSpeed = null;
    }
    double? cleanAlt = altitudeMeters;
    if (cleanAlt == null || !cleanAlt.isFinite) {
      cleanAlt = null;
    }
    double? cleanHeading = headingDeg;
    if (cleanHeading == null || !cleanHeading.isFinite || cleanHeading < 0) {
      cleanHeading = null;
    } else {
      cleanHeading = cleanHeading % 360.0;
    }
    double? cleanAcc = accuracyMeters;
    if (cleanAcc == null || !cleanAcc.isFinite || cleanAcc < 0) {
      cleanAcc = null;
    }

    return Contact(
      callsign: callsign,
      position: LatLng(latitude, longitude),
      speedMps: cleanSpeed,
      altitudeMsl: cleanAlt,
      headingDeg: cleanHeading,
      accuracyMeters: cleanAcc,
      timestamp: timestamp,
      isSelf: true,
    );
  }
}
