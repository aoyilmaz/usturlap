import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';

/// v15 → v16: iz noktalarına iz kimliği indeksi (denetim 2026-11-16).
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v16_'));
  tearDown(() async => dir.delete(recursive: true));

  Future<String> plan(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM track_points WHERE track_id = 1',
        )
        .get();
    return rows.map((r) => r.data['detail']).join(' | ');
  }

  test('yeni kurulumda iz noktaları indeksle aranır', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await plan(db), contains('track_points_track'));
  });

  test('v15 → v16: eski veritabanına indeks eklenir', () async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v15.sqlite');
    final up = AppDatabase.forTesting(NativeDatabase(file));
    await up.customSelect('SELECT 1').get();
    await up.close();
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('DROP INDEX IF EXISTS track_points_track');
          raw.execute('PRAGMA user_version = 15');
        },
      ),
    );
    addTearDown(db.close);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 16);
    expect(await plan(db), contains('track_points_track'));
  });
}
