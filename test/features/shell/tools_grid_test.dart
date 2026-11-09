import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';
import 'package:kerteriz/features/shell/tools_grid_sheet.dart';

/// D4a: ≡ ızgarasından açılan panel ızgaranın üstüne biner.
void main() {
  testWidgets('panel açan araç: Geri ızgaraya döner; harita aracı ızgarayı '
      'kapatır', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    var mapToolRan = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PanelHost(
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    void openGrid() => showToolsGridSheet(
      ctx,
      sections: [
        ToolGridSection('Araçlar', [
          ToolGridItem(
            icon: Icons.layers,
            label: 'Panel aracı',
            onTap: () => showAdaptiveSheet<void>(
              context: ctx, // haritanın context'i, ATAK'taki gibi
              builder: (_) => const Text('ARAÇ PANELİ'),
            ),
          ),
          ToolGridItem(
            icon: Icons.straighten,
            label: 'Harita aracı',
            onTap: () => mapToolRan++,
          ),
        ]),
      ],
    );

    openGrid();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel aracı'));
    await tester.pumpAndSettle();
    expect(find.text('ARAÇ PANELİ'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('ARAÇ PANELİ'), findsNothing);
    expect(find.text('Panel aracı'), findsOneWidget); // ızgara geri geldi

    await tester.tap(find.text('Harita aracı'));
    await tester.pumpAndSettle();
    expect(mapToolRan, 1);
    expect(find.text('Panel aracı'), findsNothing);
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);

    // ✕ ızgarayla birlikte hepsini kapatır.
    openGrid();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel aracı'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
  });
}
