import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../core/uuid.dart';
import '../../domain/models/track.dart';
import 'app_database.dart';

/// Rota izi kalıcılığı (domain ↔ drift köprüsü).
class TrackRepository {
  TrackRepository(this._db);

  final AppDatabase _db;

  /// Yeni iz başlatır (endedAt null), id döndürür.
  Future<int> startTrack(String name) {
    return _db
        .into(_db.tracks)
        .insert(
          TracksCompanion.insert(
            name: name,
            startedAt: DateTime.now(),
            uid: Value(newUuidV4()),
          ),
        );
  }

  /// İze bir nokta ekler.
  Future<void> addPoint(
    int trackId,
    LatLng position, {
    DateTime? timestamp,
    double? altitude,
    double? speed,
  }) async {
    // Şemada yabancı anahtar yok (üretilen kodda REFERENCES çıkmıyor):
    // silinmiş ize nokta yazılmasını veritabanı engellemez, biz engelleriz.
    final exists =
        await (_db.selectOnly(_db.tracks)
              ..addColumns([_db.tracks.id])
              ..where(_db.tracks.id.equals(trackId)))
            .getSingleOrNull();
    if (exists == null) throw StateError('İz bulunamadı: $trackId');
    await _db
        .into(_db.trackPoints)
        .insert(
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

  /// Tam bir izi (tüm noktalarıyla) tek transaction'da ekler — GPX/KML içe
  /// aktarma için. Kaydı bitmiş (endedAt dolu) olarak ekler; noktalar 1 sn
  /// aralıkla sıralanır (çizim sırası korunur). İz id'sini döndürür.
  ///
  /// [times] / [altitudes] / [speeds] verilirse (her biri nokta sayısıyla
  /// aynı uzunlukta) izin gerçek tarihi, süresi, yüksekliği ve hızı korunur.
  Future<int> importTrack(
    String name,
    List<LatLng> points, {
    String? uid,
    List<DateTime>? times,
    List<double?>? altitudes,
    List<double?>? speeds,
  }) {
    final n = points.length;
    final useTimes = times != null && times.length == n && n > 0;
    final alt = altitudes != null && altitudes.length == n ? altitudes : null;
    final spd = speeds != null && speeds.length == n ? speeds : null;
    return _db.transaction(() async {
      final now = DateTime.now();
      final start = useTimes ? times.first : now;
      final id = await _db
          .into(_db.tracks)
          .insert(
            TracksCompanion.insert(
              name: name,
              startedAt: start,
              endedAt: Value(useTimes ? times.last : start),
              uid: Value(uid ?? newUuidV4()),
            ),
          );
      await _db.batch((b) {
        var ts = start;
        for (var i = 0; i < n; i++) {
          final p = points[i];
          b.insert(
            _db.trackPoints,
            TrackPointsCompanion.insert(
              trackId: id,
              lat: p.latitude,
              lon: p.longitude,
              timestamp: useTimes ? times[i] : ts,
              altitude: Value(alt?[i]),
              speed: Value(spd?[i]),
            ),
          );
          ts = ts.add(const Duration(seconds: 1));
        }
      });
      return id;
    });
  }

  /// Kayıtlı iz sayısı (yeni ize sıra numarası vermek için).
  Future<int> trackCount() async {
    final count = _db.tracks.id.count();
    final row = await (_db.selectOnly(
      _db.tracks,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Yarım kalmış (endedAt boş) izleri kapatır: uygulama kayıt sırasında
  /// kapandıysa (sistem öldürdü, çöktü) iz sonsuza dek "kaydediliyor"
  /// görünmesin, süresi büyümesin. Bitiş = son noktanın zamanı (nokta yoksa
  /// başlangıç). Tek SQL: sonradan başlayan kayıtla yarışmaz. Kapatılan iz
  /// sayısını döndürür.
  Future<int> closeUnfinished() {
    return _db.customUpdate(
      'UPDATE tracks SET ended_at = COALESCE('
      '(SELECT MAX(timestamp) FROM track_points WHERE track_id = tracks.id), '
      'started_at) WHERE ended_at IS NULL',
      updates: {_db.tracks},
      updateKind: UpdateKind.update,
    );
  }

  /// İzi sonlandırır (endedAt = now).
  Future<void> endTrack(int trackId) {
    return (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(endedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteTrack(int trackId) {
    // Noktaları ve izi açıkça sil (foreign_keys PRAGMA'sına bağlı kalmadan).
    return _db.transaction(() async {
      await (_db.delete(
        _db.trackPoints,
      )..where((t) => t.trackId.equals(trackId))).go();
      await (_db.delete(_db.tracks)..where((t) => t.id.equals(trackId))).go();
    });
  }

  /// Tüm izleri (en yeni üstte), her biri için nokta sayısıyla canlı verir.
  Stream<List<Track>> watchTracks() {
    final countExp = _db.trackPoints.id.count();
    final query =
        _db.select(_db.tracks).join([
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
          uid: t.uid ?? 'local-track-${t.id}',
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
