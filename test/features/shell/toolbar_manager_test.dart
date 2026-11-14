import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/features/shell/toolbar_manager_sheet.dart';
import 'package:usturlap/features/shell/toolbar_tools.dart';
import 'package:usturlap/providers/settings_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';

/// D2c: Araç çubuğu paneli (ATAK Toolbar Manager).
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ToolbarManager())),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(ToolbarManager)),
    );
  }

  /// Listenin altındaki öğeye dokunmadan önce görünür yap.
  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
  }

  testWidgets('çubuktakiler ve eklenebilirler listelenir', (tester) async {
    await pump(tester);
    for (final t in ToolbarTool.defaults) {
      expect(find.byTooltip('Çıkar: ${t.label}'), findsOneWidget);
    }
    expect(find.byTooltip('Ekle: Ayarlar'), findsOneWidget);
    expect(find.textContaining('Çubukta 5/6 araç'), findsOneWidget);
  });

  testWidgets('çıkar ve ekle çubuğu değiştirir', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byTooltip('Çıkar: Haritalar'));
    await tester.pump();
    expect(c.read(toolbarToolsProvider), isNot(contains(ToolbarTool.maps)));
    expect(find.byTooltip('Ekle: Haritalar'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Ekle: Haritalar'));
    expect(c.read(toolbarToolsProvider).last, ToolbarTool.maps);
  });

  testWidgets('çubuk dolunca ekle düğmeleri kapanır', (tester) async {
    final c = await pump(tester);
    await tapVisible(tester, find.byTooltip('Ekle: Ayarlar'));
    await tester.pump();
    expect(c.read(toolbarToolsProvider), hasLength(ToolbarTool.maxOnBar));
    expect(find.textContaining('Çubuk dolu'), findsOneWidget);
    final add = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.add_circle_outline).first,
        matching: find.byType(IconButton),
      ),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('tutamaktan sürükleyerek sıra değişir', (tester) async {
    final c = await pump(tester);
    final handle = find.byKey(const ValueKey('surukle-dropPoint'));
    final rowHeight = tester
        .getSize(
          find.ancestor(
            of: find.byTooltip('Çıkar: Nokta bırak'),
            matching: find.byType(ListTile),
          ),
        )
        .height;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    // İki satır aşağı.
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, rowHeight * 0.25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final tools = c.read(toolbarToolsProvider);
    expect(tools.first, isNot(ToolbarTool.dropPoint));
    expect(tools, contains(ToolbarTool.dropPoint));
    expect(tools, hasLength(5));
  });

  testWidgets('varsayılana dön', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byTooltip('Çıkar: Nokta bırak'));
    await tester.pump();
    await tapVisible(tester, find.text('Varsayılana dön'));
    expect(c.read(toolbarToolsProvider), ToolbarTool.defaults);
  });
}
