import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/range_line_repository.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/features/tools/range_line_panel.dart';
import 'package:kerteriz/features/tools/tool_banner.dart';
import 'package:kerteriz/providers/elevation_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/range_line_providers.dart';
import 'package:kerteriz/providers/tool_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E1: iki noktalı ölçüm → kalıcı R&B çizgisi; detay paneli.
void main() {
  late AppDatabase db;
  const me = LatLng(37.0, 37.0);
  const hill = LatLng(37.01, 37.0); // ≈ 1,11 km kuzey

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Contact self(LatLng p) => Contact(
    callsign: 'KURT-1',
    position: p,
    timestamp: DateTime.utc(2026, 11, 8),
    isSelf: true,
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 20 && !done(); i++) {
      await settle(tester);
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    LatLng selfAt = me,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(self(selfAt)),
          // Arazi: kendi konumum 800 m, tepe 900 m.
          terrainElevationProvider.overrideWith(
            (ref, p) async => p == hill ? 900 : 800,
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  testWidgets('iki noktalı ölçüm kaydedilince bağlı R&B çizgisi olur', (
    tester,
  ) async {
    const banner = ToolBanner();
    final c = await pump(tester, banner);
    final n = c.read(toolProvider.notifier);
    n.setMode(ToolMode.distance);
    n.addPoint(me, ref: RbEnd.selfRef);
    await tester.pump();
    // Tek noktayla kaydedilemez.
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.bookmark_add_outlined),
          )
          .onPressed,
      isNull,
    );
    n.addPoint(hill);
    await tester.pump();
    expect(find.byTooltip('R&B çizgisi olarak kaydet'), findsOneWidget);

    await tester.tap(find.byTooltip('R&B çizgisi olarak kaydet'));
    final repo = RangeLineRepository(db);
    List<RangeLine> saved = const [];
    await pumpUntil(tester, () => saved.isNotEmpty);
    for (var i = 0; i < 20 && saved.isEmpty; i++) {
      saved = (await tester.runAsync(() => repo.watchAll().first))!;
      await settle(tester);
    }
    expect(saved, hasLength(1));
    final l = saved.single;
    expect(l.name, 'R&B-1');
    expect(l.start.isSelf, isTrue);
    expect(l.end.ref, isNull);
    expect(l.end.point, hill);
    // Ölçüm temizlendi, araç açık; kullanıcıya bağlı olduğu söylendi.
    expect(c.read(toolProvider).points, isEmpty);
    expect(c.read(toolProvider).mode, ToolMode.distance);
    await pumpUntil(
      tester,
      () => find.textContaining('R&B-1').evaluate().isNotEmpty,
    );
    expect(find.textContaining('1 ucu nesneye bağlı'), findsOneWidget);

    // Üç noktalı yol eskisi gibi çizim olarak kaydedilir.
    n.addPoint(me);
    n.addPoint(hill);
    n.addPoint(const LatLng(37.02, 37.0));
    await tester.pump();
    expect(find.byTooltip('Çizimi kaydet'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('detay: canlı uç, mesafe, kerteriz ve eğim; sil', (tester) async {
    final id = (await tester.runAsync(
      () => RangeLineRepository(db).add(
        name: 'R&B-1',
        start: const RbEnd(LatLng(36.9, 36.9), RbEnd.selfRef),
        end: const RbEnd(hill),
      ),
    ))!;
    final panel = RangeLinePanel(lineId: id, onCenter: (_) {});
    // Uç kurulduğu yerde değil, kendi konumumda çözülür.
    final c = await pump(tester, panel);
    await pumpUntil(
      tester,
      () => find.textContaining('Eğim: ↗').evaluate().isNotEmpty,
    );
    expect(find.text('Kendi konumum (canlı)'), findsOneWidget);
    expect(find.text('1.11 km'), findsOneWidget);
    expect(find.text('800 m → 900 m'), findsOneWidget);
    // atan(100 / 1112) ≈ 5.1°
    expect(find.text('Eğim: ↗ 5.1° (+100 m)'), findsOneWidget);
    final r = c.read(resolvedRangeLinesProvider).single;
    expect(r.from, me);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(find.text('R&B-1 silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pump();
    List<RangeLine>? left;
    for (var i = 0; i < 20 && (left == null || left.isNotEmpty); i++) {
      left = await tester.runAsync(
        () => RangeLineRepository(db).watchAll().first,
      );
      await settle(tester);
    }
    expect(left, isEmpty);
    await dispose(tester);
  });
}
