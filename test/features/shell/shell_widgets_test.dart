import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/offline/offline_frame_panel.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';
import 'package:kerteriz/features/map/engine/map_types.dart';
import 'package:kerteriz/features/shell/atak_toolbar.dart';
import 'package:kerteriz/features/shell/map_controls.dart';
import 'package:kerteriz/features/shell/tools_grid_sheet.dart';
import 'package:latlong2/latlong.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

void main() {
  group('ATAK araç çubuğu', () {
    late Map<String, int> calls;
    Widget bar({bool recording = false, bool drop = false}) {
      calls = {};
      void c(String k) => calls[k] = (calls[k] ?? 0) + 1;
      return _wrap(
        AtakToolbar(
          onMenu: () => c('menu'),
          onHide: () => c('hide'),
          onDropPoint: () => c('drop'),
          onMeasure: () => c('measure'),
          onGoTo: () => c('goto'),
          onMaps: () => c('maps'),
          onRecord: () => c('record'),
          recording: recording,
          dropActive: drop,
        ),
      );
    }

    testWidgets('her düğme kendi işini çağırır', (tester) async {
      await tester.pumpWidget(bar());
      for (final (icon, key) in [
        (Icons.menu, 'menu'),
        (Icons.add_location_alt_outlined, 'drop'),
        (Icons.straighten, 'measure'),
        (Icons.travel_explore, 'goto'),
        (Icons.map_outlined, 'maps'),
        (Icons.radio_button_checked, 'record'),
      ]) {
        await tester.tap(find.byIcon(icon));
        expect(calls[key], 1, reason: key);
      }
    });

    testWidgets('≡ uzun basınca çubuk gizlenir', (tester) async {
      await tester.pumpWidget(bar());
      await tester.longPress(find.byIcon(Icons.menu));
      expect(calls['hide'], 1);
      expect(calls['menu'], isNull);
    });

    testWidgets('kayıt sürerken düğme "durdur" olur', (tester) async {
      await tester.pumpWidget(bar(recording: true));
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);
      expect(find.bySemanticsLabel('İz kaydını durdur'), findsOneWidget);
    });

    testWidgets('dikey iPhone ekranına sığar, düğmeler ≥ 48 pt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390 × 844
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(bar());
      expect(
        tester.getSize(find.byType(AtakToolbar)).width,
        lessThanOrEqualTo(390 - 16),
      );
      final btn = tester.getSize(find.byIcon(Icons.map_outlined).hitTestable());
      expect(btn.width, greaterThanOrEqualTo(24)); // ikon
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
