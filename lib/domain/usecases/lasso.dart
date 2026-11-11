import 'package:latlong2/latlong.dart';

/// Nokta çokgenin içinde mi (ışın atma; kısa mesafede düz kabul).
bool pointInPolygon(LatLng p, List<LatLng> poly) {
  if (poly.length < 3) return false;
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    final crosses =
        (a.latitude > p.latitude) != (b.latitude > p.latitude) &&
        p.longitude <
            (b.longitude - a.longitude) *
                    (p.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Lasso (ATAK Lasso + Multi-Select, kılavuz s.25, 44): çizilen çokgenin
/// içine düşen nesneler. [anchors]: nesne → seçimi belirleyen noktalar
/// (nokta: konumu; çizim: köşeleri — biri içerdeyse seçilir).
List<T> lassoSelect<T>(
  List<LatLng> polygon,
  Iterable<T> items,
  Iterable<LatLng> Function(T) anchors,
) => [
  for (final it in items)
    if (anchors(it).any((p) => pointInPolygon(p, polygon))) it,
];
