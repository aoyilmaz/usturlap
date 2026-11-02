import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/coord_format.dart';
import '../data/db/settings_repository.dart';
import '../features/map/engine/map_engine.dart' show MapEngineKind;
import 'waypoint_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

const _coordFormatKey = 'coord_format';

/// Seçili koordinat biçimi (MGRS/UTM/WGS84). Drift'te kalıcı saklanır.
/// HUD'a çift dokununca [CoordFormatNotifier.cycle] ile döngüde değişir.
class CoordFormatNotifier extends Notifier<CoordFormatType> {
  @override
  CoordFormatType build() {
    _load();
    return CoordFormatType.mgrs; // kalıcı değer yüklenene kadar varsayılan
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_coordFormatKey);
    if (saved != null) {
      for (final t in CoordFormatType.values) {
        if (t.name == saved) {
          state = t;
          return;
        }
      }
    }
  }

  void cycle() {
    state = state.next;
    ref.read(settingsRepositoryProvider).set(_coordFormatKey, state.name);
  }
}

final coordFormatProvider =
    NotifierProvider<CoordFormatNotifier, CoordFormatType>(
        CoordFormatNotifier.new);

const _nightModeKey = 'night_mode';

/// Gece (düşük ışık) modu — haritaya kırmızı/karartma uygular. Kalıcı.
class NightModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_nightModeKey);
    if (saved == 'true') state = true;
  }

  void toggle() {
    state = !state;
    ref.read(settingsRepositoryProvider).set(_nightModeKey, state.toString());
  }
}

final nightModeProvider =
    NotifierProvider<NightModeNotifier, bool>(NightModeNotifier.new);

const _callsignKey = 'callsign';

/// Kullanıcının callsign'ı (HUD + track adı). Kalıcı.
class CallsignNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return AppConstants.defaultCallsign;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_callsignKey);
    if (saved != null && saved.trim().isNotEmpty) state = saved.trim();
  }

  void set(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    state = v;
    ref.read(settingsRepositoryProvider).set(_callsignKey, v);
  }
}

final callsignProvider =
    NotifierProvider<CallsignNotifier, String>(CallsignNotifier.new);

const _accuracyFilterKey = 'track_accuracy_filter';

/// Track kaydında düşük doğruluklu (gürültülü) GPS noktalarını ele.
/// `TrackFilter.maxAccuracyMeters` eşiğinden kötü noktalar atlanır.
class AccuracyFilterNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // varsayılan açık
  }

  Future<void> _load() async {
    final saved =
        await ref.read(settingsRepositoryProvider).get(_accuracyFilterKey);
    if (saved == 'false') state = false;
  }

  void toggle() {
    state = !state;
    ref
        .read(settingsRepositoryProvider)
        .set(_accuracyFilterKey, state.toString());
  }
}

final accuracyFilterProvider =
    NotifierProvider<AccuracyFilterNotifier, bool>(AccuracyFilterNotifier.new);

const _showRepeatersKey = 'show_repeaters';

/// Telsiz rölelerini haritada göster/gizle. Kalıcı.
class ShowRepeatersNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false; // varsayılan kapalı
  }

  Future<void> _load() async {
    final saved =
        await ref.read(settingsRepositoryProvider).get(_showRepeatersKey);
    if (saved == 'true') state = true;
  }

  void toggle() {
    state = !state;
    ref
        .read(settingsRepositoryProvider)
        .set(_showRepeatersKey, state.toString());
  }
}

final showRepeatersProvider =
    NotifierProvider<ShowRepeatersNotifier, bool>(ShowRepeatersNotifier.new);

const _mapEngineKey = 'map_engine';

/// Tercih edilen harita motoru (Mapbox / Klasik). Kalıcı.
///
/// Mapbox anahtarı yoksa her zaman Klasik. Kendi MBTiles/PMTiles katmanları
/// seçiliyken harita ekranı yine Klasik'e geçer (Mapbox henüz okuyamıyor).
class MapEngineKindNotifier extends Notifier<MapEngineKind> {
  static bool get _mapboxAvailable => AppConstants.mapboxAccessToken.isNotEmpty;

  @override
  MapEngineKind build() {
    _load();
    return _mapboxAvailable ? MapEngineKind.mapbox : MapEngineKind.flutterMap;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_mapEngineKey);
    if (saved == MapEngineKind.flutterMap.name) state = MapEngineKind.flutterMap;
  }

  void set(MapEngineKind kind) {
    if (kind == MapEngineKind.mapbox && !_mapboxAvailable) return;
    state = kind;
    ref.read(settingsRepositoryProvider).set(_mapEngineKey, kind.name);
  }
}

final mapEngineKindProvider =
    NotifierProvider<MapEngineKindNotifier, MapEngineKind>(
        MapEngineKindNotifier.new);
