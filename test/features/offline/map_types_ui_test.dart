import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/offline/mapbox_offline_store.dart';
import 'package:kerteriz/domain/models/offline_region.dart';
import 'package:kerteriz/features/map/base_layer.dart';
import 'package:kerteriz/features/map/engine/map_types.dart';
import 'package:kerteriz/features/map/missing_layer_dialog.dart';
import 'package:kerteriz/features/offline/offline_frame_panel.dart';
import 'package:kerteriz/providers/offline_providers.dart';

class _Store extends MapboxOfflineStore {
  final asked = <List<OfflineMapType>>[];
  @override
  Future<int> estimateBytes(OfflineRegionSpec spec) async {
    asked.add(spec.types);
    return 1024 * 1024 * spec.types.length;
  }

  @override
  Future<List<OfflineRegion>> list() async => const [];
}

/// Aşama H: harita türü seçimi ve dosyası olmayan katman penceresi.
void main() {
  testWidgets('indirme paneli: tür çipleri, en az biri, tahmin yenilenir', (
    tester,
  ) async {
    final store = _Store();
    final tick = ValueNotifier(0);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: OfflineFramePanel(
              defaultName: 'Bölge 1',
              initialTypes: const [OfflineMapType.outdoors],
              frameBounds: () async => const GeoBounds(
                south: 39.9,
                west: 32.8,
                north: 40,
                east: 32.9,
              ),
              cameraTick: tick,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(store.asked.last, [OfflineMapType.outdoors]);
    FilterChip chip(String l) =>
        tester.widget(find.widgetWithText(FilterChip, l));
    expect(chip('Topografik').selected, isTrue);
    expect(chip('Uydu').selected, isFalse);

    await tester.tap(find.widgetWithText(FilterChip, 'Uydu'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    // Sabit sıra: Uydu, Sokak, Topografik.
    expect(store.asked.last, [
      OfflineMapType.satellite,
      OfflineMapType.outdoors,
    ]);
    expect(find.textContaining('2.0 MB'), findsOneWidget);

    // Son seçili tür kaldırılamaz.
    await tester.tap(find.widgetWithText(FilterChip, 'Uydu'));
    await tester.tap(find.widgetWithText(FilterChip, 'Topografik'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(chip('Topografik').selected, isTrue);
    expect(store.asked.last, [OfflineMapType.outdoors]);
  });

  testWidgets('dosyası olmayan katman: iki seçenek ve kapat', (tester) async {
    final vec = kBaseLayers.firstWhere((l) => l.id == 'vec_turkiye');
    MissingLayerChoice? got;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              got = await showMissingLayerDialog(ctx, vec);
              closed = true;
            },
            child: const Text('aç'),
          ),
        ),
      ),
    );
    Future<void> open() async {
      closed = false;
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Vektör — Türkiye: dosya yok'), findsOneWidget);
    expect(find.textContaining('turkey.pmtiles'), findsOneWidget);
    await tester.tap(find.text('İçe aktar'));
    await tester.pumpAndSettle();
    expect(got, MissingLayerChoice.importFile);

    await open();
    await tester.tap(find.text('Sokak\'ta bölge indir'));
    await tester.pumpAndSettle();
    expect(got, MissingLayerChoice.downloadStreets);

    await open();
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(got, isNull);
  });
}
