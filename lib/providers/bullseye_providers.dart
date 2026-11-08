import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models/bullseye.dart';
import 'range_line_providers.dart';
import 'settings_providers.dart';

const _key = 'bullseye';

/// Tek bullseye (yoksa null). Ayarlarda JSON; acil silmede gider.
class BullseyeNotifier extends Notifier<Bullseye?> {
  bool _changed = false;

  @override
  Bullseye? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_key);
    if (saved == null || _changed) return;
    try {
      state = Bullseye.fromJson(jsonDecode(saved));
    } catch (_) {
      // Bozuk kayıt: bullseye yok.
    }
  }

  /// Kurar ya da değiştirir; null kaldırır.
  void set(Bullseye? b) {
    _changed = true;
    state = b;
    ref.read(settingsRepositoryProvider).set(_key, jsonEncode(b?.toJson()));
  }

  void update(Bullseye Function(Bullseye) fn) {
    final b = state;
    if (b != null) set(fn(b));
  }
}

final bullseyeProvider = NotifierProvider<BullseyeNotifier, Bullseye?>(
  BullseyeNotifier.new,
);

/// Merkezi bağlı olduğu nesnenin şimdiki konumuna çözülmüş bullseye.
class ResolvedBullseye {
  const ResolvedBullseye(this.bullseye, this.center);

  final Bullseye bullseye;
  final LatLng center;
}

final resolvedBullseyeProvider = Provider<ResolvedBullseye?>((ref) {
  final b = ref.watch(bullseyeProvider);
  if (b == null) return null;
  return ResolvedBullseye(b, ref.watch(anchorResolverProvider)(b.center));
});
