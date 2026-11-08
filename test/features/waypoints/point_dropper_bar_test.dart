import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/features/waypoints/point_dropper_bar.dart';

/// D3d: ATAK Point Dropper paleti.
void main() {
  late List<String> log;

  Future<void> pump(WidgetTester tester, {bool crosshair = false}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    log = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              // Harita ekranındaki gibi: sol sütunun sağında.
              padding: const EdgeInsets.only(left: 66, right: 8),
              child: PointDropperBar(
                selected: Affiliation.hostile,
                nextName: 'DÜŞMAN-3',
                onSelect: (a) => log.add(a.name),
                onClose: () => log.add('kapat'),
                onDropAtCrosshair: crosshair ? () => log.add('imleç') : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('beş tür, seçili olan işaretli; sıradaki ad yazar', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull); // 390 pt'ye sığar
    for (final l in ['Dost', 'Düşman', 'Nötr', 'Bilinmeyen', 'Nokta']) {
      expect(find.bySemanticsLabel(l), findsOneWidget, reason: l);
      expect(
        tester.getSize(find.bySemanticsLabel(l)).width,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Düşman')),
      isSemantics(isSelected: true),
    );
    expect(find.text('Haritaya dokun → DÜŞMAN-3'), findsOneWidget);
    expect(find.text('İmlece bırak'), findsNothing);
  });

  testWidgets('tür seçimi ve kapatma', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Dost'));
    await tester.tap(find.bySemanticsLabel('Nokta'));
    await tester.tap(find.byTooltip('Nokta bırakmayı kapat'));
    expect(log, ['friend', 'waypoint', 'kapat']);
  });

  testWidgets('artı imleç açıksa "İmlece bırak"', (tester) async {
    await pump(tester, crosshair: true);
    await tester.tap(find.text('İmlece bırak'));
    expect(log, ['imleç']);
  });

  test('ad önekleri', () {
    expect(dropPrefix(Affiliation.hostile), 'DÜŞMAN');
    expect(dropPrefix(Affiliation.waypoint), 'NOKTA');
  });
}
