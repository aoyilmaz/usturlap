import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/features/nav/tactical_compass_page.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/nav_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// Testte yönü değiştirilebilen kendi konumum.
class _Self extends Notifier<Contact?> {
  @override
  Contact? build() => null;
  void heading(double? h) => state = Contact(
    callsign: 'KURT-1',
    position: const LatLng(37.0, 37.0),
    headingDeg: h,
    timestamp: DateTime.utc(2026, 11, 8),
    isSelf: true,
  );
}

final _self = NotifierProvider<_Self, Contact?>(_Self.new);

/// E6: taktik pusula (coğrafi kuzey, derece — varsayılan ayar).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  test('sapma sözü', () {
    expect(deviationText(0), 'DOĞRU');
    expect(deviationText(-2.9), 'DOĞRU');
    expect(deviationText(12.4), 'SAĞA 12°');
    expect(deviationText(-5), 'SOLA 5°');
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const page = TacticalCompassPage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWith((ref) => ref.watch(_self)),
        ],
        child: const MaterialApp(home: page),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byWidget(page)));
  }

  testWidgets('pusula yoksa söyler', (tester) async {
    await pump(tester);
    expect(find.textContaining('Pusula verisi yok'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('kilitle → DOĞRU; dönünce sapma; kerteriz gir', (tester) async {
    final c = await pump(tester);
    c.read(_self.notifier).heading(40);
    await tester.pump();
    expect(find.text('040°'), findsOneWidget);
    expect(find.text('Ters 220°'), findsOneWidget);

    await tester.tap(find.text('Kerterizi kilitle'));
    await tester.pump();
    expect(find.text('DOĞRU'), findsOneWidget);
    expect(find.text('Kilit: 040°'), findsOneWidget);

    c.read(_self.notifier).heading(28);
    await tester.pump();
    expect(find.text('SAĞA 12°'), findsOneWidget);
    c.read(_self.notifier).heading(50);
    await tester.pump();
    expect(find.text('SOLA 10°'), findsOneWidget);

    await tester.tap(find.text('Kerteriz gir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '400');
    await tester.tap(find.text('Kilitle'));
    await tester.pump();
    expect(find.text('0–360'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '90');
    await tester.tap(find.text('Kilitle'));
    await tester.pumpAndSettle();
    expect(find.text('Kilit: 090°'), findsOneWidget);
    expect(find.text('SAĞA 40°'), findsOneWidget);

    await tester.tap(find.text('Kilidi aç'));
    await tester.pump();
    expect(find.text('Kerterizi kilitle'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('Git hedefine kilit: kerteriz konumdan hesaplanır', (
    tester,
  ) async {
    final c = await pump(tester);
    c.read(_self.notifier).heading(0);
    await tester.pump();
    expect(find.textContaining('Hedefe kilitle'), findsNothing);
    c
        .read(navTargetProvider.notifier)
        .set(const LatLng(37.0, 37.01), 'OP-1'); // doğuda
    await tester.pump();
    await tester.tap(find.text('Hedefe kilitle (OP-1)'));
    await tester.pump();
    expect(find.text('Hedef OP-1: 090°'), findsOneWidget);
    expect(find.text('SAĞA 90°'), findsOneWidget);
    await dispose(tester);
  });
}
