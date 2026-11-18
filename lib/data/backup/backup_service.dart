import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/uuid.dart';
import '../db/app_database.dart';
import '../db/attachment_repository.dart';
import '../import/geo_import.dart';

/// Yedek açılamadı (parola yanlış, dosya bozuk, uyumsuz sürüm).
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Şifreli yedek dosyası (`.krz`): "KRTZYDK1" + sürüm + PBKDF2 tur sayısı +
/// tuz (16) + nonce (12) + AES-256-GCM şifreli zip + doğrulama etiketi (16).
/// Anahtar paroladan PBKDF2-HMAC-SHA256 ile türetilir; parola dosyada yok.
class BackupCrypto {
  BackupCrypto._();

  static final magic = ascii.encode('KRTZYDK1');
  static const version = 1;

  /// PBKDF2-HMAC-SHA256 tur sayısı (yeni yedekler; OWASP önerisi 600 bin).
  /// Eski yedekler kendi başlıklarındaki sayıyla (300 bin) açılır.
  static const iterations = 600000;

  /// Başlıkta kabul edilen en büyük tur sayısı. Sayı parola doğrulanmadan
  /// önce kullanıldığı için sınırsız olamaz: 10 milyonluk sahte bir başlık
  /// parola ekranını dakikalarca kilitliyordu.
  static const maxIterations = 2000000;

