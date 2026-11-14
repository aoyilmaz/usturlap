import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';

/// v8 → v9: noktalara yükseklik (MSL) + nesne ekleri tablosu.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mig_v9_'));
  tearDown(() async => dir.delete(recursive: true));

  /// db_v7'den güncel şemaya yükseltilmiş dosyayı, açılışta [statements]
  /// ile v8'e indirger.
  Future<AppDatabase> openAsV8(List<String> statements) async {
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/v8.sqlite');
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
          raw.execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(db.close);
    return db;
  }

  Future<void> expectV9(AppDatabase db) async {
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
    final cols = await db.customSelect('PRAGMA table_info(waypoints)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('elevation'));
    // Ekler tablosu çalışır durumda.
    await db.customStatement(
      "INSERT INTO attachments (item_uid, path, created_at) "
      "VALUES ('u', 'attachments/u/a.jpg', 0)",
    );
    // Noktalar korunur, yükseklikleri boş.
    final wps = await WaypointRepository(db).watchAll().first;
    expect(wps, isNotEmpty);
    expect(wps.every((w) => w.elevation == null), isTrue);
  }

  test('v8 → v9', () async {
    await expectV9(
      await openAsV8([
        'DROP TABLE attachments',
        'ALTER TABLE waypoints DROP COLUMN elevation',
      ]),
    );
  });

  test(
    'yarıda kalmış v9 yükseltmesi tamamlanır (sütun var, tablo yok)',
    () async {
      await expectV9(await openAsV8(['DROP TABLE attachments']));
    },
  );
}
