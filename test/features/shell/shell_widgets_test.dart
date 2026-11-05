import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
