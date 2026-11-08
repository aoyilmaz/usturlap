import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/domain/models/saved_view.dart';
import 'package:kerteriz/features/map/saved_views_sheet.dart';
import 'package:kerteriz/providers/saved_view_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// D3g: kayıtlı görünümler.
void main() {
  late List<SavedView> applied;
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  SavedView current(String name) => SavedView(
    id: '',
    name: name,
    center: const LatLng(37.06, 37.38),
    zoom: 14,
    bearing: 15,
    layerId: 'sat',
    createdAt: DateTime(2026),
  );

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    applied = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SavedViewsPanel(
              current: current,
              onApply: applied.add,
              layerLabel: (id) => id == 'sat' ? 'Uydu' : null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(SavedViewsPanel)),
    );
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('kaydet: o anki görünüm adıyla eklenir; dokununca uygulanır', (
    tester,
  ) async {
    final c = await pump(tester);
    expect(find.text('Henüz kayıtlı görünüm yok.'), findsOneWidget);
    await tester.tap(find.text('Bu görünümü kaydet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kale');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final views = c.read(savedViewsProvider);
    expect(views, hasLength(1));
    expect(views.single.name, 'Kale');
    expect(views.single.id, isNotEmpty);
    expect(views.single.layerId, 'sat');
    expect(find.textContaining('z14 · Uydu'), findsOneWidget);

    await tester.tap(find.text('Kale'));
    expect(applied.single.center, const LatLng(37.06, 37.38));
    expect(applied.single.bearing, 15);
    await dispose(tester);
  });

  testWidgets('yeniden adlandır ve sil', (tester) async {
    final c = await pump(tester);
    c.read(savedViewsProvider.notifier).add(current('Kale'));
    await tester.pump();

    await tester.tap(find.byTooltip('Seçenekler: Kale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden adlandır'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kale kapısı');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(c.read(savedViewsProvider).single.name, 'Kale kapısı');

    await tester.tap(find.byTooltip('Seçenekler: Kale kapısı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(c.read(savedViewsProvider), isEmpty);
    await dispose(tester);
  });

  test('görünümler kalıcı (yeniden açılışta okunur)', () async {
    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      c.listen(savedViewsProvider, (_, _) {});
      return c;
    }

    final c = open();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c.read(savedViewsProvider.notifier).add(current('Kale'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final again = open();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(again.read(savedViewsProvider).single.name, 'Kale');
    expect(again.read(savedViewsProvider).single.zoom, 14);
  });
}
