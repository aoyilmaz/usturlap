import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/waypoint_repository.dart';
import '../domain/models/waypoint.dart';

/// Uygulama veritabanı (tek örnek, uygulama yaşam döngüsü boyunca açık).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final waypointRepositoryProvider = Provider<WaypointRepository>((ref) {
  return WaypointRepository(ref.watch(appDatabaseProvider));
});

/// Kayıtlı waypoint'lerin canlı listesi (en yeni üstte).
final waypointsProvider = StreamProvider<List<Waypoint>>((ref) {
  return ref.watch(waypointRepositoryProvider).watchAll();
});
