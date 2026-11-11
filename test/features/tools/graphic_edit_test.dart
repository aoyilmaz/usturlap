import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/map_graphic_repository.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/usecases/shape_edit.dart';
import 'package:kerteriz/features/tools/graphic_list_sheet.dart';
import 'package:kerteriz/features/tools/shape_edit_layer.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// Kayıtlı çizimi düzenleme: ayarlar penceresi ve şekil düzenleme çubuğu.
void main() {
  const square = [
    LatLng(39, 32),
    LatLng(39, 33),
    LatLng(40, 33),
    LatLng(40, 32),
  ];

  testWidgets('listeden dokun → dolu pencere; kaydedince şekil aynı kalır', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(
      () => MapGraphicRepository(db).add(
        name: 'ALAN-1',
        type: GraphicType.area,
        points: square,
        colorValue: 0xFF123456, // paletin dışında (ör. içe aktarılmış)
        strokeWidth: 2.5,
        height: 25,
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
    }

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (_, r, _) => Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => showGraphicListSheet(ctx, r),
                  child: const Text('Çizimler'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Çizimler'));
    await settle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALAN-1'));
    await tester.pumpAndSettle();
    expect(find.text('ALAN-1 düzenle'), findsOneWidget);
    // Mevcut değerler seçili gelir (paletin dışındakiler de).
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2.5'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '25 m'))
          .selected,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'HEDEF BÖLGE');
    await tester.tap(find.text('Kesikli çizgi'));
    await tester.pump();
    await tester.ensureVisible(find.text('Girişte'));
    await tester.tap(find.text('Girişte'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await settle();
    final g = (await tester.runAsync(
      () => MapGraphicRepository(db).watchAll().first,
    ))!.single;
    expect(g.name, 'HEDEF BÖLGE');
    expect(g.dashed, isTrue);
    expect(g.geofence, GeofenceTrigger.entry);
    expect(g.colorValue, 0xFF123456);
    expect(g.strokeWidth, 2.5);
    expect(g.height, 25);
    expect(g.points, square);
    await tester.pumpAndSettle();
    expect(find.text('HEDEF BÖLGE'), findsOneWidget);
    expect(find.text('HEDEF BÖLGE düzenle'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('şekil düzenleme çubuğu: ipucu ve düğmeler', (tester) async {
    final g = MapGraphic(
      id: 1,
      uid: 'a',
      name: 'ALAN-1',
      type: GraphicType.area,
      points: square,
      colorValue: 0xFFFF0000,
      createdAt: DateTime.utc(2026, 11, 11),
    );
    var state = ShapeEditState(g);
    final calls = <String>[];
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShapeEditBar(
            state: state,
            onUndo: () => calls.add('undo'),
            onRemove: () => calls.add('remove'),
            onCancel: () => calls.add('cancel'),
            onSave: () => calls.add('save'),
          ),
        ),
      ),
    );
    await pump();
    expect(
      find.text('ALAN-1: köşeye, + ya da ortadakine dokun'),
      findsOneWidget,
    );
    IconButton btn(String tip) => tester.widget(
      find.widgetWithIcon(IconButton, switch (tip) {
        'undo' => Icons.undo,
        _ => Icons.remove_circle_outline,
      }),
    );
    expect(btn('undo').onPressed, isNull);
    expect(btn('remove').onPressed, isNull);

    state = state.select(2);
    await pump();
    expect(find.text('ALAN-1: köşe 3 — yeni yerine dokun'), findsOneWidget);
    expect(btn('remove').onPressed, isNotNull);
    state = state.moveSelectedTo(const LatLng(40.5, 33.5));
    await pump();
    expect(btn('undo').onPressed, isNotNull);
    await tester.tap(find.byTooltip('Geri al'));
    await tester.tap(find.byTooltip('Şekli kaydet'));
    await tester.tap(find.byTooltip('Şekil düzenlemeyi iptal et'));
    expect(calls, ['undo', 'save', 'cancel']);

    state = state.select(ShapeEditState.moveAll);
    await pump();
    expect(find.text('ALAN-1: yeni merkezine dokun'), findsOneWidget);
  });

  test('tutamaçlar: köşeler, kenar ortaları, bütün şekil', () {
    final g = MapGraphic(
      id: 1,
      uid: 'a',
      name: 'ALAN-1',
      type: GraphicType.area,
      points: square,
      colorValue: 0xFFFF0000,
      createdAt: DateTime.utc(2026, 11, 11),
    );
    final taps = <String>[];
    final handles = shapeEditHandles(
      ShapeEditState(g).select(1),
      onVertex: (i) => taps.add('v$i'),
      onMidpoint: (i) => taps.add('m$i'),
      onMoveAll: () => taps.add('all'),
    );
    // 4 kenar ortası + 4 köşe + bütün şekil.
    expect(handles, hasLength(9));
    expect(handles.where((h) => h.imageKey == 'edit:v:sel'), hasLength(1));
    for (final h in handles) {
      h.onTap!();
    }
    expect(taps, ['m0', 'm1', 'm2', 'm3', 'v0', 'v1', 'v2', 'v3', 'all']);
    // Daire: merkez + kenar, ayrı "bütün şekil" tutamacı yok.
    final circle = shapeEditHandles(
      ShapeEditState(
        MapGraphic(
          uid: 'c',
          name: 'DAİRE-1',
          type: GraphicType.circle,
          points: const [LatLng(39, 32), LatLng(39.01, 32)],
          colorValue: 0xFFFF0000,
          createdAt: DateTime.utc(2026, 11, 11),
        ),
      ),
      onVertex: (_) {},
      onMidpoint: (_) {},
      onMoveAll: () {},
    );
    expect(circle.map((h) => h.imageKey), ['edit:c', 'edit:v']);
  });
}
