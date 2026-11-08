import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/recent_trail.dart';
import '../data/position/device_position_source.dart';
import '../domain/models/contact.dart';
import '../domain/ports/position_source.dart';
import 'settings_providers.dart';

/// Aktif `PositionSource`. v1'de telefon GPS'i; Faz 2'de buraya
/// `MeshPositionSource` takılacak — harita/HUD bu sağlayıcıyı dinlediği için
/// değişiklikten etkilenmezler (§4.1).
final positionSourceProvider = Provider<PositionSource>((ref) {
  final source = DevicePositionSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Kaynaktan gelen canlı `Contact` listesi akışı.
/// İlk dinleyici geldiğinde kaynağı başlatır, son dinleyici gidince durdurur.
final contactsProvider = StreamProvider<List<Contact>>((ref) {
  final source = ref.watch(positionSourceProvider);
  source.start();
  ref.onDispose(() => source.stop());
  return source.contacts;
});

/// GPS'ten gelen ham kendi konumu. İz kaydı ve son 15 dk izi bunu kullanır
/// (elle verilen konum kayda girmez).
final gpsSelfContactProvider = Provider<Contact?>((ref) {
  final async = ref.watch(contactsProvider);
  return async.maybeWhen(
    data: (list) {
      for (final c in list) {
        if (c.isSelf) return c;
      }
      return list.isNotEmpty ? list.first : null;
    },
    orElse: () => null,
  );
});

/// Elle verilen konum (GPS yokken / hatalıyken; ATAK self-marker ince ayar
/// ve polar giriş, kılavuz s.8). "GPS'e dön" diyene kadar geçerli; bellekte
/// tutulur (uygulama yeniden açılınca GPS'le başlar).
class ManualPositionNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void set(LatLng p) => state = p;

  void clear() => state = null;
}

final manualPositionProvider =
    NotifierProvider<ManualPositionNotifier, LatLng?>(
        ManualPositionNotifier.new);

/// Kendi konumumuz: elle konum verildiyse o (doğruluk bilinmez, yön
/// pusuladan), yoksa GPS. Harita, konum kutusu, navigasyon bunu kullanır.
final selfContactProvider = Provider<Contact?>((ref) {
  final gps = ref.watch(gpsSelfContactProvider);
  final manual = ref.watch(manualPositionProvider);
  if (manual == null) return gps;
  return Contact(
    callsign: gps?.callsign ?? ref.watch(callsignProvider),
    position: manual,
    timestamp: DateTime.now(),
    headingDeg: gps?.headingDeg,
    isSelf: true,
  );
});

/// Son 15 dakikanın kendi konumları (iz kaydından bağımsız, bellekte).
/// Harita ekranı her zaman dinler (Riverpod 3: dinlenmeyen sağlayıcı
/// duraklar ve toplamayı keserdi); yalnızca seçenek açıkken çizer.
class RecentTrailNotifier extends Notifier<List<LatLng>> {
  /// Bundan kötü doğruluklu konumlar ize girmez (titreme çizgisi olmasın).
  static const maxAccuracyMeters = 50.0;

  final _trail = RecentTrail();

  @override
  List<LatLng> build() {
    ref.listen<Contact?>(gpsSelfContactProvider, (_, c) {
      if (c == null) return;
      final acc = c.accuracyMeters;
      if (acc != null && acc > maxAccuracyMeters) return;
      if (_trail.add(c.position, c.timestamp)) state = _trail.points;
    });
    return const [];
  }
}

final recentTrailProvider =
    NotifierProvider<RecentTrailNotifier, List<LatLng>>(RecentTrailNotifier.new);
