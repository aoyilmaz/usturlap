import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/position/stub_position_source.dart';
import 'package:kerteriz/providers/field_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/nav_providers.dart';
import 'package:kerteriz/providers/track_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

/// Saha konforu: ekranı açık tutma, iz kaydı otomatik durma.
void main() {
  late AppDatabase db;
  late ProviderContainer c;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        positionSourceProvider.overrideWithValue(StubPositionSource()),
        gpsSelfContactProvider.overrideWithValue(null),
        selfContactProvider.overrideWithValue(null),
      ],
    );
    c.listen(wakeWantedProvider, (_, _) {});
    c.listen(recordingProvider, (_, _) {});
    c.listen(trackAutoStopProvider, (_, _) {});
    await _settle();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test('ekranı açık tut: görevde yalnız kayıt / rota / hedef varken', () async {
    expect(c.read(keepScreenOnProvider), KeepScreenOn.mission);
    expect(c.read(wakeWantedProvider), isFalse);
    c.read(navTargetProvider.notifier).set(const LatLng(39, 32), 'HEDEF');
    expect(c.read(wakeWantedProvider), isTrue);
    c.read(navTargetProvider.notifier).clear();
    expect(c.read(wakeWantedProvider), isFalse);
    c.read(keepScreenOnProvider.notifier).set(KeepScreenOn.always);
    expect(c.read(wakeWantedProvider), isTrue);
    c.read(keepScreenOnProvider.notifier).set(KeepScreenOn.off);
    await c.read(recordingProvider.notifier).start();
    expect(c.read(wakeWantedProvider), isFalse);
    await c.read(recordingProvider.notifier).stop();
    await _settle();
  });

  test('iz kaydı süresi dolunca kendiliğinden durur', () async {
    c.read(trackAutoStopProvider.notifier).set(60);
    final rec = c.read(recordingProvider.notifier);
    await rec.start();
    final s = c.read(recordingProvider);
    expect(s.isRecording, isTrue);
    expect(s.stopAt, isNotNull);
    expect(s.stopAt!.difference(DateTime.now()).inMinutes, closeTo(60, 1));
    // Süre dolmadan durmaz.
    expect(rec.checkAutoStop(DateTime.now()), isFalse);
    expect(
      rec.checkAutoStop(s.stopAt!.add(const Duration(seconds: 1))),
      isTrue,
    );
    await _settle();
    final after = c.read(recordingProvider);
    expect(after.isRecording, isFalse);
    expect(after.autoStopped, isTrue);
    // Elle durdurmada autoStopped yok; süre kapalıyken stopAt yok.
    c.read(trackAutoStopProvider.notifier).set(0);
    await rec.start();
    expect(c.read(recordingProvider).stopAt, isNull);
    await rec.stop();
    expect(c.read(recordingProvider).autoStopped, isFalse);
    await _settle();
  });
}
