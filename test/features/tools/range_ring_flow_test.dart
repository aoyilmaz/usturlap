import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/range_ring_repository.dart';
import 'package:kerteriz/data/db/waypoint_repository.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/domain/models/range_ring.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/features/tools/range_ring_panel.dart';
import 'package:kerteriz/features/tools/tool_banner.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/tool_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E2: menzil halkası aracı → kalıcı halka grubu; detay paneli.
void main() {
  late AppDatabase db;
  const enemy = LatLng(37.0, 37.0);
  const edge = LatLng(37.0045, 37.0); // ≈ 500 m kuzey
  const me = LatLng(37.0063, 37.0); // ≈ 700 m kuzey

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<List<RangeRing>> ringsWhen(
    WidgetTester tester,
    bool Function(List<RangeRing>) done,
  ) async {
    var rings = const <RangeRing>[];
    for (var i = 0; i < 20; i++) {
      rings = (await tester.runAsync(
        () => RangeRingRepository(db).watchAll().first,
      ))!;
      if (done(rings)) break;
      await settle(tester);
    }
    return rings;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
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
              position: me,
              timestamp: DateTime.utc(2026, 11, 8),
              isSelf: true,
            ),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  testWidgets('düşman noktası merkezli halka: kırmızı, bağlı, R-2R-3R', (
    tester,
  ) async {
    // Kayıt, akış dinlenmeden önce (drift test kilidi).
    await tester.runAsync(
      () => WaypointRepository(db).add(
        name: 'DÜŞMAN-1',
        position: enemy,
        uid: 'd1',
        affiliation: Affiliation.hostile,
      ),
    );
    const banner = ToolBanner();
    final c = await pump(tester, banner);
    // Noktaların akışı dinlensin (kaydederken düşman mı diye bakılır).
    c.listen(waypointsProvider, (_, _) {});
    await settle(tester);
    final n = c.read(toolProvider.notifier);
    n.setMode(ToolMode.rangeRings);
    n.addPoint(enemy, ref: RbEnd.waypointRef('d1'));
    n.addPoint(edge);
    await tester.pump();

    await tester.tap(find.byTooltip('Halkayı kaydet'));
    final rings = await ringsWhen(tester, (r) => r.isNotEmpty);
    expect(rings, hasLength(1));
    final r = rings.single;
    expect(r.name, 'HALKA-1');
    expect(r.center.waypointUid, 'd1');
    expect(r.colorValue, RangeRing.threatColor);
    expect(r.radii, hasLength(3));
    expect(r.radii[0], closeTo(500, 2));
    expect(r.radii[2], closeTo(3 * r.radii[0], 1e-6));
    expect(c.read(toolProvider).points, isEmpty);
    await dispose(tester);
  });

  testWidgets('detay: konumum hangi halkada; mesafeleri düzenle', (
    tester,
  ) async {
    final id = (await tester.runAsync(
      () => RangeRingRepository(db).add(
        name: 'HAVAN',
        center: const RbEnd(enemy),
        radii: const [500, 1000, 1500],
        colorValue: RangeRing.threatColor,
      ),
    ))!;
    await pump(tester, RangeRingPanel(ringId: id, onCenter: (_) {}));
    for (var i = 0; i < 20 && find.text('HAVAN').evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.text('500 m · 1.00 km · 1.50 km'), findsOneWidget);
    expect(find.textContaining('2. halkanın içinde (1.00 km)'), findsOneWidget);

    await tester.tap(find.text('Mesafeler'));
    await tester.pumpAndSettle();
    expect(find.text('500 1000 1500'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.textContaining('1 ile 6 arası mesafe'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '300 0,6km');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    final rings = await ringsWhen(tester, (r) => r.single.radii.length == 2);
    expect(rings.single.radii, [300, 600]);
    for (
      var i = 0;
      i < 20 && find.textContaining('dışında').evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    expect(find.textContaining('bütün halkaların dışında'), findsOneWidget);
    await dispose(tester);
  });
}
