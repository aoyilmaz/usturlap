import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/attachment_repository.dart';
import '../data/db/waypoint_repository.dart';
import '../domain/models/attachment.dart';
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

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentRepository(ref.watch(appDatabaseProvider));
});

/// Bir nesnenin ekleri (fotoğraflar), canlı.
final attachmentsProvider = StreamProvider.autoDispose
    .family<List<Attachment>, String>((ref, itemUid) {
      return ref.watch(attachmentRepositoryProvider).watchFor(itemUid);
    });
