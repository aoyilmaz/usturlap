import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/range_line_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:latlong2/latlong.dart';

/// v9 → v10: kalıcı R&B çizgileri tablosu.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v10_'));
  tearDown(() async => dir.delete(recursive: true));

  /// db_v7'den güncel şemaya yükseltilmiş dosyayı, açılışta [statements]
  /// ile v9'a indirger.
  Future<AppDatabase> openAsV9(List<String> statements) async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v9.sqlite');
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
          raw.execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(db.close);
    return db;
  }

  Future<void> expectV10(AppDatabase db) async {
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
    final repo = RangeLineRepository(db);
    await repo.add(
      name: 'R&B-1',
      start: const RbEnd(LatLng(37, 37), RbEnd.selfRef),
      end: const RbEnd(LatLng(37.1, 37.1)),
    );
    expect(await repo.watchAll().first, hasLength(1));
    // Noktalar korunur.
    expect(await WaypointRepository(db).watchAll().first, isNotEmpty);
  }

  test('v9 → v10', () async {
    await expectV10(await openAsV9(['DROP TABLE range_lines']));
  });

  test('tablo zaten varsa (yarıda kalmış yükseltme) düşmez', () async {
    await expectV10(await openAsV9([]));
  });
}
