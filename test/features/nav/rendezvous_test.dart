import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/features/nav/nav_banner.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/nav_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E7: buluşma noktası — hedef saate göre gereken hız.
void main() {
  final now = DateTime(2026, 11, 8, 14, 0);

  group('rendezvousLine', () {
    test('gereken hız; duruyorsam erken / geç yok', () {
      final r = rendezvousLine(
        meters: 3000,
        arriveBy: now.add(const Duration(minutes: 45)),
        now: now,
      );
      // 3 km / 0,75 sa = 4 km/h
      expect(r.text, 'Buluşma 14:45 · gereken 4.0 km/h');
      expect(r.late, isFalse);
    });

    test('şimdiki hızla erken / geç / zamanında', () {
      final at = now.add(const Duration(minutes: 30));
      // 1,5 m/s ile 3 km = 33 dk 20 sn → 3 dk geç
      final late = rendezvousLine(
        meters: 3000,
        arriveBy: at,
        now: now,
        speedMps: 1.5,
      );
      expect(late.text, endsWith('3 dk geç'));
      expect(late.late, isTrue);
      // 2 m/s ile 25 dk → 5 dk erken
      final early = rendezvousLine(
        meters: 3000,
        arriveBy: at,
        now: now,
        speedMps: 2,
      );
      expect(early.text, endsWith('5 dk erken'));
      expect(early.late, isFalse);
      // 3000 / 1,667 ≈ 30 dk → zamanında
      final onTime = rendezvousLine(
        meters: 3000,
        arriveBy: at,
        now: now,
        speedMps: 1.6667,
      );
      expect(onTime.text, endsWith('zamanında'));
    });

    test('saat geçtiyse söyler', () {
      final r = rendezvousLine(
        meters: 100,
        arriveBy: now.subtract(const Duration(minutes: 1)),
        now: now,
      );
      expect(r.text, 'Buluşma 13:59 · saat geçti');
      expect(r.late, isTrue);
    });
  });

  test('hedef aynıysa saat korunur, yeni hedefte sıfırlanır', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(navTargetProvider.notifier);
    n.set(const LatLng(1, 1), 'OP-1');
    n.setArriveBy(now);
    n.set(const LatLng(1.1, 1), 'OP-1'); // nokta taşındı
    expect(c.read(navTargetProvider)!.arriveBy, now);
    n.set(const LatLng(2, 2), 'KN-1');
    expect(c.read(navTargetProvider)!.arriveBy, isNull);
  });

  testWidgets('şeritte buluşma satırı ve saat düğmesi', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const banner = NavBanner();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(
            Contact(
              callsign: 'KURT-1',
              position: const LatLng(37.0, 37.0),
              timestamp: DateTime.utc(2026, 11, 8),
              isSelf: true,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: banner)),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byWidget(banner)));
    c.read(navTargetProvider.notifier).set(const LatLng(37.03, 37.0), 'OP-1');
    await tester.pump();
    expect(find.byTooltip('Buluşma saati'), findsOneWidget);
    expect(find.textContaining('Buluşma'), findsNothing);

    c
        .read(navTargetProvider.notifier)
        .setArriveBy(DateTime.now().add(const Duration(hours: 1)));
    await tester.pump();
    expect(find.textContaining('gereken'), findsOneWidget);

    // Kaldır.
    await tester.tap(find.byTooltip('Buluşma saati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    expect(c.read(navTargetProvider)!.arriveBy, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
