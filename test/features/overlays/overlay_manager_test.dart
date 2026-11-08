import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/waypoint_repository.dart';
import 'package:kerteriz/domain/models/overlay_visibility.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/features/overlays/overlay_manager_sheet.dart';
import 'package:kerteriz/providers/overlay_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// D3f: Overlay yöneticisi + #etiketler.
void main() {
  late List<LatLng> centered;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    centered = [];
    // Kayıtlar widget akışı dinlemeden önce (aksi halde drift akış
    // bildirimi sahte zamanda bekler, gerçek zamandaki yazma kilitlenir).
    await tester.runAsync(() async {
      final repo = WaypointRepository(db);
      await repo.add(
        name: 'Kuyu',
        note: 'temiz #su',
        position: const LatLng(37, 37),
      );
      await repo.add(
        name: 'Tank',
        position: const LatLng(37.1, 37.1),
        affiliation: Affiliation.hostile,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: OverlayManager(onCenter: centered.add, onShowRoute: (_) {}),
          ),
        ),
      ),
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(OverlayManager)),
    );
    for (
      var i = 0;
      i < 10 && find.text('Noktalar (2)').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    return c;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('türe göre gruplar ve etiket çipleri', (tester) async {
    await pump(tester);
    expect(find.text('Noktalar (2)'), findsOneWidget);
    expect(find.text('Nokta (1)'), findsOneWidget);
    expect(find.text('Düşman (1)'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '#su'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('grup gözü: haritada gizler, tekrar basınca gösterir', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.byTooltip('Gizle: Düşman'));
    await tester.pump();
    expect(c.read(overlayVisibilityProvider).hiddenGroups, {
      OverlayVisibility.waypointGroup(Affiliation.hostile),
    });
    expect(find.text('Hepsini göster'), findsOneWidget);
    await tester.tap(find.byTooltip('Göster: Düşman'));
    await tester.pump();
    expect(c.read(overlayVisibilityProvider).isDefault, isTrue);
    await dispose(tester);
  });

  testWidgets('tek nokta gizlenir; dokununca haritada ortalanır', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.text('Nokta (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuyu'));
    expect(centered, [const LatLng(37, 37)]);
    await tester.tap(find.byTooltip('Gizle: Kuyu'));
    await tester.pump();
    expect(c.read(overlayVisibilityProvider).hiddenUids, hasLength(1));
    await dispose(tester);
  });

  testWidgets('etiket süzgeci listeyi daraltır; Hepsini göster sıfırlar', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, '#su'));
    await tester.pump();
    expect(c.read(overlayVisibilityProvider).tag, 'su');
    expect(find.text('Noktalar (1)'), findsOneWidget);
    expect(find.text('Düşman (1)'), findsNothing);
    await tester.ensureVisible(find.text('Hepsini göster'));
    await tester.pump();
    await tester.tap(find.text('Hepsini göster'));
    await tester.pump();
    expect(c.read(overlayVisibilityProvider).isDefault, isTrue);
    expect(find.text('Noktalar (2)'), findsOneWidget);
    await dispose(tester);
  });
}
