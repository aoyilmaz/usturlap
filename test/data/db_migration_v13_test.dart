import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:latlong2/latlong.dart';

/// v12 → v13: çizimlerde kalınlık ve kesikli stil.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v13_'));
  tearDown(() async => dir.delete(recursive: true));

  test('v12 → v13: eski çizimler varsayılan kalınlıkla, kesiksiz', () async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v12.sqlite');
    final up = AppDatabase.forTesting(NativeDatabase(file));
    await MapGraphicRepository(up).add(
      name: 'HAT',
      type: GraphicType.line,
      points: const [LatLng(1, 1), LatLng(2, 2)],
      colorValue: 0xFFFF0000,
    );
    await up.close();
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('ALTER TABLE map_graphics DROP COLUMN stroke_width');
          raw.execute('ALTER TABLE map_graphics DROP COLUMN dashed');
          raw.execute('PRAGMA user_version = 12');
        },
      ),
    );
    addTearDown(db.close);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
    final g = (await MapGraphicRepository(
      db,
    ).watchAll().first).firstWhere((g) => g.name == 'HAT');
    expect(g.strokeWidth, MapGraphic.defaultStrokeWidth);
    expect(g.dashed, isFalse);
  });
}
