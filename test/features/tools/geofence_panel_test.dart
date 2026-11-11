import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/map_graphic_repository.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/features/tools/geofence_panel.dart';
import 'package:kerteriz/features/tools/graphic_list_sheet.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// G3: geofence paneli ve Çizimler listesinden uyarı değiştirme.
void main() {
  late AppDatabase db;
  const square = [
    LatLng(39, 32),
    LatLng(39, 33),
    LatLng(40, 33),
    LatLng(40, 32),
  ];
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = MapGraphicRepository(db);
    await repo.add(
      name: 'ALAN-1',
      type: GraphicType.area,
      points: square,
      colorValue: 0xFFFF0000,
      geofence: GeofenceTrigger.both,
    );
    await repo.add(
      name: 'ALAN-2',
      type: GraphicType.area,
      points: square,
      colorValue: 0xFF00FF00,
    );
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<List<MapGraphic>> saved(WidgetTester tester) async =>
      (await tester.runAsync(() => MapGraphicRepository(db).watchAll().first))!;

  Future<void> pump(
    WidgetTester tester,
    Widget Function(WidgetRef) body,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(
            Contact(
              callsign: 'KURT-1',
              position: const LatLng(39.5, 32.5),
              timestamp: DateTime.utc(2026, 11, 10),
              accuracyMeters: 5,
              isSelf: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: Consumer(builder: (_, r, _) => body(r))),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('panel: uyarılı alan, durum; uyarı kaldırılınca listeden çıkar', (
    tester,
  ) async {
    final centered = <LatLng>[];
    await pump(tester, (_) => GeofencePanel(onCenter: centered.add));
    expect(find.text('Uyarılı alanlar (1)'), findsOneWidget);
    expect(find.text('ALAN-1'), findsOneWidget);
    expect(find.text('ALAN-2'), findsNothing);
    expect(find.text('Giriş ve çıkışta · şu an içeridesin'), findsOneWidget);
    expect(find.text('Henüz uyarı yok.'), findsOneWidget);
    await tester.tap(find.text('ALAN-1'));
    expect(centered, [square.first]);

    await tester.tap(find.byTooltip('Geofence: ALAN-1'));
    await tester.pumpAndSettle();
    expect(find.text('ALAN-1: geofence'), findsOneWidget);
    await tester.tap(find.text('Yok'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await settle(tester);
    expect(find.text('Uyarılı alanlar (0)'), findsOneWidget);
    expect(
      (await saved(tester)).firstWhere((g) => g.name == 'ALAN-1').geofence,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Çizimler listesi: çit düğmesiyle uyarı koyulur', (tester) async {
    await pump(
      tester,
      (r) => Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showGraphicListSheet(ctx, r),
          child: const Text('Çizimler'),
        ),
      ),
    );
    await tester.tap(find.text('Çizimler'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('geofence: giriş ve çıkışta'), findsOneWidget);
    await tester.tap(find.byTooltip('Geofence: ALAN-2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkışta'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await settle(tester);
    expect(
      (await saved(tester)).firstWhere((g) => g.name == 'ALAN-2').geofence,
      GeofenceTrigger.exit,
    );
    expect(find.textContaining('geofence: çıkışta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
