import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../offline/mapbox_offline_store.dart';

/// Acil veri silme (ATAK "Clear Content", kılavuz s.58).
///
/// Silinenler:
/// - Veritabanı: noktalar, izler, rotalar, grafikler, ayarlar (callsign dahil).
/// - Belgeler klasörü: içe aktarılan dosyalar, nokta fotoğrafları
///   (`attachments/`), yükseklik verisi.
/// - Geçici klasör: paylaşılan dışa aktarımlar (KML/GeoJSON) ve kopyalar.
/// - Mapbox: indirilen bölgeler, stil paketi, önbellek.
///
/// [includeMaps] false ise harita dosyaları (.pmtiles/.mbtiles/.gpkg, yükseklik
/// verisi, indirilen bölgeler) korunur; geri kalan her şey silinir.
///
/// iOS her dosyayı ayrı anahtarla şifreler; dosya silinince anahtarı da
/// silinir, bu yüzden silinen dosyalar kurtarılamaz.
class ContentWiper {
  ContentWiper({
    required this.db,
    this.offline,
    Future<Directory> Function()? documentsDir,
    Future<Directory> Function()? tempDir,
  }) : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
       _tempDir = tempDir ?? getTemporaryDirectory;

  final AppDatabase db;
  final MapboxOfflineStore? offline;
  final Future<Directory> Function() _documentsDir;
  final Future<Directory> Function() _tempDir;

  /// drift dosyası (`pusula.sqlite`, `-wal`, `-shm`): açık olduğu için
  /// silinmez; içi [AppDatabase.wipeAll] ile boşaltılır.
  static const dbFilePrefix = 'pusula.sqlite';

  /// Yükseklik verisi klasörü (bkz. HgtParser).
  static const elevationDir = 'tiles_external';

  Future<void> wipe({bool includeMaps = true}) async {
    await db.wipeAll(keepImportedLayers: !includeMaps);
    final temps = {(await _tempDir()).path, Directory.systemTemp.path};
    await wipeFiles(await _documentsDir(), [
      for (final t in temps) Directory(t),
    ], includeMaps: includeMaps);
    if (includeMaps) await offline?.deleteAll();
  }

  /// Dosya silme kısmı (test edilebilsin diye ayrı).
  static Future<void> wipeFiles(
    Directory documents,
    List<Directory> temps, {
    required bool includeMaps,
  }) async {
    if (await documents.exists()) {
      for (final e in documents.listSync()) {
        final name = _name(e);
        if (name.startsWith(dbFilePrefix)) continue;
        if (!includeMaps && isMapData(name)) continue;
        await _delete(e);
      }
    }
    for (final t in temps) {
      if (!await t.exists()) continue;
      for (final e in t.listSync()) {
        await _delete(e);
      }
    }
  }

  /// Harita verisi mi (haritalar korunurken dokunulmayacaklar).
  static bool isMapData(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.pmtiles') ||
        n.endsWith('.mbtiles') ||
        n.endsWith('.gpkg') ||
        n == elevationDir;
  }

  static String _name(FileSystemEntity e) =>
      e.path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).last;

  static Future<void> _delete(FileSystemEntity e) async {
    try {
      await e.delete(recursive: true);
    } catch (_) {
      // Kilitli/izinsiz dosya: silmenin geri kalanı devam etsin.
    }
  }
}
