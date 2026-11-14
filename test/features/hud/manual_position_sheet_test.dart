import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/features/hud/manual_position_sheet.dart';
import 'package:usturlap/features/shell/adaptive_sheet.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// D3c: GPS'siz konum düzeltme paneli.
void main() {
  late LatLng? applied;
  late int picks;

  Future<(ProviderContainer, BuildContext)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    applied = null;
    picks = 0;
    late BuildContext ctx;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: PanelHost(
            child: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    final c = ProviderScope.containerOf(ctx);
    // Bilinen nokta: kule.
    await tester.runAsync(
      () => c
          .read(waypointRepositoryProvider)
          .add(name: 'KULE', position: const LatLng(39.9, 32.85)),
    );
    showManualPositionSheet(
      ctx,
      onPickOnMap: () => picks++,
      onApplied: (p) => applied = p,
    );
    await tester.pumpAndSettle();
    // Nokta listesi (drift akışı) gerçek zamanda gelir.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    return (c, ctx);
  }

  /// drift akışlarının zamanlayıcıları test bitmeden kapansın.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('koordinat yazınca elle konum olur, panel kapanır', (
    tester,
  ) async {
    final (c, ctx) = await pump(tester);
    await tester.enterText(find.byType(TextField).first, '39.95 32.80');
    await tapVisible(tester, find.text('Uygula').first);
    expect(c.read(manualPositionProvider), const LatLng(39.95, 32.80));
    expect(applied, const LatLng(39.95, 32.80));
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
    await dispose(tester);
  });

  testWidgets('anlaşılmayan koordinat uyarı verir', (tester) async {
    final (c, _) = await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'saçma');
    await tapVisible(tester, find.text('Uygula').first);
    expect(find.text('Koordinat anlaşılamadı'), findsOneWidget);
    expect(c.read(manualPositionProvider), isNull);
    await dispose(tester);
  });

  testWidgets('bilinen noktadan kerteriz + mesafe (coğrafi, derece)', (
    tester,
  ) async {
    final (c, _) = await pump(tester);
    // Panel yarım ekran: aşağıdaki bölüm tembel listede henüz kurulmamış.
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<int>),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ManualPositionPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapVisible(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.text('KULE').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Kerteriz (°, Coğrafi)'),
      '90',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Mesafe (m)'),
      '1000',
    );
    await tapVisible(tester, find.text('Uygula').last);
    final p = c.read(manualPositionProvider)!;
    const tower = LatLng(39.9, 32.85);
    expect(GeoMath.distance(p, tower), closeTo(1000, 0.5));
    expect(GeoMath.bearing(p, tower), closeTo(90, 0.1));
    await dispose(tester);
  });

  testWidgets('haritada göster: panel kapanır, harita moduna geçilir', (
    tester,
  ) async {
    await pump(tester);
    await tapVisible(tester, find.text('Haritada dokunarak göster'));
    expect(picks, 1);
    await dispose(tester);
  });
}
