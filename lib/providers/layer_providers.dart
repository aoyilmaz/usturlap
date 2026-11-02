import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/imported_layer_repository.dart';
import '../domain/models/imported_layer.dart';
import 'waypoint_providers.dart';

final importedLayerRepositoryProvider =
    Provider<ImportedLayerRepository>((ref) {
  return ImportedLayerRepository(ref.watch(appDatabaseProvider));
});

/// İçe-aktarılmış harita katmanlarının canlı listesi (en yeni üstte).
final importedLayersProvider = StreamProvider<List<ImportedLayer>>((ref) {
  return ref.watch(importedLayerRepositoryProvider).watchAll();
});
