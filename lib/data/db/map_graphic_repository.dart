import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/map_graphic.dart';
import 'app_database.dart';

/// Kalıcı taktik grafik (çizgi/alan) köprüsü (domain ↔ drift).
class MapGraphicRepository {
  MapGraphicRepository(this._db);

  final AppDatabase _db;

  /// Tüm grafikler (en yeni üstte), canlı akış.
  Stream<List<MapGraphic>> watchAll() {
    final query = _db.select(_db.mapGraphics)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Yeni grafik kaydeder, id döndürür.
  Future<int> add({
    required String name,
    required GraphicType type,
    required List<LatLng> points,
    required int colorValue,
  }) {
    return _db.into(_db.mapGraphics).insert(
          MapGraphicsCompanion.insert(
            name: name,
            type: type.name,
            pointsJson: _encode(points),
            color: colorValue,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.mapGraphics)..where((t) => t.id.equals(id))).go();
  }

  // ---- serileştirme ----

  static String _encode(List<LatLng> pts) =>
      jsonEncode([for (final p in pts) [p.latitude, p.longitude]]);

  static List<LatLng> _decode(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final e in list)
        LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()),
    ];
  }

  MapGraphic _toDomain(MapGraphicRow r) => MapGraphic(
        id: r.id,
        name: r.name,
        type: GraphicType.fromName(r.type),
        points: _decode(r.pointsJson),
        colorValue: r.color,
        createdAt: r.createdAt,
      );
}
