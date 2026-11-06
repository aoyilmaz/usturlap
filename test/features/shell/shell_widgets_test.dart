import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/offline/offline_frame_panel.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';
import 'package:kerteriz/features/shell/map_controls.dart';
import 'package:kerteriz/features/shell/tactical_bottom_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
    );

void main() {
  testWidgets('alt çubuk: 5 sekme doğru işlevi çağırır', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(TacticalBottomBar(
      recording: false,
      toolActive: false,
      navActive: false,
      onCoordinate: () => calls.add('koordinat'),
      onTools: () => calls.add('araclar'),
      onRecord: () => calls.add('iz'),
      onRoute: () => calls.add('rota'),
      onMissions: () => calls.add('gorevler'),
    )));

    for (final label in ['Koordinat', 'Araçlar', 'İz', 'Rota', 'Görevler']) {
      await tester.tap(find.text(label));
    }
    expect(calls, ['koordinat', 'araclar', 'iz', 'rota', 'gorevler']);
  });

  testWidgets('kayıt sürerken orta düğme "Durdur" gösterir', (tester) async {
    await tester.pumpWidget(_wrap(TacticalBottomBar(
      recording: true,
      toolActive: false,
      navActive: false,
      onCoordinate: () {},
      onTools: () {},
      onRecord: () {},
      onRoute: () {},
      onMissions: () {},
    )));
    expect(find.text('Durdur'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);
  });

  testWidgets('kontrol sütunu: 3B yalnızca motor destekliyorsa görünür',
      (tester) async {
    Widget controls({VoidCallback? onTerrain}) => _wrap(MapControlsColumn(
          onSettings: () {},
          onLayers: () {},
          onAdd: () {},
          addLabel: 'ekle',
          onRecenter: () {},
          following: false,
          onOrientation: () {},
          trackUp: false,
          onTerrain: onTerrain,
        ));

    await tester.pumpWidget(controls());
    expect(find.text('3B'), findsNothing);

    var terrain = 0;
    await tester.pumpWidget(controls(onTerrain: () => terrain++));
    await tester.tap(find.text('3B'));
    expect(terrain, 1);
  });

  testWidgets('"+" düğmesi ekleme işlevini çağırır', (tester) async {
    var added = 0;
    await tester.pumpWidget(_wrap(MapControlsColumn(
      onSettings: () {},
      onLayers: () {},
      onAdd: () => added++,
      addLabel: 'İmleçe nokta ekle',
      onRecenter: () {},
      following: true,
      onOrientation: () {},
      trackUp: false,
    )));
    await tester.tap(find.byIcon(Icons.add_location_alt));
    expect(added, 1);
  });

  testWidgets('yatay: alt çubuk sol dikey şeride dönüşür', (tester) async {
    tester.view.physicalSize = const Size(2532, 1170); // iPhone yatay
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          TacticalBottomBar(
            vertical: true,
            recording: false,
            toolActive: false,
            navActive: false,
            onCoordinate: () {},
            onTools: () {},
            onRecord: () {},
            onRoute: () {},
            onMissions: () {},
          ),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
    final bar = tester.getSize(find.byType(TacticalBottomBar));
    expect(bar.width, lessThanOrEqualTo(kSideRailWidth + 1));
    // Sekmeler yukarıdan aşağı sıralı.
    final yK = tester.getCenter(find.text('Koordinat')).dy;
    final yG = tester.getCenter(find.text('Görevler')).dy;
    expect(yK, lessThan(yG));
  });

  test('yatay: çevrimdışı çerçeve sağ panelin solunda kalır', () {
    const size = Size(844, 390);
    const safe = EdgeInsets.only(left: 47, right: 47, bottom: 21);
    final r = offlineFrameRect(size, safe, rightPanel: 380);
    expect(r.right, lessThanOrEqualTo(844 - 380));
    expect(r.left, greaterThanOrEqualTo(47));
    expect(r.height, greaterThanOrEqualTo(120));
  });

  testWidgets('yatay ekranda menü sağdan yan panel olarak açılır',
      (tester) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
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
    ));
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
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
