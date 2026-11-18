import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/uuid.dart';

part 'app_database.g.dart';

/// Kalıcı waypoint kayıtları (SQLite tablosu).
/// Üretilen satır sınıfı `WaypointRow` (domain `Waypoint` ile çakışmasın).
@DataClassName('WaypointRow')
class Waypoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get note => text().nullable()();
  // APP-6 sadakat (Affiliation.name); null = sade waypoint.
  TextColumn get affiliation => text().nullable()();
  // APP-6 v2 modifiers: birlik büyüklüğü + ana ikon (enum .name); null = none.
  TextColumn get echelon => text().nullable()();
  TextColumn get role => text().nullable()();
  // v8: kalıcı, cihazlar arası kimlik (UUID v4, CoT uid). SQLite eski
  // tabloya NOT NULL sütun ekleyemediği için şemada nullable; ama her satırda
  // dolu (eklemede repository üretir, yükseltmede backfillUids doldurur) ve
  // benzersiz indeksli.
  TextColumn get uid => text().nullable()();
  // v8: dışarıdan gelen ham CoT tipi (null = sembolden türetilir).
  TextColumn get cotType => text().nullable()();
  // v8: elipsoit üstü yükseklik (m), CoT hae.
  RealColumn get hae => real().nullable()();
  // v9: deniz seviyesinden yükseklik (m), kullanıcının girdiği (ATAK
  // Details). Girilmemişse arayüz arazi verisinden (HGT) okur.
  RealColumn get elevation => real().nullable()();
  // v12: görüş konisi (yön coğrafi °, açıklık °, menzil m); üçü birlikte
  // dolu ya da boş.
  RealColumn get fovAzimuth => real().nullable()();
  RealColumn get fovWidth => real().nullable()();
  RealColumn get fovRange => real().nullable()();
}

/// Kalıcı taktik grafikler (çizgi/alan). Noktalar JSON dizisi olarak saklanır.
@DataClassName('MapGraphicRow')
class MapGraphics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  // GraphicType.name: 'line' | 'area'.
  TextColumn get type => text()();
  // [[lat,lon],...] JSON.
  TextColumn get pointsJson => text()();
  // ARGB renk değeri.
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();
  // v8: kalıcı, cihazlar arası kimlik (UUID v4, CoT uid). SQLite eski
  // tabloya NOT NULL sütun ekleyemediği için şemada nullable; ama her satırda
  // dolu (eklemede repository üretir, yükseltmede backfillUids doldurur) ve
  // benzersiz indeksli.
  TextColumn get uid => text().nullable()();
  // v13: çizgi kalınlığı (null = varsayılan) ve kesikli stil.
  RealColumn get strokeWidth => real().nullable()();
  BoolColumn get dashed => boolean().nullable()();
  // v14: 3B yükseklik (m); null = düz alan.
  RealColumn get height => real().nullable()();
  // v15: geofence uyarısı (GeofenceTrigger.name); null = yok.
  TextColumn get geofence => text().nullable()();
}

/// Uygulama içinden içe-aktarılmış harita paketleri (Documents'taki .pmtiles/
/// .mbtiles). Katman değiştiricide gömülü katmanların yanında listelenir.
@DataClassName('ImportedLayerRow')
class ImportedLayers extends Table {
  // Benzersiz id (dosya adı türevli).
  TextColumn get id => text()();
  TextColumn get label => text().withLength(min: 1, max: 80)();
  // Documents dizinindeki dosya adı.
  TextColumn get fileName => text()();
  // 'pmtiles' (vektör) | 'mbtiles' (raster).
  TextColumn get sourceType => text()();
  // Vektör için MapLibre stil asset yolu (raster'da null).
  TextColumn get stylePath => text().nullable()();
  IntColumn get minZoom => integer().nullable()();
  IntColumn get maxZoom => integer().nullable()();
  RealColumn get centerLat => real().nullable()();
  RealColumn get centerLon => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Basit anahtar-değer ayar saklama (ör. seçili koordinat biçimi).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Rota izleri (başlat/durdur arası).
@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  // v8: kalıcı, cihazlar arası kimlik (UUID v4, CoT uid). SQLite eski
  // tabloya NOT NULL sütun ekleyemediği için şemada nullable; ama her satırda
  // dolu (eklemede repository üretir, yükseltmede backfillUids doldurur) ve
  // benzersiz indeksli.
  TextColumn get uid => text().nullable()();
}

/// Bir ize ait konum noktaları.
@DataClassName('TrackPointRow')
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get altitude => real().nullable()();
  RealColumn get speed => real().nullable()();
}

/// Nesnelere eklenen dosyalar (v9; şimdilik fotoğraf, ATAK Details).
/// Nesneye uid ile bağlanır (nokta; ileride iz, çizim). Dosya Belgeler
/// klasöründe; yol göreli saklanır (iOS'ta uygulama klasörünün yolu
/// güncellemede değişebilir).
@DataClassName('AttachmentRow')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemUid => text()();
  // Belgeler klasörüne göre: attachments/<uid>/<uuid>.jpg
  TextColumn get path => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Planlanmış rotalar (kontrol noktaları sıralı). Noktalar JSON dizisi.
