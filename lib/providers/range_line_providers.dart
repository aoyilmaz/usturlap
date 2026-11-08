import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo_math.dart';
import '../data/db/range_line_repository.dart';
import '../data/db/range_ring_repository.dart';
import '../domain/models/range_line.dart';
import '../domain/models/range_ring.dart';
import '../domain/models/waypoint.dart';
import 'location_providers.dart';
import 'waypoint_providers.dart';

final rangeLineRepositoryProvider = Provider<RangeLineRepository>((ref) {
  return RangeLineRepository(ref.watch(appDatabaseProvider));
});

/// Kayıtlı R&B çizgileri (en yeni üstte), canlı.
final rangeLinesProvider = StreamProvider<List<RangeLine>>((ref) {
  return ref.watch(rangeLineRepositoryProvider).watchAll();
});

/// Uçları bağlı oldukları nesnelerin şimdiki konumuna çözülmüş çizgi.
class ResolvedRangeLine {
  ResolvedRangeLine(this.line, this.from, this.to);

  final RangeLine line;
  final LatLng from;
  final LatLng to;

  late final RbMeasure measure = RbMeasure.between(from, to);

  /// Etiketin konduğu orta nokta (büyük daire üzerinde).
  LatLng get middle => measure.meters < 1
      ? from
      : GeoMath.destination(from, measure.meters / 2, measure.bearing);
}

/// Bağlı uçları çözmek için gerekenler: kendi konumum + noktalar (uid →
/// konum). R&B çizgileri, halkalar ve bullseye ortak kullanır.
final anchorResolverProvider = Provider<LatLng Function(RbEnd)>((ref) {
  final self = ref.watch(selfContactProvider)?.position;
  final wps = {
    for (final w in ref.watch(waypointsProvider).value ?? const <Waypoint>[])
      w.uid: w.position,
  };
  return (e) => e.resolve(self: self, waypoints: wps);
});

/// Haritanın ve detay panelinin kullandığı çözülmüş liste: kendi konumum
/// ya da bağlı nokta değişince yeniden hesaplanır.
final resolvedRangeLinesProvider = Provider<List<ResolvedRangeLine>>((ref) {
  final lines = ref.watch(rangeLinesProvider).value ?? const <RangeLine>[];
  if (lines.isEmpty) return const [];
  final at = ref.watch(anchorResolverProvider);
  return [for (final l in lines) ResolvedRangeLine(l, at(l.start), at(l.end))];
});

// ------------------------------------------------------------- halkalar

final rangeRingRepositoryProvider = Provider<RangeRingRepository>((ref) {
  return RangeRingRepository(ref.watch(appDatabaseProvider));
});

/// Kayıtlı menzil / tehdit halkaları (en yeni üstte), canlı.
final rangeRingsProvider = StreamProvider<List<RangeRing>>((ref) {
  return ref.watch(rangeRingRepositoryProvider).watchAll();
});

/// Merkezi bağlı olduğu nesnenin şimdiki konumuna çözülmüş halka grubu.
class ResolvedRangeRing {
  const ResolvedRangeRing(this.ring, this.center);

  final RangeRing ring;
  final LatLng center;

  /// [i]. halkanın etiket noktası: halkanın kuzey ucu.
  LatLng labelPoint(int i) => GeoMath.destination(center, ring.radii[i], 0);
}

final resolvedRangeRingsProvider = Provider<List<ResolvedRangeRing>>((ref) {
  final rings = ref.watch(rangeRingsProvider).value ?? const <RangeRing>[];
  if (rings.isEmpty) return const [];
  final at = ref.watch(anchorResolverProvider);
  return [for (final r in rings) ResolvedRangeRing(r, at(r.center))];
});
