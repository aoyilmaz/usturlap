import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/waypoint_repository.dart';
import 'package:kerteriz/domain/models/sensor_fov.dart';

/// v11 → v12: noktalarda görüş konisi sütunları.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v12_'));
  tearDown(() async => dir.delete(recursive: true));

  Future<AppDatabase> openAsV11(List<String> statements) async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v11.sqlite');
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    await upgraded.customSelect('SELECT 1').get();
    await upgraded.close();
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          for (final s in statements) {
            raw.execute(s);
          }
          raw.execute('PRAGMA user_version = 11');
        },
      ),
    );
    addTearDown(db.close);
    return db;
  }

  Future<void> expectV12(AppDatabase db) async {
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 14);
    final repo = WaypointRepository(db);
    final wps = await repo.watchAll().first;
    expect(wps, isNotEmpty);
    expect(wps.every((w) => w.fov == null), isTrue);
    const fov = SensorFov(azimuth: 45, width: 60, range: 1500);
    await repo.setFov(wps.first.id!, fov);
    expect(
      (await repo.watchAll().first).firstWhere((w) => w.id == wps.first.id).fov,
      fov,
    );
  }

  test('v11 → v12', () async {
    await expectV12(
      await openAsV11([
        'ALTER TABLE waypoints DROP COLUMN fov_azimuth',
        'ALTER TABLE waypoints DROP COLUMN fov_width',
        'ALTER TABLE waypoints DROP COLUMN fov_range',
      ]),
    );
  });

  test('yarıda kalmış yükseltme tamamlanır (bir sütun var)', () async {
    await expectV12(
      await openAsV11([
        'ALTER TABLE waypoints DROP COLUMN fov_width',
        'ALTER TABLE waypoints DROP COLUMN fov_range',
      ]),
    );
  });
}
