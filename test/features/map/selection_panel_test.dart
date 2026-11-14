import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/features/map/selection_panel.dart';
import 'package:usturlap/features/shell/adaptive_sheet.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/map_cleaner.dart';
import 'package:usturlap/providers/overlay_providers.dart';
import 'package:usturlap/providers/selection_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// G4: lasso seçimi ve seçim paneli.
void main() {
  late AppDatabase db;
  const square = [
    LatLng(37.0, 37.0),
    LatLng(37.0, 37.1),
    LatLng(37.1, 37.1),
    LatLng(37.1, 37.0),
  ];

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<(ProviderContainer, BuildContext)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final wps = WaypointRepository(db);
      await wps.add(
        name: 'İÇERİ',
        position: const LatLng(37.05, 37.05),
        uid: 'in',
      );
      await wps.add(
        name: 'GİZLİ',
        position: const LatLng(37.06, 37.06),
        uid: 'hid',
      );
      await wps.add(
        name: 'DIŞARI',
        position: const LatLng(37.5, 37.5),
        uid: 'out',
      );
      await MapGraphicRepository(db).add(
        name: 'HAT',
        type: GraphicType.line,
        points: const [LatLng(37.09, 37.09), LatLng(37.3, 37.3)],
        colorValue: 0xFFFF0000,
        uid: 'g',
      );
    });
    late BuildContext ctx;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: PanelHost(
            child: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    final c = ProviderScope.containerOf(ctx);
    c.listen(selectionProvider, (_, _) {});
    // Uygulamada harita ekranı nesne akışlarını dinler; testte biz.
    c.listen(mapClearTargetsProvider, (_, _) {});
    c
        .read(overlayVisibilityProvider.notifier)
        .update((v) => v.toggleUid('hid'));
    await settle(tester);
    return (c, ctx);
  }

  testWidgets('içerideki görünür nesneler seçilir; etiket eklenir', (
    tester,
  ) async {
    final (c, ctx) = await pump(tester);
    final sel = c.read(selectionProvider.notifier).select(square);
    expect(sel.waypoints.map((w) => w.name), ['İÇERİ']); // gizli ve dışarı yok
    expect(sel.graphics.single.name, 'HAT'); // bir köşesi içeride
    showSelectionPanel(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Seçim (2/2)'), findsOneWidget);

    // Çizimin işareti kaldırılır → etiket yalnız noktaya.
    await tester.tap(find.text('HAT'));
    await tester.pump();
    expect(find.text('Seçim (1/2)'), findsOneWidget);
    await tester.tap(find.text('Etiket ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '#Kuzey');
    await tester.tap(find.text('Ekle'));
    await settle(tester);
    expect(find.text('1 nesneye #Kuzey eklendi.'), findsOneWidget);
    final wp = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!.firstWhere((w) => w.uid == 'in');
    expect(wp.note, '#Kuzey');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('sil → Geri al; panel kapanınca seçim biter', (tester) async {
    final (c, ctx) = await pump(tester);
    c.read(selectionProvider.notifier).select(square);
    showSelectionPanel(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(find.text('2 nesne silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil').last);
    await settle(tester);
    await tester.pumpAndSettle(); // panelin kapanış animasyonu
    expect(c.read(selectionProvider), isNull); // panel kapandı
    var wps = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!;
    expect(wps.map((w) => w.uid), isNot(contains('in')));
    await tester.tap(find.text('Geri al'));
    await settle(tester);
    wps = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!;
    expect(wps.map((w) => w.uid), contains('in'));
    final g = await tester.runAsync(
      () => MapGraphicRepository(db).watchAll().first,
    );
    expect(g!.single.uid, 'g');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });
}
