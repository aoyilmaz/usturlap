import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Navigasyon hesapları (saf Dart, test edilir).
class NavMath {
  NavMath._();

  static const _r = 6371008.8; // ortalama Dünya yarıçapı (m)
  static const _d = Distance();

  /// 0..360 kerteriz.
  static double bearing(LatLng a, LatLng b) => (_d.bearing(a, b) + 360) % 360;

  static double distance(LatLng a, LatLng b) => _d(a, b);

  /// Hedefin, gidiş yönüne göre göreli açısı: −180..180
  /// (pozitif = sağa dön, negatif = sola dön).
  static double relativeBearing(double targetBearing, double heading) {
    var r = (targetBearing - heading) % 360;
    if (r > 180) r -= 360;
    if (r < -180) r += 360;
    return r;
  }

  /// Tahmini varış süresi. Hız bilinmiyor ya da çok düşükse (duruyor)
  /// [fallbackMps] kullanılır (varsayılan yürüyüş ~4 km/s); o da null ise null.
  static Duration? eta(double distanceM, double? speedMps,
      {double? fallbackMps = 4 / 3.6}) {
    final v = (speedMps != null && speedMps >= 0.5) ? speedMps : fallbackMps;
    if (v == null || v <= 0) return null;
    return Duration(seconds: (distanceM / v).round());
  }

  /// [p] noktasının [start]→[end] doğrusuna (büyük daire) dik uzaklığı (m).
  /// Pozitif = doğrunun SAĞI (gidiş yönüne göre), negatif = SOLU.
  static double crossTrack(LatLng start, LatLng end, LatLng p) {
    final d13 = distance(start, p) / _r;
    final t13 = _rad(bearing(start, p));
    final t12 = _rad(bearing(start, end));
    return math.asin(math.sin(d13) * math.sin(t13 - t12)) * _r;
  }

  /// [p]'nin [start]→[end] doğrusu üzerindeki izdüşümünün başlangıca uzaklığı
  /// (m). Negatif = başlangıcın gerisinde.
  static double alongTrack(LatLng start, LatLng end, LatLng p) {
    final d13 = distance(start, p) / _r;
    final xt = crossTrack(start, end, p) / _r;
    final c = math.cos(d13) / math.cos(xt);
    final at = math.acos(c.clamp(-1.0, 1.0)) * _r;
    // Başlangıcın gerisindeyse (açı > 90°) negatif.
    final t13 = _rad(bearing(start, p));
    final t12 = _rad(bearing(start, end));
    return math.cos(t13 - t12) < 0 ? -at : at;
  }

  static double _rad(double deg) => deg * math.pi / 180;

  /// "1 sa 05 dk" / "37 dk" / "45 sn".
  static String fmtDuration(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours} sa ${(d.inMinutes % 60).toString().padLeft(2, '0')} dk';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes} dk';
    return '${d.inSeconds} sn';
  }

  /// Göreli kerterizi söze çevirir: "düz", "sağa 35°", "sola 120°".
  static String fmtTurn(double rel) {
    final a = rel.abs().round();
    if (a <= 10) return 'düz';
    return rel > 0 ? 'sağa $a°' : 'sola $a°';
  }
}
