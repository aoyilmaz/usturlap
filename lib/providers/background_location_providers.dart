import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alert_providers.dart';
import 'nav_providers.dart';
import 'route_providers.dart';
import 'track_providers.dart';

/// Arka plan konumu gerekli mi: iz kaydı sürüyor, arka planda izlenen
/// geofence var, bir rota takip ediliyor ya da "Git" hedefi seçili. Harita
/// ekranı bunu dinleyip konum kaynağına bildirir (tek karar noktası: iz
/// kaydı bitince geofence'in ihtiyacı kapanmasın).
///
/// Rota takibi ve "Git" (karar 2026-11-16): ekran kapalıyken konum
/// gelmezse "noktaya vardın" / "rotadan çıktın" uyarıları da gelmez.
final backgroundLocationNeededProvider = Provider<bool>(
  (ref) =>
      ref.watch(recordingProvider).isRecording ||
      ref.watch(activeRouteProvider) != null ||
      ref.watch(navTargetProvider) != null ||
      (ref.watch(geofenceBackgroundProvider) &&
          ref.watch(hasGeofencesProvider)),
);
