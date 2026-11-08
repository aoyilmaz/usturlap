import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../core/uuid.dart';
import '../../domain/models/sensor_fov.dart';
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
  /// [uid] verilmezse yeni UUID üretilir (içe aktarmada kaynağın uid'i korunur).
  /// [cotType]: dışarıdan gelen ham CoT tipi (yoksa sembolden türetilir).
  Future<int> add({
    required String name,
    required LatLng position,
    String? uid,
    String? note,
    Affiliation affiliation = Affiliation.waypoint,
    Echelon echelon = Echelon.none,
    SymbolRole role = SymbolRole.none,
    String? cotType,
    double? hae,
  }) {
    return _db.into(_db.waypoints).insert(
          WaypointsCompanion.insert(
            name: name,
            lat: position.latitude,
            lon: position.longitude,
            createdAt: DateTime.now(),
            uid: Value(uid ?? newUuidV4()),
            note: Value(note),
            affiliation: Value(affiliation.name),
            echelon: Value(echelon.name),
            role: Value(role.name),
            cotType: Value(cotType),
            hae: Value(hae),
          ),
        );
  }

  /// Var olan bir waypoint'in ad/not/sadakat/echelon/rolünü günceller.
  /// Sadakat ya da rol değişirse dışarıdan gelmiş ham CoT tipi bırakılır
  /// (artık kullanıcının seçtiği sembolden türetilir).
  Future<void> updateDetails(
    int id, {
    required String name,
    String? note,
    required Affiliation affiliation,
    Echelon echelon = Echelon.none,
    SymbolRole role = SymbolRole.none,
  }) async {
    final current = await (_db.select(_db.waypoints)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (current == null) return;
    final symbolChanged =
        Affiliation.fromName(current.affiliation) != affiliation ||
            SymbolRole.fromName(current.role) != role;
    await (_db.update(_db.waypoints)..where((t) => t.id.equals(id))).write(
      WaypointsCompanion(
        name: Value(name),
        note: Value(note),
        affiliation: Value(affiliation.name),
        echelon: Value(echelon.name),
        role: Value(role.name),
        cotType: symbolChanged ? const Value(null) : const Value.absent(),
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

  /// Elle girilen yüksekliği (MSL, m) ayarlar; null = arazi verisine dön.
  Future<void> setElevation(int id, double? meters) {
    return (_db.update(_db.waypoints)..where((t) => t.id.equals(id))).write(
      WaypointsCompanion(elevation: Value(meters)),
    );
  }

  /// Görüş konisini kurar / değiştirir; null kaldırır.
  Future<void> setFov(int id, SensorFov? fov) {
    return (_db.update(_db.waypoints)..where((t) => t.id.equals(id))).write(
      WaypointsCompanion(
        fovAzimuth: Value(fov?.azimuth),
        fovWidth: Value(fov?.width),
        fovRange: Value(fov?.range),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.waypoints)..where((t) => t.id.equals(id))).go();
  }

  Waypoint _toDomain(WaypointRow r) => Waypoint(
        id: r.id,
        // v8'den sonra hep dolu; yalnızca savunma amaçlı yedek.
        uid: r.uid ?? 'local-waypoint-${r.id}',
        name: r.name,
        position: LatLng(r.lat, r.lon),
        createdAt: r.createdAt,
        note: r.note,
        affiliation: Affiliation.fromName(r.affiliation),
        echelon: Echelon.fromName(r.echelon),
        role: SymbolRole.fromName(r.role),
        typeCode: r.cotType,
        hae: r.hae,
        elevation: r.elevation,
        fov: SensorFov.isValid(r.fovAzimuth, r.fovWidth, r.fovRange)
            ? SensorFov(
                azimuth: r.fovAzimuth!,
                width: r.fovWidth!,
                range: r.fovRange!,
              )
            : null,
      );
}
