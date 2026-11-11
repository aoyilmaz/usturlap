import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/alerts/plugin_alert_notifications.dart';
import '../data/alerts/tts_speaker.dart';
import '../domain/models/map_graphic.dart';
import '../domain/ports/alert_output.dart';
import 'graphic_providers.dart';
import 'route_providers.dart';
import 'settings_providers.dart';

final speakerProvider = Provider<Speaker>((ref) => TtsSpeaker());

final alertNotificationsProvider = Provider<AlertNotifications>(
  (ref) => PluginAlertNotifications(),
);

/// Uygulama önde mi (ekranda). Arka plandayken uyarı bildirimle verilir.
final appForegroundProvider = Provider<bool Function()>(
  (ref) => () {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  },
);

/// Kalıcı aç/kapa ayarı (settings tablosunda "true"/"false").
class BoolSettingNotifier extends Notifier<bool> {
  BoolSettingNotifier(this._key, this._default);

  final String _key;
  final bool _default;

  @override
  bool build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_key);
    if (saved != null && ref.mounted) state = saved == 'true';
  }

  void set(bool value) {
    state = value;
    ref.read(settingsRepositoryProvider).set(_key, value.toString());
  }
}

/// Sesli uyarılar (rota, geofence, takip). Varsayılan açık.
final voiceAlertsProvider = NotifierProvider<BoolSettingNotifier, bool>(
  () => BoolSettingNotifier('voice_alerts', true),
);

/// Geofence uygulama arka plandayken de izlensin (arka plan konumu açık
/// kalır; iOS mavi göstergeyi gösterir, pil biraz daha harcanır).
/// Varsayılan açık.
final geofenceBackgroundProvider = NotifierProvider<BoolSettingNotifier, bool>(
  () => BoolSettingNotifier('geofence_background', true),
);

/// Uyarılı (geofence'li) kapalı çizim var mı.
final hasGeofencesProvider = Provider<bool>((ref) {
  final graphics = ref.watch(mapGraphicsProvider).value ?? const <MapGraphic>[];
  return graphics.any((g) => g.closed && g.geofence != null);
});

/// Bildirim izni gerekecek mi: geofence ya da rota takibi var.
final alertPermissionWantedProvider = Provider<bool>(
  (ref) =>
      ref.watch(hasGeofencesProvider) || ref.watch(activeRouteProvider) != null,
);

/// Bir uyarıyı ortama göre verir: uygulama öndeyse (ses açıksa) sesli
/// okur; arka plandaysa bildirim gösterir. Titreşim ve ekrandaki şerit
/// harita ekranında kalır.
class AlertDispatcher {
  AlertDispatcher(this._ref);

  final Ref _ref;
  var _nextId = 1;

  /// [speech]: okunacak metin (yoksa [body]).
  void alert({required String title, required String body, String? speech}) {
    if (_ref.read(appForegroundProvider)()) {
      if (_ref.read(voiceAlertsProvider)) {
        _ref.read(speakerProvider).speak(speech ?? body);
      }
    } else {
      _ref.read(alertNotificationsProvider).show(_nextId++, title, body);
    }
  }
}

final alertDispatcherProvider = Provider<AlertDispatcher>(AlertDispatcher.new);
