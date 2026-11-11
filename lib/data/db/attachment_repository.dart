import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/uuid.dart';
import '../../domain/models/attachment.dart';
import 'app_database.dart';

/// Nesne ekleri (fotoğraf): dosyalar `Belgeler/attachments/<uid>/` altında,
/// kayıtlar drift'te. Acil veri silme Belgeler'i boşalttığı için ekler de
/// gider (bkz. ContentWiper).
class AttachmentRepository {
  AttachmentRepository(this._db, {Future<Directory> Function()? documentsDir})
    : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDir;

  /// Belgeler altındaki klasör adı.
  static const folder = 'attachments';

  /// uid dosya yoluna güvenle girsin: dışarıdan (ör. ATAK'tan) gelen bir
  /// uid "../" ile klasör dışına yazamasın.
  static String safeSegment(String uid) {
    final s = uid.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return s.isEmpty || s == '.' || s == '..' ? '_' : s;
  }

  /// [itemUid]'in ekleri (eskiden yeniye).
  Stream<List<Attachment>> watchFor(String itemUid) {
    final q = _db.select(_db.attachments)
      ..where((t) => t.itemUid.equals(itemUid))
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return q.watch().asyncMap((rows) async {
      final docs = (await _documentsDir()).path;
      return [for (final r in rows) _toDomain(r, docs)];
    });
  }

  /// Bütün ekler (en yeni üstte) — galeri.
  Stream<List<Attachment>> watchAll() {
    final q = _db.select(_db.attachments)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().asyncMap((rows) async {
      final docs = (await _documentsDir()).path;
      return [for (final r in rows) _toDomain(r, docs)];
    });
  }

  /// [source]'u nesnenin klasörüne kopyalar ve kaydeder (kaynak dosya,
  /// ör. seçicinin geçici kopyası, olduğu gibi kalır).
  Future<Attachment> addFile(String itemUid, File source) async {
    final docs = (await _documentsDir()).path;
    final dot = source.path.lastIndexOf('.');
    final ext = dot >= 0 && source.path.length - dot <= 5
        ? source.path.substring(dot).toLowerCase()
        : '.jpg';
    final rel = '$folder/${safeSegment(itemUid)}/${newUuidV4()}$ext';
    final dest = File('$docs/$rel');
    await dest.parent.create(recursive: true);
    await source.copy(dest.path);
    final now = DateTime.now();
    final id = await _db
        .into(_db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            itemUid: itemUid,
            path: rel,
            createdAt: now,
          ),
        );
    return Attachment(
      id: id,
      itemUid: itemUid,
      path: rel,
      filePath: dest.path,
      createdAt: now,
    );
  }

  /// Eki siler (dosya + kayıt).
  Future<void> delete(Attachment a) async {
    await _deleteFile(File(a.filePath));
    await (_db.delete(_db.attachments)..where((t) => t.id.equals(a.id))).go();
  }

  /// Nesnenin bütün eklerini siler (nesne silinirken).
  Future<void> deleteAllFor(String itemUid) async {
    final docs = (await _documentsDir()).path;
    await (_db.delete(
      _db.attachments,
    )..where((t) => t.itemUid.equals(itemUid))).go();
    final dir = Directory('$docs/$folder/${safeSegment(itemUid)}');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Silinemeyen dosya kaydı silmeyi engellemesin.
    }
  }

  static Future<void> _deleteFile(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Attachment _toDomain(AttachmentRow r, String docs) => Attachment(
    id: r.id,
    itemUid: r.itemUid,
    path: r.path,
    filePath: '$docs/${r.path}',
    createdAt: r.createdAt,
  );
}
