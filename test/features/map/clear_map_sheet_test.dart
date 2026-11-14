import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/range_line_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:usturlap/features/map/clear_map_sheet.dart';
import 'package:usturlap/features/shell/adaptive_sheet.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// D4b: Haritayı temizle paneli.
void main() {
  late AppDatabase db;
  const p1 = LatLng(37.0, 37.0), p2 = LatLng(37.01, 37.0);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  testWidgets('sayılarla liste, kalıcı veri uyarısı, temizle → geri al', (
    tester,
  ) async {
    // Uzun ekran: yarım ekranlık panelde bütün liste görünsün.
    tester.view.physicalSize = const Size(1170, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await RangeLineRepository(
        db,
      ).add(name: 'R&B-1', start: const RbEnd(p1), end: const RbEnd(p2));
      await WaypointRepository(db).add(name: 'OP-1', position: p1);
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
    showClearMapSheet(ctx);
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('R&B çizgileri (1)'), findsOneWidget);
    expect(find.text('Noktalar (1)'), findsOneWidget);
    // Geçici işaretli, kalıcı işaretsiz.
    CheckboxListTile box(String t) =>
        tester.widget(find.widgetWithText(CheckboxListTile, t));
    expect(box('R&B çizgileri (1)').value, isTrue);
    expect(box('Noktalar (1)').value, isFalse);
    expect(find.textContaining('fotoğraflarıyla'), findsNothing);
    await tester.ensureVisible(find.text('Noktalar (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noktalar (1)'));
    await tester.pump();
    expect(find.textContaining('fotoğraflarıyla'), findsOneWidget);
    await tester.ensureVisible(find.text('Noktalar (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noktalar (1)')); // geri işaretsiz
    await tester.pump();

    // Düğme listenin üstünde.
    await tester.ensureVisible(find.text('Temizle (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temizle (1)'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Harita temizlendi.'), findsOneWidget);
    var lines = await tester.runAsync(
      () => RangeLineRepository(db).watchAll().first,
    );
    expect(lines, isEmpty);
    expect(
      await tester.runAsync(() => WaypointRepository(db).watchAll().first),
      hasLength(1),
    );

    await tester.tap(find.text('Geri al'));
    await settle(tester);
    lines = await tester.runAsync(
      () => RangeLineRepository(db).watchAll().first,
    );
    expect(lines!.single.name, 'R&B-1');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('Geri al şeridi süre dolunca kendiliğinden kapanır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => RangeLineRepository(
        db,
      ).add(name: 'R&B-1', start: const RbEnd(p1), end: const RbEnd(p2)),
    );
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
    showClearMapSheet(ctx);
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Temizle (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temizle (1)'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Harita temizlendi.'), findsOneWidget);
    // Düğmeli şerit Flutter'da varsayılan kalıcı; bizde süre dolunca kapanır.
    await tester.pump(ClearMapPanel.undoWindow);
    await tester.pumpAndSettle();
    expect(find.text('Harita temizlendi.'), findsNothing);
    expect(ClearMapPanel.undoWindow, const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
