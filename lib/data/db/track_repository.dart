import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/track.dart';
import 'app_database.dart';

/// Rota izi kalıcılığı (domain ↔ drift köprüsü).
class TrackRepository {
  TrackRepository(this._db);

  final AppDatabase _db;

  /// Yeni iz başlatır (endedAt null), id döndürür.
  Future<int> startTrack(String name) {
    return _db.into(_db.tracks).insert(
          TracksCompanion.insert(name: name, startedAt: DateTime.now()),
        );
  }

  /// İze bir nokta ekler.
  Future<void> addPoint(
    int trackId,
    LatLng position, {
    DateTime? timestamp,
    double? altitude,
    double? speed,
  }) {
    return _db.into(_db.trackPoints).insert(
          TrackPointsCompanion.insert(
            trackId: trackId,
            lat: position.latitude,
            lon: position.longitude,
            timestamp: timestamp ?? DateTime.now(),
            altitude: Value(altitude),
            speed: Value(speed),
          ),
        );
  }

  /// İzi sonlandırır (endedAt = now).
  Future<void> endTrack(int trackId) {
    return (_db.update(_db.tracks)..where((t) => t.id.equals(trackId)))
        .write(TracksCompanion(endedAt: Value(DateTime.now())));
  }

  Future<void> deleteTrack(int trackId) {
    // Noktaları ve izi açıkça sil (foreign_keys PRAGMA'sına bağlı kalmadan).
    return _db.transaction(() async {
      await (_db.delete(_db.trackPoints)
            ..where((t) => t.trackId.equals(trackId)))
          .go();
      await (_db.delete(_db.tracks)..where((t) => t.id.equals(trackId))).go();
    });
  }

  /// Tüm izleri (en yeni üstte), her biri için nokta sayısıyla canlı verir.
  Stream<List<Track>> watchTracks() {
    final countExp = _db.trackPoints.id.count();
    final query = _db.select(_db.tracks).join([
      leftOuterJoin(
        _db.trackPoints,
        _db.trackPoints.trackId.equalsExp(_db.tracks.id),
      ),
    ])
      ..groupBy([_db.tracks.id])
      ..orderBy([OrderingTerm.desc(_db.tracks.startedAt)]);
    query.addColumns([countExp]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final t = row.readTable(_db.tracks);
        final count = row.read(countExp) ?? 0;
        return Track(
          id: t.id,
          name: t.name,
          startedAt: t.startedAt,
          endedAt: t.endedAt,
          pointCount: count,
        );
      }).toList();
    });
  }

  /// Bir izin noktalarını (zaman sırasıyla) canlı verir — çizim için.
  Stream<List<TrackPoint>> watchPoints(int trackId) {
    final query = _db.select(_db.trackPoints)
      ..where((t) => t.trackId.equals(trackId))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return query.watch().map((rows) => rows.map(_toDomainPoint).toList());
  }

  /// Bir izin noktalarını tek seferlik getirir (export için).
  Future<List<TrackPoint>> pointsOf(int trackId) async {
    final query = _db.select(_db.trackPoints)
      ..where((t) => t.trackId.equals(trackId))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    final rows = await query.get();
    return rows.map(_toDomainPoint).toList();
  }

  TrackPoint _toDomainPoint(TrackPointRow r) => TrackPoint(
        position: LatLng(r.lat, r.lon),
        timestamp: r.timestamp,
        altitude: r.altitude,
        speedMps: r.speed,
      );
}
