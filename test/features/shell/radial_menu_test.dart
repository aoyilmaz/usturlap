import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/shell/radial_menu.dart';

/// D3a: ATAK radyal menüsü (kılavuz s.11).
void main() {
  late List<String> log;
  late int mapTaps;

  const labels = [
    'Detay',
    'Git',
    'R&B',
    'Halka',
    'Taşı',
    'Paylaş',
    'Sil',
    'Ortala',
  ];

  Future<void> pump(WidgetTester tester, Offset center) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    log = [];
    mapTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            // Haritanın yerine: dokunuş sayar.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => mapTaps++,
              ),
            ),
            Positioned.fill(
              child: RadialMenu(
                center: center,
                title: 'OP-1',
                actions: [
                  for (final l in labels)
                    RadialAction(
                      icon: Icons.circle,
                      label: l,
                      onTap: () => log.add(l),
                    ),
                ],
                onDismiss: () => log.add('kapat'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect button(WidgetTester tester, String label) =>
      tester.getRect(find.bySemanticsLabel(label));

  testWidgets('düğmeler halka üzerinde, üstten saat yönünde, ≥ 48 pt', (
    tester,
  ) async {
    const c = Offset(195, 420);
    await pump(tester, c);
    for (final l in labels) {
      final r = button(tester, l);
      expect(r.width, greaterThanOrEqualTo(48));
      expect((r.center - c).distance, closeTo(RadialMenu.radius, 0.5));
    }
    // İlk düğme tam üstte, ikincisi sağ üstte.
    expect(button(tester, 'Detay').center.dx, closeTo(c.dx, 0.5));
    expect(button(tester, 'Detay').center.dy, lessThan(c.dy));
    expect(button(tester, 'Git').center.dx, greaterThan(c.dx));
    expect(find.text('OP-1'), findsOneWidget);
  });

  testWidgets('eyleme dokununca önce menü kapanır, sonra eylem çalışır', (
    tester,
  ) async {
    await pump(tester, const Offset(195, 420));
    await tester.tap(find.bySemanticsLabel('Git'));
    expect(log, ['kapat', 'Git']);
    expect(mapTaps, 0);
  });

  testWidgets('dışarıya dokunuş menüyü kapatır ve haritaya geçer', (
    tester,
  ) async {
    await pump(tester, const Offset(195, 420));
    await tester.tapAt(const Offset(20, 800));
    expect(log, ['kapat']);
    expect(mapTaps, 1);
  });

  testWidgets('ortadaki ada dokununca kapanır', (tester) async {
    await pump(tester, const Offset(195, 420));
    await tester.tap(find.text('OP-1'));
    expect(log, ['kapat']);
  });

  testWidgets('ekran kenarındaki nesnede halka ekranın içinde kalır', (
    tester,
  ) async {
    await pump(tester, const Offset(5, 830));
    final screen = Offset.zero & const Size(390, 844);
    for (final l in labels) {
      final r = button(tester, l);
      expect(screen.contains(r.topLeft), isTrue, reason: '$l $r');
      expect(screen.contains(r.bottomRight), isTrue, reason: '$l $r');
    }
  });

  test('merkez kaydırma: sığmayan eksen ortalanır', () {
    final c = RadialMenu.clampCenter(
      const Offset(0, 0),
      const Size(200, 1000),
      EdgeInsets.zero,
    );
    expect(c.dx, 100); // 200 < 2 × extent
    expect(c.dy, RadialMenu.extent + 4);
  });
}
