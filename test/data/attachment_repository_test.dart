import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/attachment_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:latlong2/latlong.dart';

/// D3e: nokta fotoğrafları (dosya + kayıt).
void main() {
  late Directory root;
  late AppDatabase db;
  late AttachmentRepository repo;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('attach_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AttachmentRepository(db, documentsDir: () async => root);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<File> photo([String name = 'secici_kopyasi.JPG']) async {
    final f = File('${root.path}/tmp/$name');
    await f.create(recursive: true);
    await f.writeAsBytes([1, 2, 3]);
    return f;
  }

  test('fotoğraf nesnenin klasörüne kopyalanır, yol göreli saklanır', () async {
    final src = await photo();
    final a = await repo.addFile('uid-1', src);
    expect(a.path, startsWith('attachments/uid-1/'));
    expect(a.path, endsWith('.jpg'));
    expect(await File(a.filePath).readAsBytes(), [1, 2, 3]);
    expect(await src.exists(), isTrue, reason: 'kaynak olduğu gibi kalır');

    final list = await repo.watchFor('uid-1').first;
    expect(list.map((e) => e.filePath), [a.filePath]);
    expect(await repo.watchFor('baska').first, isEmpty);
  });

  test('tek fotoğraf ve nesnenin bütün fotoğrafları silinir', () async {
    final a = await repo.addFile('uid-1', await photo());
    final b = await repo.addFile('uid-1', await photo('2.jpg'));
    await repo.addFile('uid-2', await photo('3.jpg'));

    await repo.delete(a);
    expect(await File(a.filePath).exists(), isFalse);
    expect((await repo.watchFor('uid-1').first).map((e) => e.id), [b.id]);

    await repo.deleteAllFor('uid-1');
    expect(await repo.watchFor('uid-1').first, isEmpty);
    expect(await Directory('${root.path}/attachments/uid-1').exists(), isFalse);
    expect(await repo.watchFor('uid-2').first, hasLength(1));
  });

  test('dışarıdan gelen uid klasör dışına yazamaz', () async {
    expect(AttachmentRepository.safeSegment('../../etc'), '.._.._etc');
    expect(AttachmentRepository.safeSegment('..'), '_');
    expect(AttachmentRepository.safeSegment(''), '_');
    final a = await repo.addFile('../kacak', await photo());
    expect(
      File(a.filePath).absolute.path,
      startsWith('${root.path}/attachments/'),
    );
  });

  test('noktaya elle yükseklik girilir ve kaldırılır', () async {
    final wps = WaypointRepository(db);
    final id = await wps.add(name: 'OP-1', position: const LatLng(37, 37.4));
    await wps.setElevation(id, 884);
    expect((await wps.watchAll().first).single.elevation, 884);
    await wps.setElevation(id, null);
    expect((await wps.watchAll().first).single.elevation, isNull);
  });
}
