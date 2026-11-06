import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bearing_format.dart';
import '../core/constants.dart';
import '../core/coord_format.dart';
import '../data/db/settings_repository.dart';
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

  void cycle() => set(state.next);

  void set(CoordFormatType value) {
    state = value;
    ref.read(settingsRepositoryProvider).set(_coordFormatKey, value.name);
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

const _northRefKey = 'north_ref';

/// Kerterizlerin hangi kuzeye göre gösterileceği (ATAK: True/Magnetic/Grid).
/// Hesaplar hep coğrafi kuzeyle yapılır; bu yalnızca gösterimi değiştirir.
class NorthRefNotifier extends Notifier<NorthRef> {
  @override
  NorthRef build() {
    _load();
    return NorthRef.trueNorth;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_northRefKey);
    if (saved != null) state = NorthRef.fromName(saved);
  }

  void set(NorthRef value) {
    state = value;
    ref.read(settingsRepositoryProvider).set(_northRefKey, value.name);
  }
}

final northRefProvider =
    NotifierProvider<NorthRefNotifier, NorthRef>(NorthRefNotifier.new);

const _angleUnitKey = 'angle_unit';

/// Açı birimi: derece ya da NATO mili (6400). Kalıcı.
class AngleUnitNotifier extends Notifier<AngleUnit> {
  @override
  AngleUnit build() {
    _load();
    return AngleUnit.degrees;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_angleUnitKey);
    if (saved != null) state = AngleUnit.fromName(saved);
  }

  void set(AngleUnit value) {
    state = value;
    ref.read(settingsRepositoryProvider).set(_angleUnitKey, value.name);
  }
}

final angleUnitProvider =
    NotifierProvider<AngleUnitNotifier, AngleUnit>(AngleUnitNotifier.new);

/// Ekrandaki bütün kerterizler bu biçimlendiriciden geçer.
final bearingFormatterProvider = Provider<BearingFormatter>((ref) {
  return BearingFormatter(
    ref: ref.watch(northRefProvider),
    unit: ref.watch(angleUnitProvider),
  );
});

const _crosshairKey = 'show_crosshair';

/// Haritanın ortasında artı imleç (eldivenle nokta koymak için).
/// ATAK'ta yok → varsayılan kapalı; Ayarlar'dan açılır. Kalıcı.
class CrosshairNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_crosshairKey);
    if (saved == 'true') state = true;
  }

  void toggle() {
    state = !state;
    ref.read(settingsRepositoryProvider).set(_crosshairKey, state.toString());
  }
}

final crosshairProvider =
    NotifierProvider<CrosshairNotifier, bool>(CrosshairNotifier.new);
