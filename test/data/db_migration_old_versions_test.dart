import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';

/// v8'den eski sürümlerden yükseltme (2026-11-07 simülatörde bulundu):
/// v7 adımı `route_plans`'ı GÜNCEL tanımla (uid dahil) kurduğu için v8 adımı
/// "duplicate column name: uid" ile düşüyordu → uygulama her açılışta çöker.
///
/// Eski şemalar gerçek v7 dosyasından türetilir: v7 = v6 + route_plans,
/// v6 = v5 + imported_layers, v5 = v4 + map_graphics + echelon/role.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('migration_old_');
  });
  tearDown(() async => dir.delete(recursive: true));

  /// db_v7'yi kopyalar; açılışta (yükseltmeden hemen önce) [statements] ile
  /// eski sürüme indirger.
  Future<AppDatabase> open(int version, List<String> statements) async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v$version.sqlite');
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          for (final s in statements) {
            raw.execute(s);
          }
          raw.execute('PRAGMA user_version = $version');
        },
      ),
    );
    addTearDown(db.close);
    return db;
  }

  Future<void> expectUpgraded(AppDatabase db) async {
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
    for (final t in ['waypoints', 'map_graphics', 'tracks', 'route_plans']) {
      final empty = await db
          .customSelect('SELECT count(*) AS n FROM $t WHERE uid IS NULL')
          .getSingle();
      expect(empty.read<int>('n'), 0, reason: '$t uid dolu olmalı');
    }
    final wps = await db.select(db.waypoints).get();
    expect(wps, isNotEmpty);
    // Yeni rota eklenebiliyor (route_plans çalışır durumda).
    await db.customStatement(
      "INSERT INTO route_plans (name, points_json, created_at, uid) "
      "VALUES ('R', '[]', 0, 'u-yeni')",
    );
  }

  test('v6 → v8 (route_plans yokken)', () async {
    await expectUpgraded(await open(6, ['DROP TABLE route_plans']));
  });

  test('v4 → v8 (map_graphics, imported_layers, route_plans yokken)', () async {
    await expectUpgraded(
      await open(4, [
        'DROP TABLE route_plans',
        'DROP TABLE imported_layers',
        'DROP TABLE map_graphics',
        'ALTER TABLE waypoints DROP COLUMN echelon',
        'ALTER TABLE waypoints DROP COLUMN role',
      ]),
    );
  });

  test('yarıda kalmış v8 yükseltmesi tekrar çalışır', () async {
    // Simülatördeki durum: user_version 6, ama bazı v8 sütunları eklenmiş.
    await expectUpgraded(
      await open(6, [
        'DROP TABLE route_plans',
        'ALTER TABLE waypoints ADD COLUMN uid TEXT NULL',
        'ALTER TABLE waypoints ADD COLUMN cot_type TEXT NULL',
        'ALTER TABLE tracks ADD COLUMN uid TEXT NULL',
      ]),
    );
  });
}
