import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/features/tools/freehand_layer.dart';
import 'package:usturlap/features/tools/range_tools_bar.dart';
import 'package:usturlap/providers/tool_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// G1: çizim araçları çubuğu, kaydetme, serbest çizim katmanı.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  testWidgets('dikdörtgen çizilip kalın, kesikli kaydedilir', (tester) async {
    final bar = RangeToolsBar.drawing(onClose: () {});
    final c = await pump(
      tester,
      Align(alignment: Alignment.topLeft, child: bar),
    );
    for (final l in [
      'Çizgi',
      'Alan',
      'Daire',
      'Dikdörtgen',
      'Serbest çizim',
      'Çizim araçlarını kapat',
    ]) {
      expect(find.bySemanticsLabel(l), findsOneWidget, reason: l);
    }
    expect(find.text('Bir çizim aracı seçin'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Dikdörtgen'));
    await tester.pump();
    const a = LatLng(37.0, 37.0);
    final b = GeoMath.destination(GeoMath.destination(a, 1000, 0), 500, 90);
    c.read(toolProvider.notifier)
      ..addPoint(a)
      ..addPoint(b);
    await tester.pump();
    expect(find.textContaining('Dikdörtgen: 500 m × 1.00 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Çizimi kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Dikdörtgen kaydet'), findsOneWidget);
    expect(find.text('DİKDÖRTGEN-1'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.tap(find.text('Kesikli çizgi'));
    await tester.pump();
    await tester.tap(find.text('25 m'));
    await tester.pump();
    await tester.ensureVisible(find.text('Çıkışta'));
    await tester.tap(find.text('Çıkışta'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    final saved = (await tester.runAsync(
      () => MapGraphicRepository(db).watchAll().first,
    ))!;
    final g = saved.single;
    expect(g.type, GraphicType.rectangle);
    expect(g.points, hasLength(4));
    expect(g.strokeWidth, 5);
    expect(g.dashed, isTrue);
    expect(g.height, 25);
    expect(g.geofence, GeofenceTrigger.exit);
    expect(c.read(toolProvider).points, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('serbest çizim katmanı: sürükleme sadeleşip verilir', (
    tester,
  ) async {
    List<Offset>? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FreehandLayer(
            color: Colors.amber,
            onDone: (pts) async => got = pts,
          ),
        ),
      ),
    );
    // Düz sürükleme → iki uç; L biçimi → üç nokta.
    final g = await tester.startGesture(const Offset(50, 300));
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(Offset(50.0 + i * 10, 300));
    }
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(Offset(250, 300.0 + i * 10));
    }
    await g.up();
    await tester.pump();
    expect(got, isNotNull);
    expect(got!.length, 3);
    expect(got!.first, const Offset(50, 300));
    expect(got!.last, const Offset(250, 500));
  });
}
