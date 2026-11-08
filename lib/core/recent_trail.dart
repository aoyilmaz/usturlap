import 'package:latlong2/latlong.dart';

import 'geo_math.dart';

/// Son [window] süredeki kendi konumlarımız (ATAK self-marker "son 15 dk
/// izi", kılavuz s.8). İz kaydından bağımsız, yalnızca bellekte.
///
/// Saf Dart: [add] her GPS konumuyla çağrılır; [minSpacingMeters]'den yakın
/// konumlar (durağan titreme) eklenmez, süresi geçenler atılır.
class RecentTrail {
  RecentTrail({
    this.window = const Duration(minutes: 15),
    this.minSpacingMeters = 5,
  });

  final Duration window;
  final double minSpacingMeters;
  final _points = <(LatLng, DateTime)>[];

  /// Konum ekler; iz değiştiyse true.
  bool add(LatLng p, DateTime at) {
    var changed = prune(at);
    if (_points.isEmpty ||
        GeoMath.distance(_points.last.$1, p) >= minSpacingMeters) {
      _points.add((p, at));
      changed = true;
    }
    return changed;
  }

  /// [now]'dan [window] önceki noktaları atar; atıldıysa true.
  bool prune(DateTime now) {
    final cutoff = now.subtract(window);
    final before = _points.length;
    _points.removeWhere((e) => e.$2.isBefore(cutoff));
    return _points.length != before;
  }

  List<LatLng> get points => [for (final e in _points) e.$1];
}
