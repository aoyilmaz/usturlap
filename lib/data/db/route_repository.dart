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
    List<String?> pointNames = const [],
    String? uid,
  }) async {
    final u = uid ?? newUuidV4();
    final created = DateTime.now();
    final id = await _db.into(_db.routePlans).insert(RoutePlansCompanion.insert(
          name: name,
          pointsJson: _encode(points, pointNames),
          createdAt: created,
          uid: Value(u),
        ));
    return RoutePlan(
        id: id,
        uid: u,
        name: name,
        points: points,
        pointNames: pointNames,
        createdAt: created);
  }

  /// Noktaları ve adlarını değiştirir (ters çevirme, nokta adları).
  Future<void> setPoints(int id, List<LatLng> points, List<String?> names) {
    return (_db.update(_db.routePlans)..where((t) => t.id.equals(id))).write(
        RoutePlansCompanion(pointsJson: Value(_encode(points, names))));
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.routePlans)..where((t) => t.id.equals(id)))
        .write(RoutePlansCompanion(name: Value(name)));
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.routePlans)..where((t) => t.id.equals(id))).go();
  }

  /// [[lat, lon], [lat, lon, "ad"], …] — ad isteğe bağlı üçüncü eleman
  /// (eski kayıtlar adsız okunur; şema değişmedi).
  static String _encode(List<LatLng> pts, [List<String?> names = const []]) {
    String? nameAt(int i) {
      final n = i < names.length ? names[i]?.trim() : null;
      return n == null || n.isEmpty ? null : n;
    }

    return jsonEncode([
      for (var i = 0; i < pts.length; i++)
        [pts[i].latitude, pts[i].longitude, ?nameAt(i)],
    ]);
  }

  static List<dynamic> _rows(String raw) => jsonDecode(raw) as List<dynamic>;

  static List<LatLng> _decode(List<dynamic> rows) => [
        for (final e in rows)
          LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()),
      ];

  static List<String?> _names(List<dynamic> rows) => [
        for (final e in rows)
          (e as List).length > 2 && e[2] is String ? e[2] as String : null,
      ];

  RoutePlan _toDomain(RoutePlanRow r) {
    final rows = _rows(r.pointsJson);
    return RoutePlan(
      id: r.id,
      uid: r.uid ?? 'local-route-${r.id}',
      name: r.name,
      points: _decode(rows),
      pointNames: _names(rows),
      createdAt: r.createdAt,
    );
  }
}
