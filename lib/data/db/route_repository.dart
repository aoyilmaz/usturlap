import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../core/uuid.dart';
import '../../domain/models/route_plan.dart';
import 'app_database.dart';

/// Planlanmış rotalar köprüsü (domain ↔ drift).
class RouteRepository {
  RouteRepository(this._db);

  final AppDatabase _db;

  /// Tüm rotalar (en yeni üstte), canlı akış.
  Stream<List<RoutePlan>> watchAll() {
    final q = _db.select(_db.routePlans)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Rotayı kaydeder ve kaydedilen hâlini döndürür.
  Future<RoutePlan> add({
    required String name,
    required List<LatLng> points,
    String? uid,
  }) async {
    final u = uid ?? newUuidV4();
    final created = DateTime.now();
    final id = await _db.into(_db.routePlans).insert(RoutePlansCompanion.insert(
          name: name,
          pointsJson: _encode(points),
          createdAt: created,
          uid: Value(u),
        ));
    return RoutePlan(
        id: id, uid: u, name: name, points: points, createdAt: created);
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.routePlans)..where((t) => t.id.equals(id)))
        .write(RoutePlansCompanion(name: Value(name)));
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.routePlans)..where((t) => t.id.equals(id))).go();
  }

  static String _encode(List<LatLng> pts) =>
      jsonEncode([for (final p in pts) [p.latitude, p.longitude]]);

  static List<LatLng> _decode(String raw) => [
        for (final e in jsonDecode(raw) as List<dynamic>)
          LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()),
      ];

  RoutePlan _toDomain(RoutePlanRow r) => RoutePlan(
        id: r.id,
        uid: r.uid ?? 'local-route-${r.id}',
        name: r.name,
        points: _decode(r.pointsJson),
        createdAt: r.createdAt,
      );
}
