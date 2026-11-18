import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/track_repository.dart';
import 'package:usturlap/data/db/settings_repository.dart';
import 'package:usturlap/data/position/stub_position_source.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/domain/models/track.dart';
import 'package:usturlap/domain/ports/position_source.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/track_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// Elle konum yayınlanan sahte GPS.
class _FakeSource implements PositionSource {
  final _c = StreamController<List<Contact>>.broadcast();

  void emit(double lat, double lon) => _c.add([
    Contact(
      callsign: 'T',
      position: LatLng(lat, lon),
      accuracyMeters: 5,
      timestamp: DateTime.now(),
      isSelf: true,
    ),
  ]);

  @override
  Stream<List<Contact>> get contacts => _c.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}
  @override
  Future<void> stop() async {}
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('her yeni iz sıradaki numarayı alır (İZ-1, İZ-2, İZ-3)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        positionSourceProvider.overrideWithValue(StubPositionSource()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // Gerçek uygulamadaki gibi: iz listesini kimse dinlemiyor.
    final rec = container.read(recordingProvider.notifier);
    for (var i = 0; i < 3; i++) {
      await rec.start();
      await rec.stop();
    }

    final names = (await db.select(db.tracks).get()).map((t) => t.name);
    expect(names, [endsWith('İZ-1'), endsWith('İZ-2'), endsWith('İZ-3')]);
  });

  test('kayıt sırasında canlı iz noktaları haritaya gelir', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gps = _FakeSource();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        positionSourceProvider.overrideWithValue(gps),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // Harita ekranının dinlediği sağlayıcılar.
    container.listen(selfContactProvider, (_, _) {});
    container.listen(recordingProvider, (_, _) {});
    final live = container.listen<AsyncValue<List<TrackPoint>>>(
      currentTrackPointsProvider,
      (_, _) {},
    );

    gps.emit(39.900, 32.800);
    await _settle();
    await container.read(recordingProvider.notifier).start();
    await _settle();
    for (var i = 1; i <= 5; i++) {
      gps.emit(39.900 + i * 0.001, 32.800); // ~111 m adım
      await _settle();
    }

    final saved = await db.select(db.trackPoints).get();
    expect(saved.length, 6, reason: 'veritabanına yazılan');
    expect(live.read().value?.length, 6, reason: 'haritaya giden canlı iz');
  });

  group('kayıt güvenliği (denetim 2026-11-16)', () {
    late AppDatabase db;
    late _FakeSource gps;
    late ProviderContainer c;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      gps = _FakeSource();
      c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          positionSourceProvider.overrideWithValue(gps),
        ],
      );
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('kayıtlı "kendiliğinden dur" ayarı açılıştan sonraki ilk kayıtta '
        'uygulanır', () async {
      await SettingsRepository(db).set('track_auto_stop_min', '120');
      // Ayarlar paneli açılmadı; ayarı kimse izlemiyor.
      await c.read(recordingProvider.notifier).start();
      final stopAt = c.read(recordingProvider).stopAt;
      expect(stopAt, isNotNull);
      expect(
        stopAt!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(118, 120),
      );
    });

    test('kayda hızlı çift dokunuş tek iz açar', () async {
      final rec = c.read(recordingProvider.notifier);
      await Future.wait([rec.start(), rec.start()]);
      expect((await db.select(db.tracks).get()).length, 1);
      expect(c.read(recordingProvider).isRecording, isTrue);
    });

    test(
      'kaydedilen iz yok olursa kayıt durur (nokta boşa yazılmaz)',
      () async {
        final sub = c.listen(recordingProvider, (_, _) {});
        addTearDown(sub.close);
        await c.read(recordingProvider.notifier).start();
        final id = c.read(recordingProvider).trackId!;
        gps.emit(39.0, 32.0);
        await _settle();
        await c.read(trackRepositoryProvider).deleteTrack(id);
        gps.emit(39.001, 32.0);
        await _settle();
        expect(c.read(recordingProvider).isRecording, isFalse);
        expect(await db.select(db.trackPoints).get(), isEmpty);
      },
    );

    test('önceki oturumdan yarım kalan iz açılışta kapatılır', () async {
      final repo = TrackRepository(db);
      final t0 = DateTime(2026, 11, 10, 9);
      final old = await repo.startTrack('YARIM');
      await repo.addPoint(old, const LatLng(39, 32), timestamp: t0);
      await repo.addPoint(
        old,
        const LatLng(39.01, 32),
        timestamp: t0.add(const Duration(minutes: 40)),
      );
      final empty = await repo.startTrack('BOŞ');

      // Uygulama yeniden açıldı: kayıt sağlayıcısı kurulur.
      c.read(recordingProvider);
      await _settle();
      final rows = {for (final t in await db.select(db.tracks).get()) t.id: t};
      // Bitiş = son noktanın zamanı (şimdi değil: süre büyümesin).
      expect(rows[old]!.endedAt, t0.add(const Duration(minutes: 40)));
      // Noktasız iz: bitiş = başlangıç.
      expect(rows[empty]!.endedAt, rows[empty]!.startedAt);

      // Yeni kayıt etkilenmez.
      await c.read(recordingProvider.notifier).start();
      final live = c.read(recordingProvider).trackId!;
      final liveRow = await (db.select(
        db.tracks,
      )..where((t) => t.id.equals(live))).getSingle();
      expect(liveRow.endedAt, isNull);
    });
  });
}
