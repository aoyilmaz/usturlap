import 'package:latlong2/latlong.dart';

import '../models/map_graphic.dart';

/// Bir geofence uyarısı: şekle giriş ya da çıkış.
class GeofenceEvent {
  const GeofenceEvent({
    required this.uid,
    required this.name,
    required this.entered,
    required this.at,
  });

  final String uid;
  final String name;

  /// true = girildi, false = çıkıldı.
  final bool entered;
  final DateTime at;
}

/// Geofence izleyicisi (ATAK Geofencing, kılavuz s.43): her konumda
/// şekillerin içinde / dışında olunduğunu önceki konumla karşılaştırır;
/// şeklin uyarı türüne uyan geçişlerde olay üretir. İlk konum yalnızca
/// başlangıç durumunu belirler (uygulama açılınca boşuna uyarı yok).
class GeofenceMonitor {
  final Map<String, bool> _inside = {};

  /// Şekil için son bilinen durum (bilinmiyorsa null).
  bool? isInside(String uid) => _inside[uid];

  Map<String, bool> get snapshot => Map.unmodifiable(_inside);

  List<GeofenceEvent> update(
    LatLng p,
    Iterable<MapGraphic> graphics,
    DateTime at,
  ) {
    final out = <GeofenceEvent>[];
    final seen = <String>{};
    for (final g in graphics) {
      final trigger = g.geofence;
      if (trigger == null || !g.closed) continue;
      seen.add(g.uid);
      final now = g.contains(p);
      final before = _inside[g.uid];
      _inside[g.uid] = now;
      if (before == null || before == now) continue;
      if (now ? trigger.onEntry : trigger.onExit) {
        out.add(GeofenceEvent(uid: g.uid, name: g.name, entered: now, at: at));
      }
    }
    // Silinen / uyarısı kaldırılan şekillerin durumu unutulur.
    _inside.removeWhere((uid, _) => !seen.contains(uid));
    return out;
  }
}
