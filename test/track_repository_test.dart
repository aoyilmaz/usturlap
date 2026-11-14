import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/track_repository.dart';

void main() {
  late AppDatabase db;
  late TrackRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TrackRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('başlat → nokta ekle → nokta sayısı/listesi doğru', () async {
    final id = await repo.startTrack('İZ-1');
    await repo.addPoint(id, const LatLng(39.0, 32.0), altitude: 900);
    await repo.addPoint(id, const LatLng(39.001, 32.001), altitude: 905);

    final pts = await repo.pointsOf(id);
    expect(pts.length, 2);
    expect(pts.first.altitude, 900);

    final tracks = await repo.watchTracks().first;
    expect(tracks.length, 1);
    expect(tracks.first.pointCount, 2);
    expect(tracks.first.isRecording, true); // henüz bitmedi
  });

  test('endTrack endedAt ayarlar (isRecording false)', () async {
    final id = await repo.startTrack('İZ-1');
    await repo.endTrack(id);
    final tracks = await repo.watchTracks().first;
    expect(tracks.first.isRecording, false);
    expect(tracks.first.endedAt, isNotNull);
  });

  test('deleteTrack izi ve noktalarını (cascade) siler', () async {
    final id = await repo.startTrack('İZ-1');
    await repo.addPoint(id, const LatLng(39.0, 32.0));
    await repo.deleteTrack(id);

    expect((await repo.watchTracks().first), isEmpty);
    expect((await repo.pointsOf(id)), isEmpty);
  });
}
