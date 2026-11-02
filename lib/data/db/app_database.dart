import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

/// Uygulamanın drift veritabanı. Faz ilerledikçe geofence tabloları
/// buraya eklenecek (şema sürümü artırılarak).
@DriftDatabase(tables: [
  Waypoints,
  Settings,
  Tracks,
  TrackPoints,
  MapGraphics,
  ImportedLayers
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Test için: çağıran bir QueryExecutor (ör. NativeDatabase.memory()) verir.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Mevcut veriyi koruyarak yeni tablo/sütun ekle.
          if (from < 2) await m.createTable(settings);
          if (from < 3) {
            await m.createTable(tracks);
            await m.createTable(trackPoints);
          }
          // v4: waypoint'lere APP-6 sadakat sütunu.
          if (from < 4) await m.addColumn(waypoints, waypoints.affiliation);
          // v5: APP-6 v2 modifiers + kalıcı taktik grafikler.
          if (from < 5) {
            await m.addColumn(waypoints, waypoints.echelon);
            await m.addColumn(waypoints, waypoints.role);
            await m.createTable(mapGraphics);
          }
          // v6: uygulama-içi içe-aktarılan harita paketleri.
          if (from < 6) await m.createTable(importedLayers);
        },
        beforeOpen: (details) async {
          // Cascade delete için foreign key'leri aç.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Veritabanı dosyasını uygulamanın belge dizininde açar (drift_flutter,
  /// path_provider + sqlite3 native kütüphanesini kendi halleder).
  static QueryExecutor _open() => driftDatabase(name: 'pusula');
}
