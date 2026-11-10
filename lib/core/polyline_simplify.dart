/// Douglas–Peucker sadeleştirme: çizginin şeklini [tolerance] içinde
/// koruyarak gereksiz noktaları atar (serbest çizimde yüzlerce dokunma
/// noktası → onlarca). Uçlar her zaman kalır. Noktalar (x, y) çiftleri;
/// yığın kullanır (uzun çizgide özyineleme taşmasın).
List<(double, double)> simplifyPolyline(
  List<(double, double)> pts,
  double tolerance,
) {
  if (pts.length < 3) return List.of(pts);
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = true;
  keep[pts.length - 1] = true;
  final stack = <(int, int)>[(0, pts.length - 1)];
  final tol2 = tolerance * tolerance;
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var maxD = 0.0;
    var idx = -1;
    for (var i = a + 1; i < b; i++) {
      final d = _segmentDist2(pts[i], pts[a], pts[b]);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx >= 0 && maxD > tol2) {
      keep[idx] = true;
      stack
        ..add((a, idx))
        ..add((idx, b));
    }
  }
  return [
    for (var i = 0; i < pts.length; i++)
      if (keep[i]) pts[i],
  ];
}

/// [p]'nin [a]–[b] doğru parçasına uzaklığının karesi.
double _segmentDist2(
  (double, double) p,
  (double, double) a,
  (double, double) b,
) {
  final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / len2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final x = a.$1 + t * dx - p.$1, y = a.$2 + t * dy - p.$2;
  return x * x + y * y;
}
