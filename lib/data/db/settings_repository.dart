import '../../core/uuid.dart';
import 'app_database.dart';

/// Basit anahtar-değer ayar erişimi (drift `Settings` tablosu üzerinde).
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }
}

/// Bu cihazın kalıcı CoT kimliği (veri paketinde "oluşturan"); ilk
/// istendiğinde üretilir. Konum içermez. (Extension: testlerdeki sahte
/// ayar depoları da kullanabilsin.)
extension DeviceUid on SettingsRepository {
  Future<String> deviceUid() async {
    const key = 'device_uid';
    final saved = await get(key);
    if (saved != null && saved.isNotEmpty) return saved;
    final uid = 'KERTERIZ-${newUuidV4()}';
    await set(key, uid);
    return uid;
  }
}
