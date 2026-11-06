import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wipe/content_wiper.dart';
import 'offline_providers.dart';
import 'waypoint_providers.dart';

/// Acil veri silme servisi (Ayarlar → Acil veri silme).
final contentWiperProvider = Provider<ContentWiper>((ref) {
  return ContentWiper(
    db: ref.watch(appDatabaseProvider),
    offline: ref.watch(offlineStoreProvider),
  );
});
