import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/map_graphic_repository.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:latlong2/latlong.dart';

/// v13 → v14: çizimlerde 3B yükseklik.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v14_'));
  tearDown(() async => dir.delete(recursive: true));

  test('v13 → v14: eski çizimler düz; yükseklik yazılıp okunur', () async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v13.sqlite');
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
          raw.execute('ALTER TABLE map_graphics DROP COLUMN height');
          raw.execute('PRAGMA user_version = 13');
        },
      ),
    );
    addTearDown(db.close);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 14);
    final repo = MapGraphicRepository(db);
    expect(
      (await repo.watchAll().first).firstWhere((g) => g.name == 'ESKİ').height,
      isNull,
    );
    await repo.add(
      name: 'KULE',
      type: GraphicType.rectangle,
      points: const [LatLng(1, 1), LatLng(1, 2), LatLng(2, 2), LatLng(2, 1)],
      colorValue: 0xFFFF0000,
      height: 25,
    );
    expect(
      (await repo.watchAll().first).firstWhere((g) => g.name == 'KULE').height,
      25,
    );
  });
}
