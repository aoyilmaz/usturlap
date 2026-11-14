import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/battery_alarm.dart';
import 'alert_providers.dart';
import 'nav_providers.dart';
import 'route_providers.dart';
import 'settings_providers.dart';
import 'track_providers.dart';

/// Ekranı açık tutma seçeneği.
enum KeepScreenOn {
  off('Kapalı'),
  mission('Görevde'),
  always('Her zaman');

  const KeepScreenOn(this.label);
  final String label;
}

class KeepScreenOnNotifier extends Notifier<KeepScreenOn> {
  static const _key = 'keep_screen_on';

  @override
  KeepScreenOn build() {
    _load();
    return KeepScreenOn.mission;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_key);
    final v = KeepScreenOn.values.asNameMap()[saved];
    if (v != null && ref.mounted) state = v;
  }

  void set(KeepScreenOn v) {
    state = v;
    ref.read(settingsRepositoryProvider).set(_key, v.name);
  }
}

/// Ekranı açık tut: Kapalı / Görevde (iz kaydı, rota takibi ya da Git
/// hedefi varken) / Her zaman. Varsayılan: Görevde.
final keepScreenOnProvider =
    NotifierProvider<KeepScreenOnNotifier, KeepScreenOn>(
      KeepScreenOnNotifier.new,
    );

/// Ekran şu an açık tutulmalı mı.
final wakeWantedProvider = Provider<bool>((ref) {
  return switch (ref.watch(keepScreenOnProvider)) {
    KeepScreenOn.off => false,
    KeepScreenOn.always => true,
    KeepScreenOn.mission =>
      ref.watch(recordingProvider).isRecording ||
          ref.watch(activeRouteProvider) != null ||
          ref.watch(navTargetProvider) != null,
  };
});

/// İz kaydı kendiliğinden dursun (dakika; 0 = kapalı).
class TrackAutoStopNotifier extends Notifier<int> {
  static const _key = 'track_auto_stop_min';
  static const choices = [0, 60, 120, 240];

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final v = int.tryParse(
      await ref.read(settingsRepositoryProvider).get(_key) ?? '',
    );
    if (v != null && choices.contains(v) && ref.mounted) state = v;
  }

  void set(int minutes) {
    state = minutes;
    ref.read(settingsRepositoryProvider).set(_key, '$minutes');
  }
}

final trackAutoStopProvider = NotifierProvider<TrackAutoStopNotifier, int>(
  TrackAutoStopNotifier.new,
);

/// Düşük pil uyarısı (%20, %10, %5). Varsayılan açık.
final lowBatteryAlertProvider = NotifierProvider<BoolSettingNotifier, bool>(
  () => BoolSettingNotifier('low_battery_alert', true),
);

/// Pil durumu.
class BatteryStatus {
  const BatteryStatus(this.level, {required this.charging});

  final int level;
  final bool charging;
}

/// Pil düzeyi: açılışta, 2 dakikada bir ve şarj durumu değişince okunur.
final batteryStatusProvider = StreamProvider<BatteryStatus>((ref) {
  final battery = Battery();
  final out = StreamController<BatteryStatus>();
  var charging = false;
  Future<void> read() async {
    try {
      final level = await battery.batteryLevel;
      if (!out.isClosed) out.add(BatteryStatus(level, charging: charging));
    } catch (_) {
      // Pil okunamıyorsa (simülatör vb.) uyarı yok.
    }
  }

  final sub = battery.onBatteryStateChanged.listen((s) {
    charging = s == BatteryState.charging || s == BatteryState.full;
    read();
  }, onError: (_) {});
  final timer = Timer.periodic(const Duration(minutes: 2), (_) => read());
  read();
  ref.onDispose(() {
    timer.cancel();
    sub.cancel();
    out.close();
  });
  return out.stream;
});

/// Son düşük pil uyarısı: pil düzeyi ve sıra numarası (aynı düzey yeniden
/// uyarılsa da değişsin). Harita ekranı titreşim + şerit + sesli /
/// bildirim verir.
class LowBatteryNotifier extends Notifier<({int level, int seq})?> {
  final _alarm = BatteryAlarm();
  var _seq = 0;

  @override
  ({int level, int seq})? build() {
    ref.listen<AsyncValue<BatteryStatus>>(batteryStatusProvider, (_, next) {
      final s = next.value;
      if (s == null || !ref.read(lowBatteryAlertProvider)) return;
      final hit = _alarm.update(s.level, charging: s.charging);
      if (hit != null) state = (level: s.level, seq: ++_seq);
    });
    return null;
  }
}

final lowBatteryProvider =
    NotifierProvider<LowBatteryNotifier, ({int level, int seq})?>(
      LowBatteryNotifier.new,
    );
