import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/offline/mapbox_offline_store.dart';
import 'package:usturlap/domain/models/offline_region.dart';
import 'package:usturlap/features/offline/offline_frame_panel.dart';
import 'package:usturlap/providers/offline_providers.dart';

/// Gerçek Mapbox yerine kontrol edilebilir sahte servis.
class _FakeStore extends MapboxOfflineStore {
  final regions = <OfflineRegion>[];
  Completer<void>? gate; // indirmeyi testte bekletmek için
  Object? failWith;
  final progressCalls = <double>[];

  @override
  Future<List<OfflineRegion>> list() async => List.of(regions);

  @override
  Future<OfflineRegion> download(OfflineRegionSpec spec,
      {OfflineProgress? onProgress}) async {
    onProgress?.call(0.5, 1000);
    await gate?.future;
    if (failWith != null) throw failWith!;
    onProgress?.call(1.0, 2000);
    final r = OfflineRegion(
      id: 'pz-1',
      name: spec.name,
      south: spec.south,
      west: spec.west,
      north: spec.north,
      east: spec.east,
      maxZoom: spec.maxZoom,
      createdAt: DateTime(2026, 11, 2),
      sizeBytes: 2000,
      completedResources: 10,
      requiredResources: 10,
    );
    regions.add(r);
    return r;
  }

  @override
  Future<void> delete(String id) async => regions.removeWhere((r) => r.id == id);
}

const _spec = OfflineRegionSpec(
    name: 'Test', south: 39.9, west: 32.8, north: 40.0, east: 32.9, maxZoom: 16);

void main() {
  late _FakeStore store;
  late ProviderContainer c;

  setUp(() {
    store = _FakeStore();
    c = ProviderContainer(
        overrides: [offlineStoreProvider.overrideWithValue(store)]);
  });
  tearDown(() => c.dispose());

  test('indirme: ilerleme → tamamlandı, liste yenilenir', () async {
    store.gate = Completer();
    await c.read(offlineRegionsProvider.future);
    expect(c.read(offlineDownloadProvider.notifier).start(_spec), isTrue);
    await Future<void>.delayed(Duration.zero);

    final mid = c.read(offlineDownloadProvider)!;
    expect(mid.running, isTrue);
    expect(mid.fraction, 0.5);
    expect(mid.bytes, 1000);

    store.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final end = c.read(offlineDownloadProvider)!;
    expect(end.done, isTrue);
    expect(end.bytes, 2000);
    expect(c.read(offlineRegionsProvider).value!.single.name, 'Test');
  });

  test('aynı anda ikinci indirme başlatılmaz', () async {
    store.gate = Completer();
    final n = c.read(offlineDownloadProvider.notifier);
    expect(n.start(_spec), isTrue);
    expect(n.start(_spec), isFalse);
    n.dismiss(); // sürerken kapatılamaz
    expect(c.read(offlineDownloadProvider), isNotNull);
    store.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    n.dismiss();
    expect(c.read(offlineDownloadProvider), isNull);
  });

  test('750 paket sınırı hatası anlaşılır mesaja çevrilir', () async {
    store.failWith = Exception('TileRegionError: tile pack limit exceeded');
    c.read(offlineDownloadProvider.notifier).start(_spec);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final s = c.read(offlineDownloadProvider)!;
    expect(s.running, isFalse);
    expect(s.error, contains('750'));
  });

  test('bölge silme listeyi günceller', () async {
    store.regions.add(OfflineRegion(
      id: 'pz-9', name: 'Eski', south: 0, west: 0, north: 1, east: 1,
      maxZoom: 14, createdAt: DateTime(2026), sizeBytes: 1,
      completedResources: 1, requiredResources: 1));
    await c.read(offlineRegionsProvider.future);
    await c.read(offlineRegionsProvider.notifier).delete('pz-9');
    expect(c.read(offlineRegionsProvider).value, isEmpty);
  });

  test('OfflineRegion.isComplete', () {
    OfflineRegion r(int done, int req) => OfflineRegion(
        id: 'x', name: 'x', south: 0, west: 0, north: 0, east: 0, maxZoom: 0,
        createdAt: DateTime(2026), sizeBytes: 0,
        completedResources: done, requiredResources: req);
    expect(r(10, 10).isComplete, isTrue);
    expect(r(5, 10).isComplete, isFalse);
    expect(r(0, 0).isComplete, isFalse);
  });

  test('çerçeve dikdörtgeni ekranda kalır, alt panele yer bırakır', () {
    final f = offlineFrameRect(const Size(390, 844), const EdgeInsets.only(top: 47, bottom: 34));
    expect(f.left, 24);
    expect(f.right, 390 - 24);
    expect(f.top, 47 + 120);
    expect(f.bottom, lessThanOrEqualTo(844 - 34 - 300));
    // Çok küçük ekranda bile en az 120 px yükseklik.
    final small = offlineFrameRect(const Size(320, 480), EdgeInsets.zero);
    expect(small.height, greaterThanOrEqualTo(120));
  });
}