@DataClassName('RoutePlanRow')
class RoutePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  // [[lat,lon],...] JSON — sıra = rota sırası.
  TextColumn get pointsJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  // v8: kalıcı, cihazlar arası kimlik (UUID v4, CoT uid). SQLite eski
  // tabloya NOT NULL sütun ekleyemediği için şemada nullable; ama her satırda
  // dolu (eklemede repository üretir, yükseltmede backfillUids doldurur) ve
  // benzersiz indeksli.
  TextColumn get uid => text().nullable()();
}

/// v10: kalıcı R&B çizgileri (ATAK R&B Line). Uçlar sabit konum ya da
/// nesneye bağlı (`ref`: `self` ya da `wp:<uid>`; bkz. `RbEnd`); bağlı uçta
/// lat/lon kuruluş anındaki konumdur (nesne silinirse uç orada kalır).
@DataClassName('RangeLineRow')
class RangeLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Yeni tablo: uid baştan zorunlu ve benzersiz.
  TextColumn get uid => text().unique()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get startLat => real()();
  RealColumn get startLon => real()();
  TextColumn get startRef => text().nullable()();
  RealColumn get endLat => real()();
  RealColumn get endLon => real()();
  TextColumn get endRef => text().nullable()();
  // ARGB renk değeri.
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

