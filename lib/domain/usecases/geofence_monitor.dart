import 'dart:math' as math;

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
///
/// Sınır tamponu: durum ancak kenardan en az [margin] (GPS doğruluğu daha
/// kötüyse doğruluk kadar) içeri ya da dışarı geçilince değişir. Kenar
/// boyunca yürürken konum titremesi aynı uyarıyı tekrar tekrar
/// üretiyordu (denetim 2026-11-16). Küçük şekillerde tampon şeklin en
/// küçük boyutunun dörtte birini geçmez.
class GeofenceMonitor {
  GeofenceMonitor({this.margin = 15});

  /// En küçük sınır tamponu (m).
  final double margin;

  final Map<String, bool> _inside = {};

  /// Şekil için son bilinen durum (bilinmiyorsa null).
  bool? isInside(String uid) => _inside[uid];

  Map<String, bool> get snapshot => Map.unmodifiable(_inside);

  /// [accuracy]: konumun doğruluğu (m); tamponu büyütür.
  List<GeofenceEvent> update(
    LatLng p,
    Iterable<MapGraphic> graphics,
    DateTime at, {
    double? accuracy,
  }) {
    final out = <GeofenceEvent>[];
    final seen = <String>{};
    for (final g in graphics) {
      final trigger = g.geofence;
      if (trigger == null || !g.closed) continue;
      seen.add(g.uid);
      final raw = g.contains(p);
      final before = _inside[g.uid];
      var now = raw;
      if (before != null && raw != before) {
        // Sınırı açıkça geçmeden durum değişmez.
        final want = math.min(
          math.max(margin, accuracy ?? 0),
          g.minSpanMeters / 4,
        );
        if (g.distanceToEdge(p) < want) now = before;
      }
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
