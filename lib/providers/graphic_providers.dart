import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/map_graphic_repository.dart';
import '../domain/models/map_graphic.dart';
import 'waypoint_providers.dart';

final mapGraphicRepositoryProvider = Provider<MapGraphicRepository>((ref) {
  return MapGraphicRepository(ref.watch(appDatabaseProvider));
});

/// Kayıtlı taktik grafiklerin canlı listesi (en yeni üstte).
final mapGraphicsProvider = StreamProvider<List<MapGraphic>>((ref) {
  return ref.watch(mapGraphicRepositoryProvider).watchAll();
});
