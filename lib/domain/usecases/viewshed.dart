import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Görüş alanı ayarları (ATAK Viewshed, kılavuz s.48).
class ViewshedParams {
  const ViewshedParams({
    required this.observer,
    this.observerHeight = 2,
    this.targetHeight = 2,
    this.radius = 2000,
  });

  /// Gözlemcinin konumu.
  final LatLng observer;

  /// Gözlemcinin yerden yüksekliği (m; ayakta ~2, kule 10–30).
  final double observerHeight;

  /// Görülmesi istenen hedefin yerden yüksekliği (m; 0 = zemin, 2 = insan).
  final double targetHeight;

  /// Yarıçap (m).
  final double radius;
}

/// Hücre durumları.
abstract final class ViewshedCell {
  static const noData = 0;
  static const hidden = 1;
  static const visible = 2;
}

/// Görüş alanı sonucu: kuzeyden güneye satırlar, batıdan doğuya sütunlar.
class ViewshedGrid {
  const ViewshedGrid({
    required this.size,
    required this.cellMeters,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.cells,
    required this.observerGround,
  });

  /// Kenar başına hücre (kare ızgara).
  final int size;
  final double cellMeters;
  final double north, south, east, west;

  /// [ViewshedCell] değerleri, `satır * size + sütun`.
  final Uint8List cells;

  /// Gözlemcinin bulunduğu yerin yüksekliği (m).
  final double observerGround;

  int _count(int v) => cells.where((c) => c == v).length;

  /// Görünen alan (km²).
  double get visibleKm2 =>
      _count(ViewshedCell.visible) * cellMeters * cellMeters / 1e6;

  /// Verisi olan alanın görünen oranı (0–1).
  double get visibleFraction {
    final v = _count(ViewshedCell.visible);
    final all = v + _count(ViewshedCell.hidden);
    return all == 0 ? 0 : v / all;
  }

  /// Haritaya ön-çarpılmış RGBA: görünen yeşil, görünmeyen kırmızı
  /// (yarı saydam), verisiz saydam.
  Uint8List toRgba() {
    final out = Uint8List(cells.length * 4);
    for (var i = 0; i < cells.length; i++) {
      final (r, g, b, a) = switch (cells[i]) {
        ViewshedCell.visible => (40, 220, 60, 0.38),
        ViewshedCell.hidden => (220, 40, 40, 0.30),
        _ => (0, 0, 0, 0.0),
      };
      out[i * 4] = (r * a).round();
      out[i * 4 + 1] = (g * a).round();
      out[i * 4 + 2] = (b * a).round();
      out[i * 4 + 3] = (255 * a).round();
    }
    return out;
  }
}

/// Görüş alanı hesabı (saf Dart; arka planda çalıştırılır).
///
/// Gözlemci çevresinde enlem/boylam eksenli kare ızgara; merkezden kenardaki
/// her hücreye ışın atılır, ışın boyunca o ana kadarki en dik ufuk açısı
/// izlenir: hedefin tepesi bu açının üstünde kalan hücre görünür. Dünya
/// eğriliği ve atmosfer kırılması (k = 0,13) düşülür.
class Viewshed {
  Viewshed._();

  static const _earthRadius = 6371008.8;
  static const refraction = 0.13;

  /// En çok hücre (kenar başına); arazi verisi ~30 m olduğundan küçük
  /// yarıçapta daha az hücre yeter.
  static const maxCells = 401;

  /// [elevation]: konumdaki arazi yüksekliği (m), veri yoksa null.
  /// Gözlemcinin yerinde veri yoksa null döner.
  static ViewshedGrid? compute(
    ViewshedParams p,
    double? Function(double lat, double lon) elevation,
  ) {
    final ground = elevation(p.observer.latitude, p.observer.longitude);
    if (ground == null) return null;
    final eye = ground + p.observerHeight;

    // Hücre: en az 30 m (veri çözünürlüğü), en çok maxCells hücre.
    var n = (2 * p.radius / 30).ceil() + 1;
    if (n > maxCells) n = maxCells;
    if (n.isEven) n++;
    final m = n ~/ 2;
    final cell = 2 * p.radius / (n - 1);

    final lat0 = p.observer.latitude, lon0 = p.observer.longitude;
    final latPerM = 180 / (math.pi * _earthRadius);
    final lonPerM = latPerM / math.cos(lat0 * math.pi / 180);

    final cells = Uint8List(n * n);
    final drop = (1 - refraction) / (2 * _earthRadius);

    void ray(int ti, int tj) {
      // ti/tj: hedef kenar hücresi (satır kuzeyden, sütun batıdan).
      final di = (ti - m).toDouble(), dj = (tj - m).toDouble();
      final steps = math.max(di.abs(), dj.abs()).round();
      if (steps == 0) return;
      var maxAngle = double.negativeInfinity;
      for (var k = 1; k <= steps; k++) {
        final fi = m + di * k / steps, fj = m + dj * k / steps;
        final dyM = (m - fi) * cell, dxM = (fj - m) * cell;
        final dist = math.sqrt(dxM * dxM + dyM * dyM);
        if (dist > p.radius) break;
        final e = elevation(lat0 + dyM * latPerM, lon0 + dxM * lonPerM);
        final idx = fi.round() * n + fj.round();
        if (e == null) continue;
        final curve = dist * dist * drop;
        final groundAngle = (e - curve - eye) / dist;
        final targetAngle = (e + p.targetHeight - curve - eye) / dist;
        if (targetAngle >= maxAngle) {
          cells[idx] = ViewshedCell.visible;
        } else if (cells[idx] != ViewshedCell.visible) {
          cells[idx] = ViewshedCell.hidden;
        }
        if (groundAngle > maxAngle) maxAngle = groundAngle;
      }
    }

    for (var t = 0; t < n; t++) {
      ray(0, t);
      ray(n - 1, t);
      ray(t, 0);
      ray(t, n - 1);
    }
    cells[m * n + m] = ViewshedCell.visible;

    return ViewshedGrid(
      size: n,
      cellMeters: cell,
      // Hücre merkezleri kenarda: resim yarım hücre taşar.
      north: lat0 + (m + 0.5) * cell * latPerM,
      south: lat0 - (m + 0.5) * cell * latPerM,
      east: lon0 + (m + 0.5) * cell * lonPerM,
      west: lon0 - (m + 0.5) * cell * lonPerM,
      cells: cells,
      observerGround: ground,
    );
  }
}
