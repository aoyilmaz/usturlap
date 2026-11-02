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
    Affiliation affiliation = Affiliation.waypoint,
    Echelon echelon = Echelon.none,
    SymbolRole role = SymbolRole.none,
  }) {
    return _db.into(_db.waypoints).insert(
          WaypointsCompanion.insert(
            name: name,
            lat: position.latitude,
            lon: position.longitude,
            createdAt: DateTime.now(),
            note: Value(note),
            affiliation: Value(affiliation.name),
            echelon: Value(echelon.name),
            role: Value(role.name),
          ),
        );
  }

  /// Var olan bir waypoint'in ad/not/sadakat/echelon/rolünü günceller.
  Future<void> updateDetails(
    int id, {
    required String name,
    String? note,
    required Affiliation affiliation,
    Echelon echelon = Echelon.none,
    SymbolRole role = SymbolRole.none,
  }) {
    return (_db.update(_db.waypoints)..where((t) => t.id.equals(id))).write(
      WaypointsCompanion(
        name: Value(name),
        note: Value(note),
        affiliation: Value(affiliation.name),
        echelon: Value(echelon.name),
        role: Value(role.name),
      ),
    );
  }

  /// Waypoint'i yeni konuma taşır (sürükle/yeniden konumlandır).
  Future<void> move(int id, LatLng position) {
    return (_db.update(_db.waypoints)..where((t) => t.id.equals(id))).write(
      WaypointsCompanion(
        lat: Value(position.latitude),
        lon: Value(position.longitude),
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
        affiliation: Affiliation.fromName(r.affiliation),
        echelon: Echelon.fromName(r.echelon),
        role: SymbolRole.fromName(r.role),
      );
}
