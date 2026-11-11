import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/map_graphic_repository.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:latlong2/latlong.dart';

/// v14 → v15: çizimlerde geofence uyarısı.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v15_'));
  tearDown(() async => dir.delete(recursive: true));

  test('v14 → v15: eski çizimler uyarısız; uyarı yazılıp okunur', () async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v14.sqlite');
    final up = AppDatabase.forTesting(NativeDatabase(file));
    await MapGraphicRepository(up).add(
      name: 'ESKİ',
      type: GraphicType.area,
      points: const [LatLng(1, 1), LatLng(1, 2), LatLng(2, 2)],
      colorValue: 0xFFFF0000,
    );
    await up.close();
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('ALTER TABLE map_graphics DROP COLUMN geofence');
          raw.execute('PRAGMA user_version = 14');
        },
      ),
    );
    addTearDown(db.close);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
    final repo = MapGraphicRepository(db);
    final old = (await repo.watchAll().first).firstWhere(
      (g) => g.name == 'ESKİ',
    );
    expect(old.geofence, isNull);
    await repo.setGeofence(old.id!, GeofenceTrigger.exit);
    await repo.add(
      name: 'ÇİT',
      type: GraphicType.circle,
      points: const [LatLng(1, 1), LatLng(1.01, 1)],
      colorValue: 0xFFFF0000,
      geofence: GeofenceTrigger.both,
    );
    final all = await repo.watchAll().first;
    expect(
      all.firstWhere((g) => g.name == 'ESKİ').geofence,
      GeofenceTrigger.exit,
    );
    expect(
      all.firstWhere((g) => g.name == 'ÇİT').geofence,
      GeofenceTrigger.both,
    );
    await repo.setGeofence(old.id!, null);
    expect(
      (await repo.watchAll().first)
          .firstWhere((g) => g.name == 'ESKİ')
          .geofence,
      isNull,
    );
  });
}
