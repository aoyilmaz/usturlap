import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/domain/models/bullseye.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/features/tools/bullseye_panel.dart';
import 'package:kerteriz/providers/bullseye_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E3: Bullseye paneli ve bilgi şeridi.
void main() {
  late AppDatabase db;
  const center = LatLng(37.0, 37.0);
  const me = LatLng(37.01, 37.0); // ≈ 1,11 km kuzey

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

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
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('kur, halka aralığı / sayısı, kaldır', (tester) async {
    final panel = BullseyePanel(mapCenter: () => center, onCenter: (_) {});
    final c = await pump(tester, panel);
    expect(find.text('Harita ortasına kur'), findsOneWidget);
    await tester.tap(find.text('Harita ortasına kur'));
    await tester.pump();
    final b = c.read(bullseyeProvider)!;
    expect(b.center.point, center);
    expect(b.center.ref, isNull);
    expect(find.text('BE 000° / 1.11 km'), findsOneWidget);
    expect(find.text('5 · 5.00 km'), findsOneWidget);

    await tester.tap(find.text('500 m'));
    await tester.pump();
    await tester.tap(find.byTooltip('Halka ekle'));
    await tester.pump();
    expect(c.read(bullseyeProvider)!.ringSpacing, 500);
    expect(c.read(bullseyeProvider)!.ringCount, 6);
    expect(find.text('6 · 3.00 km'), findsOneWidget);

    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(c.read(bullseyeProvider), isNull);
    expect(find.text('Harita ortasına kur'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('bilgi şeridi: konumumun çağrısı; merkez bensem görünmez', (
    tester,
  ) async {
    var taps = 0;
    final banner = BullseyeBanner(onTap: () => taps++);
    final c = await pump(tester, banner);
    expect(find.textContaining('BE'), findsNothing);

    c
        .read(bullseyeProvider.notifier)
        .set(const Bullseye(center: RbEnd(center)));
    await tester.pump();
    expect(find.text('BE 000° / 1.11 km'), findsOneWidget);
    await tester.tap(find.text('BE 000° / 1.11 km'));
    expect(taps, 1);

    c
        .read(bullseyeProvider.notifier)
        .set(const Bullseye(center: RbEnd(center, RbEnd.selfRef)));
    await tester.pump();
    expect(find.textContaining('BE'), findsNothing);
    await dispose(tester);
  });

  test('bullseye kalıcı (yeniden açılışta okunur)', () async {
    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      c.listen(bullseyeProvider, (_, _) {});
      return c;
    }

    final c = open();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c
        .read(bullseyeProvider.notifier)
        .set(
          Bullseye(
            center: RbEnd(center, RbEnd.waypointRef('op1')),
            name: 'OP-1',
            ringSpacing: 2000,
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final again = open();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final b = again.read(bullseyeProvider)!;
    expect(b.name, 'OP-1');
    expect(b.ringSpacing, 2000);
    expect(b.center.waypointUid, 'op1');

    // Kaldırınca da kalıcı.
    again.read(bullseyeProvider.notifier).set(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final third = open();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(third.read(bullseyeProvider), isNull);
  });
}
