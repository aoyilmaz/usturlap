import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/backup/backup_service.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/attachment_repository.dart';
import 'package:usturlap/data/db/settings_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:latlong2/latlong.dart';

/// I2: şifreli yedek ve geri yükleme.
void main() {
  late AppDatabase db;
  late Directory docs, tmp;
  late BackupService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = await Directory.systemTemp.createTemp('yedek_docs_');
    tmp = await Directory.systemTemp.createTemp('yedek_tmp_');
    service = BackupService(
      db,
      documentsDir: () async => docs,
      tempDir: () async => tmp,
    );
  });
  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
    await tmp.delete(recursive: true);
  });

  test(
    'şifreleme: doğru parola açar, yanlış parola ve bozuk dosya reddedilir',
    () async {
      final plain = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final enc = await BackupCrypto.encrypt(
        plain,
        'gizli-parola',
        iterations: 20000,
      );
      expect(BackupCrypto.looksLike(enc), isTrue);
      expect(await BackupCrypto.decrypt(enc, 'gizli-parola'), plain);
      await expectLater(
        BackupCrypto.decrypt(enc, 'yanlis'),
        throwsA(isA<BackupException>()),
      );
      final broken = Uint8List.fromList(enc)..[enc.length - 20] ^= 1;
      await expectLater(
        BackupCrypto.decrypt(broken, 'gizli-parola'),
        throwsA(isA<BackupException>()),
      );
      await expectLater(
        BackupCrypto.decrypt(Uint8List.fromList([1, 2, 3]), 'x'),
        throwsA(isA<BackupException>()),
      );
    },
  );

  test(
    'yedekle → değiştir → geri yükle: veri, ayar, fotoğraf döner; katman korunur',
    () async {
      final wps = WaypointRepository(db);
      await wps.add(name: 'OP-1', position: const LatLng(39, 32), uid: 'wp-1');
      await SettingsRepository(db).set('callsign', 'KURT-1');
      final photos = AttachmentRepository(db, documentsDir: () async => docs);
      final src = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
      await photos.addFile('wp-1', src);

      final data = await service.create('parola-123');
      expect(BackupCrypto.looksLike(data), isTrue);

      // Yedekten sonra değişiklikler.
      final w = (await wps.watchAll().first).single;
      await wps.delete(w.id!);
      await wps.add(name: 'YENİ', position: const LatLng(40, 33));
      await SettingsRepository(db).set('callsign', 'BAŞKA');
      await photos.deleteAllFor('wp-1');
      await db
          .into(db.importedLayers)
          .insert(
            ImportedLayersCompanion.insert(
              id: 'katman',
              label: 'Katman',
              fileName: 'k.pmtiles',
              sourceType: 'pmtiles',
              createdAt: DateTime(2026),
              minZoom: const Value(5),
            ),
          );

      await expectLater(
        service.open(data, 'yanlis'),
        throwsA(isA<BackupException>()),
      );
      final c = await service.open(data, 'parola-123');
      expect(c.counts['waypoints'], 1);
      expect(c.counts['photos'], 1);
      expect(c.schema, db.schemaVersion);

      await service.restore(c);
      final after = await wps.watchAll().first;
      expect(after.map((w) => w.name), ['OP-1']);
      expect(after.single.uid, 'wp-1');
      expect(await SettingsRepository(db).get('callsign'), 'KURT-1');
      final pics = await photos.watchFor('wp-1').first;
      expect(pics, hasLength(1));
      expect(await File(pics.single.filePath).readAsBytes(), [1, 2, 3]);
      // Bu cihazdaki harita katmanı korunur.
      expect(await db.select(db.importedLayers).get(), hasLength(1));
      // Geçici dosya kalmaz.
      expect(tmp.listSync().where((e) => e.path.endsWith('.sqlite')), isEmpty);
    },
  );

  test('eski şemalı yedek (v7) yükseltilerek geri yüklenir', () async {
    final v7 = await File('test/fixtures/db_v7.sqlite').readAsBytes();
    final c = BackupContents(
      database: v7,
      attachments: const {},
      meta: const {'app': 'kerteriz', 'schema': 7},
    );
    await WaypointRepository(
      db,
    ).add(name: 'SİLİNECEK', position: const LatLng(1, 1));
    await service.restore(c);
    final names = (await WaypointRepository(
      db,
    ).watchAll().first).map((w) => w.name);
    expect(names, isNot(contains('SİLİNECEK')));
  });

  test('yedek zip okuyucu: Usturlap yedeği olmayan zip reddedilir', () {
    final zip = BackupArchive.build(
      BackupContents(
        database: Uint8List(4),
        attachments: const {},
        meta: const {'app': 'baska'},
      ),
    );
    expect(() => BackupArchive.read(zip), throwsA(isA<BackupException>()));
  });

  group('denetim 2026-11-16', () {
    test('yeni yedekler 600 bin turla şifrelenir', () {
      expect(BackupCrypto.iterations, 600000);
    });

    test('başlıktaki aşırı tur sayısı parola denenmeden reddedilir', () async {
      final enc = await BackupCrypto.encrypt(
        Uint8List.fromList([1, 2, 3]),
        'parola',
        iterations: 20000,
      );
      ByteData.sublistView(enc, 9, 13).setUint32(0, 10000000);
      final sw = Stopwatch()..start();
      await expectLater(
        BackupCrypto.decrypt(enc, 'parola'),
        throwsA(isA<BackupException>()),
      );
      expect(sw.elapsed.inSeconds, lessThan(2));
    });

    test('eski (300 bin turlu) yedek açılmaya devam eder', () async {
      final plain = Uint8List.fromList([9, 8, 7]);
      final enc = await BackupCrypto.encrypt(plain, 'eski', iterations: 300000);
      expect(await BackupCrypto.decrypt(enc, 'eski'), plain);
    });

    test(
      'fotoğraf yazılamazsa veritabanı ve fotoğraflar hiç değişmez',
      () async {
        final wps = WaypointRepository(db);
        final photos = AttachmentRepository(db, documentsDir: () async => docs);
        await wps.add(
          name: 'YEDEKTEKİ',
          position: const LatLng(39, 32),
          uid: 'a',
        );
        await photos.addFile(
          'a',
          File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 1, 1]),
        );
        final c = await service.open(await service.create('p'), 'p');

        // Yedekten sonra cihazdaki hâl.
        await wps.delete((await wps.watchAll().first).single.id!);
        await photos.deleteAllFor('a');
        await wps.add(
          name: 'CİHAZDAKİ',
          position: const LatLng(40, 33),
          uid: 'b',
        );
        await photos.addFile(
          'b',
          File('${tmp.path}/b.jpg')..writeAsBytesSync([2, 2, 2]),
        );

        // Geçersiz dosya adlı bir fotoğraf: hazırlık klasörüne yazım düşer.
        final broken = BackupContents(
          database: c.database,
          attachments: {
            ...c.attachments,
            'attachments/x/\u0000geçersiz.jpg': Uint8List.fromList([0]),
          },
          meta: c.meta,
        );
        await expectLater(service.restore(broken), throwsA(anything));

        // Hiçbir şey değişmedi: cihazdaki nokta ve fotoğrafı yerinde.
        final now = await wps.watchAll().first;
        expect(now.map((w) => w.name), ['CİHAZDAKİ']);
        final pics = await photos.watchFor('b').first;
        expect(pics, hasLength(1));
        expect(await File(pics.single.filePath).readAsBytes(), [2, 2, 2]);
        expect(
          Directory('${docs.path}/attachments_yeni').existsSync(),
          isFalse,
        );
      },
    );
  });
}
