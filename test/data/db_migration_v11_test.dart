import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/range_line_repository.dart';
import 'package:kerteriz/data/db/range_ring_repository.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:latlong2/latlong.dart';

/// v10 → v11: kalıcı menzil halkaları tablosu; R&B çizgileri korunur.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v11_'));
  tearDown(() async => dir.delete(recursive: true));

  test('v10 → v11', () async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v10.sqlite');
    // Güncel şemaya yükselt, bir R&B çizgisi ekle.
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    await RangeLineRepository(upgraded).add(
      name: 'R&B-1',
      start: const RbEnd(LatLng(37, 37)),
      end: const RbEnd(LatLng(37.1, 37)),
    );
    await upgraded.close();
    // v10'a indir: halkalar tablosu yok.
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('DROP TABLE range_rings');
          raw.execute('PRAGMA user_version = 10');
        },
      ),
    );
    addTearDown(db.close);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
    final rings = RangeRingRepository(db);
    await rings.add(
      name: 'HALKA-1',
      center: const RbEnd(LatLng(37, 37)),
      radii: const [500],
      colorValue: RangeLine.defaultColor,
    );
    expect(await rings.watchAll().first, hasLength(1));
    expect(await RangeLineRepository(db).watchAll().first, hasLength(1));
  });
}
