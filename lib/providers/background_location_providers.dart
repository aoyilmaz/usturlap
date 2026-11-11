import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alert_providers.dart';
import 'track_providers.dart';

/// Arka plan konumu gerekli mi: iz kaydı sürüyor ya da arka planda izlenen
/// geofence var. Harita ekranı bunu dinleyip konum kaynağına bildirir
/// (tek karar noktası: iz kaydı bitince geofence'in ihtiyacı kapanmasın).
final backgroundLocationNeededProvider = Provider<bool>(
  (ref) =>
      ref.watch(recordingProvider).isRecording ||
      (ref.watch(geofenceBackgroundProvider) &&
          ref.watch(hasGeofencesProvider)),
);
