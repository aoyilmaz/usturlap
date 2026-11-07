import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/offline/offline_frame_panel.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';
import 'package:kerteriz/features/map/engine/map_types.dart';
import 'package:kerteriz/features/shell/atak_toolbar.dart';
import 'package:kerteriz/features/shell/map_controls.dart';
import 'package:kerteriz/features/shell/tools_grid_sheet.dart';
import 'package:kerteriz/features/shell/toolbar_tools.dart';
import 'package:latlong2/latlong.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

void main() {
  group('ATAK araç çubuğu', () {
    late Map<String, int> calls;
    void c(String k) => calls[k] = (calls[k] ?? 0) + 1;

    Widget bar(List<(IconData, String)> tools, {bool withEdit = true}) {
      calls = {};
      return _wrap(
        AtakToolbar(
          onMenu: () => c('menu'),
          onHide: () => c('hide'),
          onEdit: withEdit ? () => c('edit') : null,
          items: [
            for (final (icon, key) in tools)
              ToolbarItem(icon: icon, label: key, onTap: () => c(key)),
          ],
        ),
      );
    }

    const defaults = [
      (Icons.add_location_alt_outlined, 'drop'),
      (Icons.straighten, 'measure'),
      (Icons.travel_explore, 'goto'),
      (Icons.map_outlined, 'maps'),
      (Icons.radio_button_checked, 'record'),
    ];

    testWidgets('her düğme kendi işini çağırır', (tester) async {
      await tester.pumpWidget(bar(defaults));
      for (final (icon, key) in [(Icons.menu, 'menu'), ...defaults]) {
        await tester.tap(find.byIcon(icon));
        expect(calls[key], 1, reason: key);
      }
      // Etiket erişilebilirlik adıdır.
      expect(find.bySemanticsLabel('maps'), findsOneWidget);
    });

    testWidgets('≡ uzun basınca çubuk gizlenir, araca uzun basınca düzenle', (
      tester,
    ) async {
      await tester.pumpWidget(bar(defaults));
      await tester.longPress(find.byIcon(Icons.menu));
      expect(calls['hide'], 1);
      expect(calls['menu'], isNull);
      await tester.longPress(find.byIcon(Icons.map_outlined));
      expect(calls['edit'], 1);
      expect(calls['maps'], isNull);
    });

    testWidgets('araç yoksa yalnız ≡ kalır', (tester) async {
      await tester.pumpWidget(bar(const []));
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('en çok araçla dikey iPhone ekranına sığar', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436); // 375 × 812 (en dar)
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final icons = [
        Icons.add_location_alt_outlined,
        Icons.straighten,
        Icons.travel_explore,
        Icons.map_outlined,
        Icons.radio_button_checked,
        Icons.settings,
      ];
      expect(icons.length, ToolbarTool.maxOnBar);
      await tester.pumpWidget(bar([for (final i in icons) (i, '$i')]));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AtakToolbar)).width,
        lessThanOrEqualTo(375 - 16),
      );
      expect(kToolbarButtonSize, greaterThanOrEqualTo(48));
    });
  });

  group('sol sütun (pusula · ◎ · zoom)', () {
    late Map<String, int> calls;
    late ValueNotifier<MapCameraState> cam;
    Widget controls({VoidCallback? terrain, bool locked = false}) {
      calls = {};
      void c(String k) => calls[k] = (calls[k] ?? 0) + 1;
      cam = ValueNotifier(
        const MapCameraState(center: LatLng(39, 32), zoom: 12),
      );
      return MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MapSideControls(
              camera: cam,
              trackUp: false,
              onToggleOrientation: () => c('orient'),
              rotationLocked: locked,
              onToggleRotationLock: () => c('lock'),
              following: false,
              onRecenter: () => c('recenter'),
              onZoomIn: () => c('in'),
              onZoomOut: () => c('out'),
              onToggleTerrain: terrain,
            ),
          ),
        ),
      );
    }

    testWidgets('zoom ve ◎ düğmeleri', (tester) async {
      await tester.pumpWidget(controls());
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.location_searching));
      expect(calls, {'in': 1, 'out': 1, 'recenter': 1});
    });

    testWidgets('pusula: dokun → yön; uzun bas → kilit + 3B', (tester) async {
      var terrain = 0;
      await tester.pumpWidget(controls(terrain: () => terrain++));
      final compass = find.bySemanticsLabel(RegExp('^Pusula'));
      expect(find.text('3B'), findsNothing);

      await tester.tap(compass);
      expect(calls['orient'], 1);

      await tester.longPress(compass);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.lock_open));
      expect(calls['lock'], 1);
      await tester.tap(find.text('3B'));
      expect(terrain, 1);
    });

    testWidgets('motor 3B desteklemiyorsa 3B düğmesi yok', (tester) async {
      await tester.pumpWidget(controls());
      await tester.longPress(find.bySemanticsLabel(RegExp('^Pusula')));
      await tester.pump();
      expect(find.byIcon(Icons.lock_open), findsOneWidget);
      expect(find.text('3B'), findsNothing);
    });

    testWidgets('harita dönükse pusula açıyı yazar', (tester) async {
      await tester.pumpWidget(controls());
      expect(find.text('45°'), findsNothing);
      cam.value = const MapCameraState(
        center: LatLng(39, 32),
        zoom: 12,
        bearing: 45,
      );
      await tester.pump();
      expect(find.text('45°'), findsOneWidget);
    });
  });

  group('≡ araç ızgarası', () {
    Future<void> open(
      WidgetTester tester,
      List<ToolGridSection> sections,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showToolsGridSheet(context, sections: sections),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('kutuya dokununca ızgara kapanır, araç çalışır', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var settings = 0;
      await open(tester, [
        ToolGridSection('Sistem', [
          ToolGridItem(
            icon: Icons.settings,
            label: 'Ayarlar',
            onTap: () => settings++,
          ),
        ]),
      ]);
      expect(find.text('SİSTEM'), findsOneWidget);
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      expect(settings, 1);
      expect(find.text('Ayarlar'), findsNothing); // ızgara kapandı
    });

    testWidgets('dikeyde en az 3 sütun', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, [
        ToolGridSection('Ölçüm', [
          for (var i = 0; i < 6; i++)
            ToolGridItem(
              icon: Icons.straighten,
              label: 'Araç $i',
              onTap: () {},
            ),
        ]),
      ]);
      final y0 = tester.getCenter(find.text('Araç 0')).dy;
      final y2 = tester.getCenter(find.text('Araç 2')).dy;
      expect(y0, y2); // ilk üçü aynı satırda
    });
  });

  test('yatay: çevrimdışı çerçeve sağ panelin solunda kalır', () {
    const size = Size(844, 390);
    const safe = EdgeInsets.only(left: 47, right: 47, bottom: 21);
    final r = offlineFrameRect(size, safe, rightPanel: 380);
    expect(r.right, lessThanOrEqualTo(844 - 380));
    expect(r.left, greaterThanOrEqualTo(47));
    expect(r.height, greaterThanOrEqualTo(120));
  });

  testWidgets('yatay ekranda menü sağdan yan panel olarak açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context: context,
                  builder: (_) => const Text('PANEL'),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.text('PANEL'));
    final screenW = 2532 / 3;
    // Panel ekranın sağ yarısında; alttan sayfa değil.
    expect(panel.left, greaterThan(screenW / 2));
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('dikey ekranda menü alttan sayfa olarak açılır', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context: context,
                  builder: (_) => const Text('PANEL'),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
