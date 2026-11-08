import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../core/uuid.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import 'app_database.dart';

/// Kalıcı menzil / tehdit halkası köprüsü (domain ↔ drift).
class RangeRingRepository {
  RangeRingRepository(this._db);

  final AppDatabase _db;

  /// Tüm halkalar (en yeni üstte), canlı akış.
  Stream<List<RangeRing>> watchAll() {
    final query = _db.select(_db.rangeRings)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Yeni halka grubu kaydeder, id döndürür. [radii] sıralanıp
  /// tekrarlardan arındırılır.
  Future<int> add({
    required String name,
    required RbEnd center,
    required List<double> radii,
    required int colorValue,
    String? uid,
  }) {
    return _db
        .into(_db.rangeRings)
        .insert(
          RangeRingsCompanion.insert(
            uid: uid ?? newUuidV4(),
            name: name,
            centerLat: center.point.latitude,
            centerLon: center.point.longitude,
            centerRef: Value(center.ref),
            radiiJson: _encode(radii),
            color: colorValue,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.rangeRings)..where((t) => t.id.equals(id))).write(
      RangeRingsCompanion(name: Value(name)),
    );
  }

  Future<void> setRadii(int id, List<double> radii) {
    return (_db.update(_db.rangeRings)..where((t) => t.id.equals(id))).write(
      RangeRingsCompanion(radiiJson: Value(_encode(radii))),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.rangeRings)..where((t) => t.id.equals(id))).go();
  }

  static String _encode(List<double> radii) =>
      jsonEncode(radii.toSet().toList()..sort());

  static List<double> _decode(String raw) {
    try {
      return [
        for (final v in jsonDecode(raw) as List<dynamic>) (v as num).toDouble(),
      ]..sort();
    } catch (_) {
      return const []; // bozuk kayıt: halkasız (silinebilsin diye listede)
    }
  }

  RangeRing _toDomain(RangeRingRow r) => RangeRing(
    id: r.id,
    uid: r.uid,
    name: r.name,
    center: RbEnd(LatLng(r.centerLat, r.centerLon), r.centerRef),
    radii: _decode(r.radiiJson),
    colorValue: r.color,
    createdAt: r.createdAt,
  );
}
