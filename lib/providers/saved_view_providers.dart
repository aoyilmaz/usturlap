import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/uuid.dart';
import '../domain/models/saved_view.dart';
import 'settings_providers.dart';

const _key = 'saved_views';

/// Kayıtlı görünümler (eskiden yeniye). Ayarlarda JSON; acil silmede gider.
class SavedViewsNotifier extends Notifier<List<SavedView>> {
  bool _changed = false;

  @override
  List<SavedView> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).get(_key);
    if (saved == null || _changed) return;
    try {
      final list = jsonDecode(saved);
      if (list is! List) return;
      state = [for (final e in list) ?SavedView.fromJson(e)];
    } catch (_) {
      // Bozuk kayıt: boş liste.
    }
  }

  /// Yeni görünüm ekler; kimliği burada verilir.
  SavedView add(SavedView v) {
    final withId = SavedView(
      id: newUuidV4(),
      name: v.name,
      center: v.center,
      zoom: v.zoom,
      bearing: v.bearing,
      layerId: v.layerId,
      createdAt: DateTime.now(),
    );
    _save([...state, withId]);
    return withId;
  }

  void rename(String id, String name) =>
      _save([for (final v in state) v.id == id ? v.renamed(name) : v]);

  void delete(String id) => _save([
    for (final v in state)
      if (v.id != id) v,
  ]);

  void _save(List<SavedView> views) {
    _changed = true;
    state = List.unmodifiable(views);
    ref
        .read(settingsRepositoryProvider)
        .set(_key, jsonEncode([for (final v in views) v.toJson()]));
  }
}

final savedViewsProvider =
    NotifierProvider<SavedViewsNotifier, List<SavedView>>(
      SavedViewsNotifier.new,
    );
