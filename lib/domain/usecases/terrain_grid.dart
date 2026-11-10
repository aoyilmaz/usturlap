import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Bir alanın düzenli yükseklik ızgarası (arazi analizi için): satırlar
/// kuzeyden güneye, sütunlar batıdan doğuya; veri yoksa NaN.
class TerrainGrid {
  TerrainGrid({
    required this.rows,
    required this.cols,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.cellX,
    required this.cellY,
    required this.z,
  });

  final int rows, cols;

  /// Izgaranın dış sınırları (hücre merkezleri yarım hücre içeride).
  final double north, south, east, west;

  /// Hücre boyu (m): doğu-batı, kuzey-güney.
  final double cellX, cellY;

  /// Yükseklikler (m), `satır * cols + sütun`.
  final Float32List z;

  static const maxCells = 300;
  static const _earthRadius = 6371008.8;

  double at(int r, int c) => z[r * cols + c];

  /// [center] çevresinde kenarı 2·[halfSize] m kare alan; hücre en az
  /// 30 m (veri çözünürlüğü), kenar başına en çok [maxCells].
  static TerrainGrid sample(
    LatLng center,
    double halfSize,
    double? Function(double lat, double lon) elevation,
  ) {
    var n = (2 * halfSize / 30).ceil();
    if (n > maxCells) n = maxCells;
    if (n < 2) n = 2;
    final cell = 2 * halfSize / n;
    final latPerM = 180 / (math.pi * _earthRadius);
    final lonPerM = latPerM / math.cos(center.latitude * math.pi / 180);
    final north = center.latitude + halfSize * latPerM;
    final west = center.longitude - halfSize * lonPerM;
    final z = Float32List(n * n);
    for (var r = 0; r < n; r++) {
      final lat = north - (r + 0.5) * cell * latPerM;
      for (var c = 0; c < n; c++) {
        final lon = west + (c + 0.5) * cell * lonPerM;
        z[r * n + c] = elevation(lat, lon) ?? double.nan;
      }
    }
    return TerrainGrid(
      rows: n,
      cols: n,
      north: north,
      south: center.latitude - halfSize * latPerM,
      east: center.longitude + halfSize * lonPerM,
      west: west,
      cellX: cell,
      cellY: cell,
      z: z,
    );
  }

  bool get hasData => z.any((v) => !v.isNaN);

  /// En alçak / en yüksek (veri yoksa null).
  (double, double)? get range {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final v in z) {
      if (v.isNaN) continue;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return lo.isFinite ? (lo, hi) : null;
  }

  /// Izgara koordinatı (sütun, satır; hücre merkezi = tam sayı) → konum.
  LatLng _toLatLng(double x, double y) => LatLng(
    north - (y + 0.5) / rows * (north - south),
    west + (x + 0.5) / cols * (east - west),
  );

  // ----------------------------------------------------------- eğriler

