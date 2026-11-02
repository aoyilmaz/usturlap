import 'package:drift/drift.dart';

import '../../domain/models/imported_layer.dart';
import 'app_database.dart';

/// İçe-aktarılmış harita paketleri için domain ↔ drift köprüsü.
class ImportedLayerRepository {
  ImportedLayerRepository(this._db);

  final AppDatabase _db;

  /// Tüm içe-aktarılmış katmanlar (en yeni üstte), canlı akış.
  Stream<List<ImportedLayer>> watchAll() {
    final query = _db.select(_db.importedLayers)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Yeni içe-aktarılmış katman kaydeder (aynı id varsa üzerine yazar).
  Future<void> upsert(ImportedLayer layer) {
    return _db.into(_db.importedLayers).insertOnConflictUpdate(
          ImportedLayersCompanion.insert(
            id: layer.id,
            label: layer.label,
            fileName: layer.fileName,
            sourceType: layer.sourceType,
            stylePath: Value(layer.stylePath),
            minZoom: Value(layer.minZoom),
            maxZoom: Value(layer.maxZoom),
            centerLat: Value(layer.centerLat),
            centerLon: Value(layer.centerLon),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> delete(String id) {
    return (_db.delete(_db.importedLayers)..where((t) => t.id.equals(id))).go();
  }

  ImportedLayer _toDomain(ImportedLayerRow r) => ImportedLayer(
        id: r.id,
        label: r.label,
        fileName: r.fileName,
        sourceType: r.sourceType,
        stylePath: r.stylePath,
        minZoom: r.minZoom,
        maxZoom: r.maxZoom,
        centerLat: r.centerLat,
        centerLon: r.centerLon,
      );
}
