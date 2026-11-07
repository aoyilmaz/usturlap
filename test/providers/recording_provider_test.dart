import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/position/stub_position_source.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/track.dart';
import 'package:kerteriz/domain/ports/position_source.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/track_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
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

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

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
    expect(names, [
      endsWith('İZ-1'),
      endsWith('İZ-2'),
      endsWith('İZ-3'),
    ]);
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
}
