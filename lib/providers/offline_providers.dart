import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline/mapbox_offline_store.dart';
import '../domain/models/offline_region.dart';

final offlineStoreProvider =
    Provider<MapboxOfflineStore>((ref) => MapboxOfflineStore());

/// İndirilmiş bölgeler. İndirme/silme sonrası [OfflineRegionsNotifier.refresh].
class OfflineRegionsNotifier extends AsyncNotifier<List<OfflineRegion>> {
  @override
  Future<List<OfflineRegion>> build() => ref.read(offlineStoreProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(ref.read(offlineStoreProvider).list);
  }

  Future<void> delete(String id) async {
    await ref.read(offlineStoreProvider).delete(id);
    await refresh();
  }
}

final offlineRegionsProvider =
    AsyncNotifierProvider<OfflineRegionsNotifier, List<OfflineRegion>>(
        OfflineRegionsNotifier.new);

/// Süren (ya da yeni biten) indirmenin durumu. null → indirme yok.
class OfflineDownloadState {
  const OfflineDownloadState({
    required this.name,
    this.fraction = 0,
    this.bytes = 0,
    this.done = false,
    this.error,
  });

  final String name;
  final double fraction;
  final int bytes;
  final bool done;
  final String? error;

  bool get running => !done && error == null;

  OfflineDownloadState copyWith(
          {double? fraction, int? bytes, bool? done, String? error}) =>
      OfflineDownloadState(
        name: name,
        fraction: fraction ?? this.fraction,
        bytes: bytes ?? this.bytes,
        done: done ?? this.done,
        error: error ?? this.error,
      );
}

class OfflineDownloadNotifier extends Notifier<OfflineDownloadState?> {
  @override
  OfflineDownloadState? build() => null;

  /// Aynı anda tek indirme. Başlatıldıysa false döner.
  bool start(OfflineRegionSpec spec) {
    if (state?.running ?? false) return false;
    state = OfflineDownloadState(name: spec.name);
    _run(spec);
    return true;
  }

  Future<void> _run(OfflineRegionSpec spec) async {
    try {
      await ref.read(offlineStoreProvider).download(spec,
          onProgress: (f, bytes) {
        final s = state;
        if (s != null && s.running) state = s.copyWith(fraction: f, bytes: bytes);
      });
      state = state?.copyWith(fraction: 1, done: true);
    } catch (e) {
      state = state?.copyWith(error: _friendlyError(e));
    }
    await ref.read(offlineRegionsProvider.notifier).refresh();
  }

  /// Bilgi kartını kapat.
  void dismiss() {
    if (state?.running ?? false) return;
    state = null;
  }

  static String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('limit') || s.contains('Limit')) {
      return 'Mapbox çevrimdışı sınırı (${MapboxOfflineStore.tilePackLimit} '
          'karo paketi) doldu. Eski bölgeleri silin.';
    }
    if (s.contains('connect') || s.contains('network') || s.contains('Network')) {
      return 'Ağ bağlantısı yok ya da kesildi.';
    }
    return s;
  }
}

final offlineDownloadProvider =
    NotifierProvider<OfflineDownloadNotifier, OfflineDownloadState?>(
        OfflineDownloadNotifier.new);

/// Test amaçlı Mapbox ağ kesme (uygulama açıkken geçerli; yeniden başlatınca açık).
class OfflineTestModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> set(bool offline) async {
    await ref.read(offlineStoreProvider).setNetworkEnabled(!offline);
    state = offline;
  }
}

final offlineTestModeProvider =
    NotifierProvider<OfflineTestModeNotifier, bool>(OfflineTestModeNotifier.new);
