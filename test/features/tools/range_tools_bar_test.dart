import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/settings_repository.dart';
import 'package:usturlap/features/tools/range_tools_bar.dart';
import 'package:usturlap/providers/settings_providers.dart';
import 'package:usturlap/providers/tool_providers.dart';
import 'package:latlong2/latlong.dart';

class _MemSettings implements SettingsRepository {
  @override
  Future<String?> get(String key) async => null;
  @override
  Future<void> set(String key, String value) async {}
}

void main() {
  late ProviderContainer c;
  late int closed;

  Future<void> pump(WidgetTester tester) async {
    closed = 0;
    c = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(_MemSettings())],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: RangeToolsBar(onClose: () => closed++),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('araç yokken ipucu; araca dokun → açılır, tekrar → kapanır', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Bir ölçüm aracı seçin'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Menzil halkası'));
    await tester.pump();
    expect(c.read(toolProvider).mode, ToolMode.rangeRings);
    expect(find.text('Bir ölçüm aracı seçin'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Mesafe / R&B çizgisi'));
    await tester.pump();
    expect(c.read(toolProvider).mode, ToolMode.distance);

    await tester.tap(find.bySemanticsLabel('Mesafe / R&B çizgisi'));
    await tester.pump();
    expect(c.read(toolProvider).mode, ToolMode.none);
  });

  testWidgets('aktif araçta ölçüm şeridi: değer, geri al, gizle', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Mesafe / R&B çizgisi'));
    await tester.pump();
    final n = c.read(toolProvider.notifier);
    n.addPoint(const LatLng(39.0, 32.0));
    n.addPoint(const LatLng(39.01, 32.0));
    await tester.pump();
    expect(find.textContaining('Mesafe: 1.11 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Çizimi gizle'));
    await tester.pump();
    expect(c.read(toolProvider).visible, isFalse);

    await tester.tap(find.byTooltip('Geri al'));
    await tester.pump();
    expect(c.read(toolProvider).points, hasLength(1));
  });

  testWidgets('✕ kapatma işlevini çağırır', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Ölçüm araçlarını kapat'));
    expect(closed, 1);
  });

  testWidgets('dikey iPhone\'da sol sütunun yanına sığar (≤ 316 pt)', (
    tester,
  ) async {
    await pump(tester);
    // 5 araç + ayraç + ✕ çubuğu.
    final bar = tester.getSize(find.byType(Material).at(1));
    expect(bar.width, lessThanOrEqualTo(316));
  });
}
