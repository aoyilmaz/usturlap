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
@DriftDatabase(tables: [Waypoints, Settings, Tracks, TrackPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Test için: çağıran bir QueryExecutor (ör. NativeDatabase.memory()) verir.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Mevcut veriyi koruyarak yeni tablolar ekle.
          if (from < 2) await m.createTable(settings);
          if (from < 3) {
            await m.createTable(tracks);
            await m.createTable(trackPoints);
          }
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
