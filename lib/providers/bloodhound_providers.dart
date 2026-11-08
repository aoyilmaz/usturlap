import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models/bloodhound.dart';
import '../domain/models/range_line.dart';
import 'location_providers.dart';
import 'range_line_providers.dart';
import 'settings_providers.dart';

/// Açık takipler (ATAK Multiple Bloodhounds). "Git" hedefi gibi bellekte:
/// uygulama yeniden açılınca boş başlar.
class BloodhoundsNotifier extends Notifier<List<Bloodhound>> {
  int _nextId = 1;

  @override
  List<Bloodhound> build() => const [];

  /// Aynı iki uç arasında zaten takip varsa yenisi eklenmez; false döner.
  bool add(RbEnd from, RbEnd to) {
    if (state.any((b) => b.from == from && b.to == to)) return false;
    state = [...state, Bloodhound(id: _nextId++, from: from, to: to)];
    return true;
  }

  void remove(int id) => state = [
    for (final b in state)
      if (b.id != id) b,
  ];

  void clear() => state = const [];
}

final bloodhoundsProvider =
    NotifierProvider<BloodhoundsNotifier, List<Bloodhound>>(
      BloodhoundsNotifier.new,
    );

const _thresholdsKey = 'bloodhound_eta';

/// ETA renk eşikleri (kalıcı).
class EtaThresholdsNotifier extends Notifier<EtaThresholds> {
  bool _changed = false;

  @override
  EtaThresholds build() {
    _load();
    return const EtaThresholds();
  }

  Future<void> _load() async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .get(_thresholdsKey);
    if (saved == null || _changed) return;
    try {
      state = EtaThresholds.fromJson(jsonDecode(saved));
    } catch (_) {
      // Bozuk kayıt: varsayılan.
    }
  }

  void setMinutes({int? warn, int? alarm}) {
    _changed = true;
    state = state.withMinutes(warn: warn, alarm: alarm);
    ref
        .read(settingsRepositoryProvider)
        .set(_thresholdsKey, jsonEncode(state.toJson()));
  }
}

final etaThresholdsProvider =
    NotifierProvider<EtaThresholdsNotifier, EtaThresholds>(
      EtaThresholdsNotifier.new,
    );

/// Uçları çözülmüş ve okunmuş takip.
class ResolvedBloodhound {
  ResolvedBloodhound(this.bloodhound, this.from, this.to, this.reading);

  final Bloodhound bloodhound;
  final LatLng from;
  final LatLng to;
  final BloodhoundReading reading;

  LatLng get middle => LatLng(
    (from.latitude + to.latitude) / 2,
    (from.longitude + to.longitude) / 2,
  );
}

final resolvedBloodhoundsProvider = Provider<List<ResolvedBloodhound>>((ref) {
  final list = ref.watch(bloodhoundsProvider);
  if (list.isEmpty) return const [];
  final at = ref.watch(anchorResolverProvider);
  final speed = ref.watch(selfContactProvider)?.speedMps;
  final thresholds = ref.watch(etaThresholdsProvider);
  ResolvedBloodhound resolve(Bloodhound b) {
    final from = at(b.from), to = at(b.to);
    final reading = BloodhoundReading.of(
      from,
      to,
      hasSpeed: b.hasSpeed,
      speedMps: speed,
      thresholds: thresholds,
    );
    return ResolvedBloodhound(b, from, to, reading);
  }

  return [for (final b in list) resolve(b)];
});
