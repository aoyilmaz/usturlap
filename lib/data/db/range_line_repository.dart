import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../core/uuid.dart';
import '../../domain/models/range_line.dart';
import 'app_database.dart';

/// Kalıcı R&B çizgisi köprüsü (domain ↔ drift).
class RangeLineRepository {
  RangeLineRepository(this._db);

  final AppDatabase _db;

  /// Tüm çizgiler (en yeni üstte), canlı akış.
  Stream<List<RangeLine>> watchAll() {
    final query = _db.select(_db.rangeLines)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Yeni çizgi kaydeder, id döndürür.
  Future<int> add({
    required String name,
    required RbEnd start,
    required RbEnd end,
    int colorValue = RangeLine.defaultColor,
    String? uid,
  }) {
    return _db
        .into(_db.rangeLines)
        .insert(
          RangeLinesCompanion.insert(
            uid: uid ?? newUuidV4(),
            name: name,
            startLat: start.point.latitude,
            startLon: start.point.longitude,
            startRef: Value(start.ref),
            endLat: end.point.latitude,
            endLon: end.point.longitude,
            endRef: Value(end.ref),
            color: colorValue,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.rangeLines)..where((t) => t.id.equals(id))).write(
      RangeLinesCompanion(name: Value(name)),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.rangeLines)..where((t) => t.id.equals(id))).go();
  }

  RangeLine _toDomain(RangeLineRow r) => RangeLine(
    id: r.id,
    uid: r.uid,
    name: r.name,
    start: RbEnd(LatLng(r.startLat, r.startLon), r.startRef),
    end: RbEnd(LatLng(r.endLat, r.endLon), r.endRef),
    colorValue: r.color,
    createdAt: r.createdAt,
  );
}