  static bool looksLike(Uint8List data) {
    if (data.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }

  static Future<SecretKey> _key(String password, List<int> salt, int it) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: it,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> encrypt(
    Uint8List plain,
    String password, {
    int iterations = iterations,
  }) async {
    final aes = AesGcm.with256bits();
    final salt = SecretKeyData.random(length: 16).bytes;
    final nonce = aes.newNonce();
    final box = await aes.encrypt(
      plain,
      secretKey: await _key(password, salt, iterations),
      nonce: nonce,
    );
    final header = ByteData(4)..setUint32(0, iterations);
    return Uint8List.fromList([
      ...magic,
      version,
      ...header.buffer.asUint8List(),
      ...salt,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  static Future<Uint8List> decrypt(Uint8List data, String password) async {
    const head = 8 + 1 + 4 + 16 + 12;
    if (!looksLike(data) || data.length < head + 16) {
      throw const BackupException('Bu bir Usturlap yedeği değil.');
    }
    if (data[8] != version) {
      throw const BackupException('Yedek biçimi bu sürümde açılamıyor.');
    }
    final it = ByteData.sublistView(data, 9, 13).getUint32(0);
    if (it < 10000 || it > maxIterations) {
      throw const BackupException('Yedek dosyası bozuk.');
    }
    final salt = data.sublist(13, 29);
    final nonce = data.sublist(29, 41);
    final cipher = data.sublist(41, data.length - 16);
    final mac = data.sublist(data.length - 16);
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: await _key(password, salt, it),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupException('Parola yanlış ya da dosya bozuk.');
    }
  }
}

/// Yedeğin içi (açılmış).
class BackupContents {
  const BackupContents({
    required this.database,
    required this.attachments,
    required this.meta,
  });

  final Uint8List database;

  /// "attachments/…" göreli yol → içerik.
  final Map<String, Uint8List> attachments;
  final Map<String, dynamic> meta;

  int get schema => (meta['schema'] as num?)?.toInt() ?? 0;
  DateTime? get createdAt => DateTime.tryParse('${meta['createdAt']}');
  Map<String, int> get counts => {
    for (final e in ((meta['counts'] as Map?) ?? const {}).entries)
      '${e.key}': (e.value as num?)?.toInt() ?? 0,
  };
}

/// Yedek zip'i: `kerteriz.sqlite`, `yedek.json`, `attachments/…`.
/// "kerteriz" adları (dosya adı, `app` alanı, `.krz`, "KRTZYDK1") uygulamanın
/// eski adından kalan biçim kimlikleridir; eski yedekler açılsın diye değişmez.
class BackupArchive {
  BackupArchive._();

  static const dbName = 'kerteriz.sqlite';
  static const metaName = 'yedek.json';

  static Uint8List build(BackupContents c) {
    final a = Archive()
      ..addFile(ArchiveFile.bytes(metaName, utf8.encode(jsonEncode(c.meta))))
      ..addFile(ArchiveFile.bytes(dbName, c.database));
    c.attachments.forEach((path, bytes) {
      a.addFile(ArchiveFile.bytes(path, bytes));
    });
    return ZipEncoder().encodeBytes(a);
  }

  static BackupContents read(Uint8List zip) {
    final Archive a;
    try {
      a = ZipDecoder().decodeBytes(zip, throwOnError: true);
    } on Exception {
      throw const BackupException('Yedek dosyası bozuk.');
    }
    Uint8List? db;
    Map<String, dynamic>? meta;
    final attachments = <String, Uint8List>{};
    for (final f in a.files) {
      if (!f.isFile || !GeoImport.safePath(f.name)) continue;
      final bytes = f.readBytes();
      if (bytes == null) continue;
      if (f.name == dbName) {
        db = bytes;
      } else if (f.name == metaName) {
        final j = jsonDecode(utf8.decode(bytes));
        if (j is Map<String, dynamic>) meta = j;
      } else if (f.name.startsWith('${AttachmentRepository.folder}/')) {
        attachments[f.name] = bytes;
      }
    }
    if (db == null || meta == null || meta['app'] != 'kerteriz') {
      throw const BackupException('Bu bir Usturlap yedeği değil.');
    }
    return BackupContents(database: db, attachments: attachments, meta: meta);
  }
}

/// Yedek oluşturma ve geri yükleme (I2). Yedekte: veritabanı (noktalar,
/// çizimler, izler, rotalar, ölçümler, ayarlar) ve nokta fotoğrafları.
/// Harita dosyaları ve yükseklik verisi büyük olduğu için girmez.
///
/// Geri yükleme çalışan bağlantıyı kapatmaz: yedek veritabanı ayrı açılıp
/// güncel şemaya yükseltilir, sonra tek işlemde tablolar kopyalanır
/// (sütun adlarıyla; eski veritabanlarında sütun sırası farklı olabilir).
/// İçe aktarılmış harita katmanları bu cihazdaki dosyalara bağlı olduğu
/// için korunur.
class BackupService {
  BackupService(
    this.db, {
    Future<Directory> Function()? documentsDir,
    Future<Directory> Function()? tempDir,
  }) : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
       _tempDir = tempDir ?? getTemporaryDirectory;

  final AppDatabase db;
  final Future<Directory> Function() _documentsDir;
  final Future<Directory> Function() _tempDir;

  Future<int> _count(String table) async {
    final r = await db
        .customSelect('SELECT COUNT(*) AS n FROM "$table"')
        .getSingle();
    return r.read<int>('n');
  }

  /// Şifreli yedek (`.krz` içeriği).
  Future<Uint8List> create(String password, {DateTime? now}) async {
    final tmp = await _tempDir();
    final copy = File('${tmp.path}/yedek_${newUuidV4()}.sqlite');
    try {
      // Açık veritabanının tutarlı kopyası.
      await db.customStatement('VACUUM INTO ?', [copy.path]);
      final database = await copy.readAsBytes();
      final docs = (await _documentsDir()).path;
      final dir = Directory('$docs/${AttachmentRepository.folder}');
      final attachments = <String, Uint8List>{};
      if (await dir.exists()) {
        await for (final e in dir.list(recursive: true)) {
          if (e is! File) continue;
          final rel = e.path.substring(docs.length + 1);
          attachments[rel] = await e.readAsBytes();
        }
      }
      final meta = {
        'app': 'kerteriz',
        'schema': db.schemaVersion,
        'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
        'counts': {
          'waypoints': await _count(db.waypoints.actualTableName),
          'graphics': await _count(db.mapGraphics.actualTableName),
          'tracks': await _count(db.tracks.actualTableName),
          'routes': await _count(db.routePlans.actualTableName),
          'photos': attachments.length,
        },
      };
      final contents = BackupContents(
        database: database,
        attachments: attachments,
        meta: meta,
      );
      return _seal(contents, password);
    } finally {
      if (await copy.exists()) await copy.delete();
    }
  }

  /// Yedeği çözer ve okur (parola yanlışsa [BackupException]).
  Future<BackupContents> open(Uint8List data, String password) async {
    final contents = await _unseal(data, password);
    if (contents.schema > db.schemaVersion) {
      throw const BackupException(
        'Yedek daha yeni bir Usturlap sürümünden; önce uygulamayı güncelle.',
      );
    }
    return contents;
  }

  // İş parçacığı işleri statik: kapanış `this`'i (veritabanı) yakalamasın.
  static Future<Uint8List> _seal(BackupContents c, String password) =>
      Isolate.run(() => BackupCrypto.encrypt(BackupArchive.build(c), password));

  static Future<BackupContents> _unseal(Uint8List data, String password) =>
      Isolate.run(() async {
        final zip = await BackupCrypto.decrypt(data, password);
        return BackupArchive.read(zip);
      });

  /// Mevcut veriyi yedektekiyle değiştirir.
  ///
  /// Sıra önemli: önce yedekteki fotoğraflar ayrı bir klasöre yazılır
  /// (disk doluysa burada durur, hiçbir şey değişmemiş olur), sonra
  /// veritabanı tek işlemde değiştirilir, en son klasörler yer değiştirir.
  /// Eskiden veritabanı önce değişiyordu; fotoğraf yazımı bozulunca yeni
  /// veritabanı eski fotoğraflarla kalıyor ve "geri yüklenemedi" deniyordu.
  Future<void> restore(BackupContents c) async {
    final docs = (await _documentsDir()).path;
    const folder = AttachmentRepository.folder;
    final dir = Directory('$docs/$folder');
    final aside = Directory('$docs/${folder}_eski');
    final staged = Directory('$docs/${folder}_yeni');
    if (await staged.exists()) await staged.delete(recursive: true);
    try {
      await staged.create(recursive: true);
      for (final e in c.attachments.entries) {
        // Anahtarlar "attachments/…" (BackupArchive.read doğrular).
        final rel = e.key.substring(folder.length + 1);
        final f = File('${staged.path}/$rel');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(e.value, flush: true);
      }
      await _restoreDatabase(c);
    } catch (_) {
      if (await staged.exists()) await staged.delete(recursive: true);
      rethrow;
    }

    // Fotoğraflar yerine konur: hazırlanan klasör asıl adını alır.
    try {
      if (await aside.exists()) await aside.delete(recursive: true);
      if (await dir.exists()) await dir.rename(aside.path);
      await staged.rename(dir.path);
    } catch (_) {
      // Yer değiştirme yarıda kaldıysa eski fotoğrafları geri koy.
      if (!await dir.exists() && await aside.exists()) {
        await aside.rename(dir.path);
      }
      rethrow;
    }
    // Eski fotoğrafların silinememesi geri yüklemeyi başarısız yapmaz.
    try {
      if (await aside.exists()) await aside.delete(recursive: true);
    } catch (_) {}
  }

  /// Veritabanını yedektekiyle değiştirir (tek işlem; hata olursa eski veri
  /// aynen kalır).
  Future<void> _restoreDatabase(BackupContents c) async {
    final tmp = await _tempDir();
    final file = File('${tmp.path}/geri_${newUuidV4()}.sqlite');
    await file.writeAsBytes(c.database, flush: true);
    try {
      // Yedeği ayrı aç: drift eski şemayı güncele yükseltir.
      final old = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await old.customSelect('SELECT 1').get();
      } finally {
        await old.close();
      }

      final tables = [
        for (final t in db.allTables)
          if (t.actualTableName != db.importedLayers.actualTableName) t,
      ];
      await db.customStatement('ATTACH DATABASE ? AS yedek', [file.path]);
      try {
        await db.transaction(() async {
          for (final t in tables) {
            final cols = t.$columns.map((c) => '"${c.name}"').join(', ');
            final name = '"${t.actualTableName}"';
            await db.customStatement('DELETE FROM main.$name');
            await db.customStatement(
              'INSERT INTO main.$name ($cols) SELECT $cols FROM yedek.$name',
            );
          }
        });
      } finally {
        await db.customStatement('DETACH DATABASE yedek');
      }
      db.notifyUpdates({for (final t in tables) TableUpdate.onTable(t)});
    } finally {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('${file.path}$suffix');
        if (await f.exists()) await f.delete();
      }
    }
  }
}
