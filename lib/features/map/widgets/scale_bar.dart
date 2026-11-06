import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ölçek çubuğu hesabı (saf, test edilir).
class ScaleBarMath {
  ScaleBarMath._();

  /// Mapbox zoom'u 512 pikselik karolara dayanır: zoom 0'da dünya 512 px.
  /// Ekvatorda zoom 0'da 1 mantıksal piksel = 2πR / 512 metre.
  static const double _metersPerPxZ0 = 2 * math.pi * 6378137 / 512;

  /// Haritanın ortasında 1 mantıksal pikselin metre karşılığı.
  static double metersPerPixel(double zoom, double latitudeDeg) =>
      _metersPerPxZ0 *
      math.cos(latitudeDeg * math.pi / 180) /
      math.pow(2, zoom);

  /// [maxPx] genişliğe sığan en büyük "yuvarlak" mesafe (1, 2, 5 × 10ⁿ m).
  static ({double meters, double pixels}) pick(
    double zoom,
    double latitudeDeg, {
    double maxPx = 110,
  }) {
    final mpp = metersPerPixel(zoom, latitudeDeg);
    final maxMeters = mpp * maxPx;
    final base = math
        .pow(10, (math.log(maxMeters) / math.ln10).floor())
        .toDouble();
    var nice = base;
    for (final f in const [5, 2, 1]) {
      if (f * base <= maxMeters) {
        nice = f * base;
        break;
      }
    }
    return (meters: nice, pixels: nice / mpp);
  }

  /// 500 → "500 m", 2000 → "2 km", 0.5 → "0.5 m".
  static String label(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km == km.roundToDouble() ? km.round() : km} km';
    }
    if (meters >= 1) return '${meters.round()} m';
    return '$meters m';
  }
}

/// Haritanın sol altında sürekli görünen ölçek çubuğu (ATAK Map Scale, s.5).
///
/// Mapbox'ın kendi çubuğu iOS'ta yalnızca zoom sırasında görünür ve renkleri
/// ayarlanamaz; bu yüzden kendimiz çiziyoruz. 3B (eğik) görünümde değer
/// haritanın ortası için yaklaşıktır.
class MapScaleBar extends StatelessWidget {
  const MapScaleBar({
    super.key,
    required this.zoom,
    required this.latitude,
    this.night = false,
  });

  final double zoom;
  final double latitude;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final s = ScaleBarMath.pick(zoom, latitude);
    final color = night ? Colors.redAccent : Colors.white;
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ScaleBarMath.label(s.meters),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
          const SizedBox(height: 2),
          CustomPaint(size: Size(s.pixels, 8), painter: _BarPainter(color)),
        ],
      ),
    );
  }
}

/// "|____|" biçimli çubuk; uydu görüntüsünde okunsun diye siyah kenarlı.
class _BarPainter extends CustomPainter {
  _BarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0);
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.square;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    canvas.drawPath(path, outline);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.color != color;
}
