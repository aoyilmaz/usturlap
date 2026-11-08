import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/waypoint_repository.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/features/nav/bloodhound_panel.dart';
import 'package:kerteriz/providers/bloodhound_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E4: takip paneli.
void main() {
  late AppDatabase db;
  const me = LatLng(37.0, 37.0);
  const op = LatLng(37.01, 37.0);
  const cp = LatLng(37.0, 37.01);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Noktalar akış dinlenmeden önce (drift test kilidi).
    await tester.runAsync(() async {
      final repo = WaypointRepository(db);
      await repo.add(name: 'OP-1', position: op, uid: 'op1');
      await repo.add(name: 'KN-1', position: cp, uid: 'cp1');
    });
    final panel = BloodhoundPanel(onCenter: (_) {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(
            Contact(
              callsign: 'KURT-1',
              position: me,
              speedMps: 2,
              timestamp: DateTime.utc(2026, 11, 8),
              isSelf: true,
            ),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: panel)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await settle(tester);
    }
    return ProviderScope.containerOf(tester.element(find.byWidget(panel)));
  }

  testWidgets('benden noktaya takip canlı; iki nokta arası eklenir', (
    tester,
  ) async {
    final c = await pump(tester);
    expect(find.textContaining('Henüz takip yok'), findsOneWidget);
    c
        .read(bloodhoundsProvider.notifier)
        .add(
          const RbEnd(me, RbEnd.selfRef),
          RbEnd(op, RbEnd.waypointRef('op1')),
        );
    await tester.pump();
    expect(find.text('Ben → OP-1'), findsOneWidget);
    // 1112 m / 2 m/s ≈ 9 dk (gerçek hız, ~ yok).
    expect(find.textContaining('000° · 1.11 km · 9 dk ('), findsOneWidget);

    // İki nokta arası: KN-1 → OP-1 (hız yok → süre yok).
    final from = find.byType(DropdownButtonFormField<String>).first;
    final to = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(from);
    await tester.tap(from);
    await tester.pumpAndSettle();
    await tester.tap(find.text('KN-1').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(to);
    await tester.tap(to);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OP-1').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Takip ekle').last);
    await tester.tap(find.text('Takip ekle').last);
    await tester.pump();
    expect(find.text('KN-1 → OP-1'), findsOneWidget);
    expect(c.read(resolvedBloodhoundsProvider).last.reading.eta, isNull);

    // Aynısı tekrar eklenmez.
    await tester.tap(find.text('Takip ekle').last);
    await tester.pump();
    expect(find.text('Bu takip zaten açık.'), findsOneWidget);
    expect(c.read(bloodhoundsProvider), hasLength(2));

    await tester.ensureVisible(find.byTooltip('Takibi kaldır: Ben → OP-1'));
    await tester.tap(find.byTooltip('Takibi kaldır: Ben → OP-1'));
    await tester.pump();
    expect(find.text('Ben → OP-1'), findsNothing);
    expect(c.read(bloodhoundsProvider), hasLength(1));
    await dispose(tester);
  });

  testWidgets('ETA eşikleri: artır / azalt, sıra korunur', (tester) async {
    final c = await pump(tester);
    final up = find.byTooltip('Kırmızı eşiğini artır');
    await tester.ensureVisible(up);
    expect(find.text('Sarı ≤ 15 dk'), findsOneWidget);
    expect(find.text('Kırmızı ≤ 5 dk'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.tap(up);
      await tester.pump();
    }
    expect(c.read(etaThresholdsProvider).alarm.inMinutes, 15);
    expect(c.read(etaThresholdsProvider).warn.inMinutes, 16);
    expect(find.text('Sarı ≤ 16 dk'), findsOneWidget);
    await dispose(tester);
  });
}
