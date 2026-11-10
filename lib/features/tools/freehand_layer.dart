import 'package:flutter/material.dart';

import '../../core/polyline_simplify.dart';

/// Serbest çizim (ATAK Telestrate, kılavuz s.42) için haritanın üstündeki
/// yakalama katmanı: parmak izi anında çizilir; parmak kalkınca
/// sadeleştirilmiş ekran noktaları [onDone]'a verilir (konuma çevirmek
/// çağıranın işi). Katman açıkken harita kaymaz.
class FreehandLayer extends StatefulWidget {
  const FreehandLayer({super.key, required this.color, required this.onDone});

  final Color color;
  final Future<void> Function(List<Offset> points) onDone;

  /// Sadeleştirme toleransı (mantıksal piksel).
  static const tolerance = 2.5;

  @override
  State<FreehandLayer> createState() => _FreehandLayerState();
}

class _FreehandLayerState extends State<FreehandLayer> {
  List<Offset> _path = const [];

  void _add(Offset p) {
    // 2 pt'den yakın noktalar gürültü.
    if (_path.isNotEmpty && (p - _path.last).distance < 2) return;
    setState(() => _path = [..._path, p]);
  }

  Future<void> _end() async {
    final raw = _path;
    if (raw.length < 2) {
      setState(() => _path = const []);
      return;
    }
    final simple = simplifyPolyline([
      for (final o in raw) (o.dx, o.dy),
    ], FreehandLayer.tolerance);
    await widget.onDone([for (final (x, y) in simple) Offset(x, y)]);
    // Haritadaki çizgi gelene kadar iz ekranda kalsın (parlama olmasın).
    if (mounted) setState(() => _path = const []);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Serbest çizim alanı',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => setState(() => _path = [d.localPosition]),
        onPanUpdate: (d) => _add(d.localPosition),
        onPanEnd: (_) => _end(),
        child: CustomPaint(
          painter: _PathPainter(_path, widget.color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.path, this.color);

  final List<Offset> path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final p = Path()..moveTo(path.first.dx, path.first.dy);
    for (final o in path.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.path != path || old.color != color;
}
