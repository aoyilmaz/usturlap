import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/overlay_visibility.dart';
import 'settings_providers.dart';

const _key = 'overlay_visibility';

/// Overlay Manager seçimleri (gizli gruplar / nesneler, etiket süzgeci).
/// Ayarlarda kalıcı.
class OverlayVisibilityNotifier extends Notifier<OverlayVisibility> {
  bool _changed = false;

  @override
  OverlayVisibility build() {
    _load();
    return const OverlayVisibility();
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_key);
    if (saved == null || _changed) return;
    try {
      state = OverlayVisibility.fromJson(jsonDecode(saved));
    } catch (_) {
      // Bozuk kayıt: varsayılan (her şey görünür).
    }
  }

  void update(OverlayVisibility Function(OverlayVisibility) change) {
    _changed = true;
    state = change(state);
    ref.read(settingsRepositoryProvider).set(_key, jsonEncode(state.toJson()));
  }

  void reset() => update((_) => const OverlayVisibility());
}

final overlayVisibilityProvider =
    NotifierProvider<OverlayVisibilityNotifier, OverlayVisibility>(
      OverlayVisibilityNotifier.new,
    );
