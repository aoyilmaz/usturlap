import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/waypoint.dart';
import 'app_database.dart';

/// Waypoint kalıcılığı için domain ↔ drift köprüsü.
/// Presentation katmanı yalnızca domain `Waypoint` görür; drift'i bilmez.
class WaypointRepository {
  WaypointRepository(this._db);

  final AppDatabase _db;

  /// Tüm waypoint'leri (en yeni üstte) canlı akış olarak verir.
  Stream<List<Waypoint>> watchAll() {
    final query = _db.select(_db.waypoints)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        // createdAt saniye çözünürlükte; aynı saniyedeki kayıtlar için id ile
        // ayır (en yeni = en büyük id).
        (t) => OrderingTerm.desc(t.id),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Yeni waypoint kaydeder, oluşturulan id'yi döndürür.
  Future<int> add({
    required String name,
    required LatLng position,
    String? note,
  }) {
    return _db.into(_db.waypoints).insert(
          WaypointsCompanion.insert(
            name: name,
            lat: position.latitude,
            lon: position.longitude,
            createdAt: DateTime.now(),
            note: Value(note),
          ),
        );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.waypoints)..where((t) => t.id.equals(id))).go();
  }

  Waypoint _toDomain(WaypointRow r) => Waypoint(
        id: r.id,
        name: r.name,
        position: LatLng(r.lat, r.lon),
        createdAt: r.createdAt,
        note: r.note,
      );
}
