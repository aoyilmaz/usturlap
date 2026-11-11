import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models/map_graphic.dart';
import '../domain/models/range_line.dart';
import '../domain/models/range_ring.dart';
import '../domain/models/waypoint.dart';
import '../domain/usecases/lasso.dart';
import 'map_cleaner.dart';
import 'range_line_providers.dart';

/// Lasso ile seçilenler (yalnız haritada görünenlerden).
class MapSelection {
  const MapSelection({
    required this.polygon,
    this.waypoints = const [],
    this.graphics = const [],
    this.rangeLines = const [],
    this.rangeRings = const [],
  });

  /// Çizilen seçim alanı.
  final List<LatLng> polygon;
  final List<Waypoint> waypoints;
  final List<MapGraphic> graphics;
  final List<RangeLine> rangeLines;
  final List<RangeRing> rangeRings;

  int get count =>
      waypoints.length +
      graphics.length +
      rangeLines.length +
      rangeRings.length;
  bool get isEmpty => count == 0;
}

class SelectionNotifier extends Notifier<MapSelection?> {
  @override
  MapSelection? build() => null;

  /// [polygon] içine düşen görünür nesneleri seçer ve seçimi döndürür.
  MapSelection select(List<LatLng> polygon) {
    final t = ref.read(mapClearTargetsProvider);
    // R&B ve halkalar şimdiki (bağlı) konumlarıyla.
    final rbAt = {
      for (final r in ref.read(resolvedRangeLinesProvider)) r.line.uid: r,
    };
    final ringAt = {
      for (final r in ref.read(resolvedRangeRingsProvider)) r.ring.uid: r,
    };
    final s = MapSelection(
      polygon: polygon,
      waypoints: lassoSelect(polygon, t.waypoints, (w) => [w.position]),
      graphics: lassoSelect(polygon, t.graphics, (g) => g.outline),
      rangeLines: lassoSelect(
        polygon,
        t.rangeLines,
        (l) => [rbAt[l.uid]?.middle ?? l.start.point],
      ),
      rangeRings: lassoSelect(
        polygon,
        t.rangeRings,
        (r) => [ringAt[r.uid]?.center ?? r.center.point],
      ),
    );
    state = s;
    return s;
  }

  /// Panelde işaret kaldırılanlar düşer.
  void set(MapSelection? s) {
    if (ref.mounted) state = s;
  }

  void clear() => set(null);
}

final selectionProvider = NotifierProvider<SelectionNotifier, MapSelection?>(
  SelectionNotifier.new,
);