/// v11: kalıcı menzil / tehdit halkaları (ATAK R&B Circle, Threat Rings).
/// Merkez R&B ucu gibi sabit ya da bağlı (`centerRef`); halka mesafeleri
/// metre cinsinden JSON dizisi, küçükten büyüğe.
@DataClassName('RangeRingRow')
class RangeRings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uid => text().unique()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get centerLat => real()();
  RealColumn get centerLon => real()();
  TextColumn get centerRef => text().nullable()();
  // [500.0, 1000.0, ...] JSON.
  TextColumn get radiiJson => text()();
  // ARGB renk değeri.
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Uygulamanın drift veritabanı. Faz ilerledikçe geofence tabloları
/// buraya eklenecek (şema sürümü artırılarak).
@DriftDatabase(tables: [
  Waypoints,
  Settings,
  Tracks,
  TrackPoints,
  MapGraphics,
  ImportedLayers,
  RoutePlans,
  Attachments,
  RangeLines,
  RangeRings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Test için: çağıran bir QueryExecutor (ör. NativeDatabase.memory()) verir.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createUidIndexes();
          await _createAttachmentIndex();
          await _createTrackPointIndex();
        },
        onUpgrade: (m, from, to) async {
          // Mevcut veriyi koruyarak yeni tablo/sütun ekle.
          // DİKKAT: createTable tabloyu GÜNCEL tanımla kurar (sonradan eklenen
          // sütunlar dahil). Bu yüzden sütunlar `_addColumnIfMissing` ile
          // eklenir; aksi halde eski sürümden atlayarak gelen kurulum
          // "duplicate column" ile düşer. Yarıda kalan yükseltme de (SQLite
          // sütun eklemeyi geri almaz) bir sonraki açılışta tamamlanır.
          if (from < 2) await m.createTable(settings);
          if (from < 3) {
            await m.createTable(tracks);
            await m.createTable(trackPoints);
          }
          // v4: waypoint'lere APP-6 sadakat sütunu.
          if (from < 4) {
            await _addColumnIfMissing(m, waypoints, waypoints.affiliation);
          }
          // v5: APP-6 v2 modifiers + kalıcı taktik grafikler.
          if (from < 5) {
            await _addColumnIfMissing(m, waypoints, waypoints.echelon);
            await _addColumnIfMissing(m, waypoints, waypoints.role);
            await m.createTable(mapGraphics);
          }
          // v6: uygulama-içi içe-aktarılan harita paketleri.
          if (from < 6) await m.createTable(importedLayers);
          // v7: planlanmış rotalar.
          if (from < 7) await m.createTable(routePlans);
          // v8: ATAK nesne modeli — kalıcı uid (+ noktalarda ham CoT tipi, hae).
          if (from < 8) {
            await _addColumnIfMissing(m, waypoints, waypoints.uid);
            await _addColumnIfMissing(m, waypoints, waypoints.cotType);
            await _addColumnIfMissing(m, waypoints, waypoints.hae);
            await _addColumnIfMissing(m, mapGraphics, mapGraphics.uid);
            await _addColumnIfMissing(m, tracks, tracks.uid);
            await _addColumnIfMissing(m, routePlans, routePlans.uid);
            await backfillUids();
            await _createUidIndexes();
          }
          // v9: nokta yüksekliği (MSL) + nesne ekleri (fotoğraf).
          if (from < 9) {
            await _addColumnIfMissing(m, waypoints, waypoints.elevation);
            if (!await _tableExists(attachments.actualTableName)) {
              await m.createTable(attachments);
            }
            await _createAttachmentIndex();
          }
          // v10: kalıcı R&B çizgileri.
          if (from < 10) {
            if (!await _tableExists(rangeLines.actualTableName)) {
              await m.createTable(rangeLines);
            }
          }
          // v11: kalıcı menzil / tehdit halkaları.
          if (from < 11) {
            if (!await _tableExists(rangeRings.actualTableName)) {
              await m.createTable(rangeRings);
            }
          }
          // v12: noktalarda görüş konisi.
          if (from < 12) {
            await _addColumnIfMissing(m, waypoints, waypoints.fovAzimuth);
            await _addColumnIfMissing(m, waypoints, waypoints.fovWidth);
            await _addColumnIfMissing(m, waypoints, waypoints.fovRange);
          }
          // v13: çizimlerde kalınlık ve kesikli stil.
          if (from < 13) {
            await _addColumnIfMissing(m, mapGraphics, mapGraphics.strokeWidth);
            await _addColumnIfMissing(m, mapGraphics, mapGraphics.dashed);
          }
          // v14: kapalı çizimlerde 3B yükseklik.
          if (from < 14) {
            await _addColumnIfMissing(m, mapGraphics, mapGraphics.height);
          }
          // v15: kapalı çizimlerde geofence uyarısı.
          if (from < 15) {
            await _addColumnIfMissing(m, mapGraphics, mapGraphics.geofence);
          }
          if (from < 16) await _createTrackPointIndex();
        },
        beforeOpen: (details) async {
          // Cascade delete için foreign key'leri aç.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Sütun tabloda yoksa ekler (yükseltme adımları tekrar çalışabilsin).
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final cols = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    if (cols.any((c) => c.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// İz noktaları iz kimliğiyle aransın (v16). İndeks yokken iz listesi
  /// sorgusu bütün noktaları tarıyordu; kayıt sırasında her yeni noktada
  /// yinelendiği için uzun süre kullanılan cihazda pil ve takılma.
  Future<void> _createTrackPointIndex() => customStatement(
    'CREATE INDEX IF NOT EXISTS track_points_track '
    'ON track_points (track_id, timestamp)',
  );

  /// Bir nesnenin ekleri hızlı bulunsun.
  Future<void> _createAttachmentIndex() => customStatement(
        'CREATE INDEX IF NOT EXISTS attachments_item ON attachments (item_uid)',
      );

  /// uid'i boş satırlara yeni UUID verir (v8 yükseltmesi). Tekrar çağrılması
  /// zararsızdır: yalnızca boş olanları doldurur.
  Future<void> backfillUids() async {
    for (final table in const [
      'waypoints',
      'map_graphics',
      'tracks',
      'route_plans',
    ]) {
      final rows = await customSelect(
        'SELECT id FROM $table WHERE uid IS NULL',
      ).get();
      for (final r in rows) {
        await customUpdate(
          'UPDATE $table SET uid = ? WHERE id = ?',
          variables: [
            Variable.withString(newUuidV4()),
            Variable.withInt(r.read<int>('id')),
          ],
        );
      }
    }
  }

  /// uid benzersizliği (aynı nesne iki kez kaydedilmesin; paylaşımda
  /// gelen nesne uid ile bulunur).
  Future<void> _createUidIndexes() async {
    for (final table in const [
      'waypoints',
      'map_graphics',
      'tracks',
      'route_plans',
    ]) {
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS ${table}_uid ON $table (uid)',
      );
    }
  }

  /// Acil veri silme (ATAK "Clear Content"): bütün tabloları boşaltır.
  ///
  /// `secure_delete` silinen sayfaların üzerine sıfır yazdırır, `VACUUM`
  /// dosyayı yeniden kurar; böylece silinen kayıtlar dosyada kalmaz.
  /// [keepImportedLayers]: içe aktarılan harita kayıtları korunur (haritalar
  /// silinmeyecekse dosyalar listede görünmeye devam etsin).
  Future<void> wipeAll({bool keepImportedLayers = false}) async {
    await customStatement('PRAGMA secure_delete = ON');
    await transaction(() async {
      for (final t in allTables) {
        if (keepImportedLayers &&
            t.actualTableName == importedLayers.actualTableName) {
          continue;
        }
        await delete(t).go();
      }
      // AUTOINCREMENT sayaçları da sıfırlansın: aksi halde yeni kayıtların
      // id'si silinmeden önce kaç kayıt oluşturulduğunu ele verir.
      await customStatement('DELETE FROM sqlite_sequence');
    });
    await customStatement('VACUUM');
    // WAL kipindeyse günlük dosyasını da boşalt (değilse etkisiz).
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// Veritabanı dosyasını uygulamanın belge dizininde açar (drift_flutter,
  /// path_provider + sqlite3 native kütüphanesini kendi halleder).
  static QueryExecutor _open() => driftDatabase(name: 'pusula');
}