  /// Eş yükselti eğrileri ("yürüyen kareler"): her [interval] m'de bir;
  /// parçalar uç uca eklenip çizgi olur.
  List<ContourLine> contours(double interval) {
    final segs = <double, List<(double, double, double, double)>>{};
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final tl = at(r, c), tr = at(r, c + 1);
        final br = at(r + 1, c + 1), bl = at(r + 1, c);
        if (tl.isNaN || tr.isNaN || br.isNaN || bl.isNaN) continue;
        final lo = math.min(math.min(tl, tr), math.min(br, bl));
        final hi = math.max(math.max(tl, tr), math.max(br, bl));
        // Seviye = tam sayı × aralık (toplama birikimi anahtarı bozmasın).
        for (var k = (lo / interval).ceil(); k * interval <= hi; k++) {
          _cell(r, c, tl, tr, br, bl, k * interval, segs);
        }
      }
    }
    final out = <ContourLine>[];
    for (final e in segs.entries) {
      for (final chain in _join(e.value)) {
        out.add(
          ContourLine(e.key, [for (final (x, y) in chain) _toLatLng(x, y)]),
        );
      }
    }
    return out;
  }

  /// Bir hücrenin [level] eğrisi parçaları (köşe değerleri ≥ seviye "üstte").
  static void _cell(
    int r,
    int c,
    double tl,
    double tr,
    double br,
    double bl,
    double level,
    Map<double, List<(double, double, double, double)>> segs,
  ) {
    final code =
        (tl >= level ? 8 : 0) |
        (tr >= level ? 4 : 0) |
        (br >= level ? 2 : 0) |
        (bl >= level ? 1 : 0);
    if (code == 0 || code == 15) return;
    double t(double a, double b) => a == b ? 0.5 : (level - a) / (b - a);
    // Kenar noktaları (x = sütun, y = satır).
    final top = (c + t(tl, tr), r.toDouble());
    final right = ((c + 1).toDouble(), r + t(tr, br));
    final bottom = (c + t(bl, br), (r + 1).toDouble());
    final left = (c.toDouble(), r + t(tl, bl));
    final list = segs.putIfAbsent(level, () => []);
    void add((double, double) a, (double, double) b) {
      // Köşe değeri seviyeye tam eşitse iki kenar noktası çakışır:
      // sıfır uzunluklu parça eklenmez.
      if (a == b) return;
      list.add((a.$1, a.$2, b.$1, b.$2));
    }

    final centerHigh = (tl + tr + br + bl) / 4 >= level;
    switch (code) {
      case 1 || 14:
        add(left, bottom);
      case 2 || 13:
        add(bottom, right);
      case 3 || 12:
        add(left, right);
      case 4 || 11:
        add(top, right);
      case 6 || 9:
        add(top, bottom);
      case 7 || 8:
        add(left, top);
      case 5: // eyer: tr ve bl üstte
        if (centerHigh) {
          add(left, top);
          add(bottom, right);
        } else {
          add(left, bottom);
          add(top, right);
        }
      case 10: // eyer: tl ve br üstte
        if (centerHigh) {
          add(left, bottom);
          add(top, right);
        } else {
          add(left, top);
          add(bottom, right);
        }
    }
  }

  /// Uçları ortak parçaları zincirler.
  static List<List<(double, double)>> _join(
    List<(double, double, double, double)> segs,
  ) {
    String key(double x, double y) =>
        '${(x * 1000).round()},${(y * 1000).round()}';
    final byEnd = <String, List<int>>{};
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      byEnd.putIfAbsent(key(s.$1, s.$2), () => []).add(i);
      byEnd.putIfAbsent(key(s.$3, s.$4), () => []).add(i);
    }
    final used = List<bool>.filled(segs.length, false);
    final out = <List<(double, double)>>[];

    (double, double)? next((double, double) p) {
      for (final i in byEnd[key(p.$1, p.$2)] ?? const <int>[]) {
        if (used[i]) continue;
        used[i] = true;
        final s = segs[i];
        return key(s.$1, s.$2) == key(p.$1, p.$2) ? (s.$3, s.$4) : (s.$1, s.$2);
      }
      return null;
    }

    for (var i = 0; i < segs.length; i++) {
      if (used[i]) continue;
      used[i] = true;
      final s = segs[i];
      final chain = <(double, double)>[(s.$1, s.$2), (s.$3, s.$4)];
      // İki yöne uzat.
      for (var p = next(chain.last); p != null; p = next(chain.last)) {
        chain.add(p);
      }
      for (var p = next(chain.first); p != null; p = next(chain.first)) {
        chain.insert(0, p);
      }
      out.add(chain);
    }
    return out;
  }

  // ----------------------------------------------------- renkli katmanlar

  /// Eğim (derece) — Horn yöntemi; kenar hücreler ve verisiz komşuluk NaN.
  Float32List slopes() {
    final out = Float32List(rows * cols)..fillRange(0, rows * cols, double.nan);
    for (var r = 1; r < rows - 1; r++) {
      for (var c = 1; c < cols - 1; c++) {
        final a = at(r - 1, c - 1), b = at(r - 1, c), cc = at(r - 1, c + 1);
        final d = at(r, c - 1), f = at(r, c + 1);
        final g = at(r + 1, c - 1), h = at(r + 1, c), i = at(r + 1, c + 1);
        final dx = ((cc + 2 * f + i) - (a + 2 * d + g)) / (8 * cellX);
        final dy = ((g + 2 * h + i) - (a + 2 * b + cc)) / (8 * cellY);
        final s = math.atan(math.sqrt(dx * dx + dy * dy)) * 180 / math.pi;
        out[r * cols + c] = s; // komşulardan biri NaN ise NaN kalır
      }
    }
    return out;
  }

  /// Eğim katmanı (ön-çarpılmış RGBA): < 10° yeşil, < 20° sarı, < 30°
  /// turuncu, üstü kırmızı; verisiz saydam.
  Uint8List slopeRgba() {
    final s = slopes();
    return _rgba(s.length, (k) {
      final v = s[k];
      if (v.isNaN) return null;
      return slopeColor(v);
    });
  }

  /// Yükseklik katmanı: alandaki en alçaktan en yükseğe yeşil → sarı →
  /// kahverengi → beyaz.
  Uint8List elevationRgba() {
    final rg = range;
    return _rgba(z.length, (k) {
      final v = z[k];
      if (v.isNaN || rg == null) return null;
      final t = rg.$2 == rg.$1 ? 0.5 : (v - rg.$1) / (rg.$2 - rg.$1);
      return elevationColor(t);
    });
  }

  static (int, int, int) slopeColor(double deg) {
    if (deg < 10) return (60, 200, 70);
    if (deg < 20) return (240, 220, 40);
    if (deg < 30) return (245, 140, 30);
    return (220, 40, 40);
  }

  static (int, int, int) elevationColor(double t) {
    const stops = [
      (0.0, (40, 140, 60)),
      (0.35, (200, 210, 90)),
      (0.7, (150, 100, 50)),
      (1.0, (245, 245, 245)),
    ];
    for (var i = 0; i < stops.length - 1; i++) {
      final (t0, c0) = stops[i];
      final (t1, c1) = stops[i + 1];
      if (t <= t1) {
        final f = (t - t0) / (t1 - t0);
        int mix(int a, int b) => (a + (b - a) * f).round();
        return (mix(c0.$1, c1.$1), mix(c0.$2, c1.$2), mix(c0.$3, c1.$3));
      }
    }
    return stops.last.$2;
  }

  static Uint8List _rgba(int n, (int, int, int)? Function(int k) color) {
    const alpha = 0.45;
    final out = Uint8List(n * 4);
    for (var k = 0; k < n; k++) {
      final c = color(k);
      if (c == null) continue;
      out[k * 4] = (c.$1 * alpha).round();
      out[k * 4 + 1] = (c.$2 * alpha).round();
      out[k * 4 + 2] = (c.$3 * alpha).round();
      out[k * 4 + 3] = (255 * alpha).round();
    }
    return out;
  }
}

/// Bir eş yükselti eğrisi (m) ve noktaları.
class ContourLine {
  const ContourLine(this.level, this.points);

  final double level;
  final List<LatLng> points;
}
