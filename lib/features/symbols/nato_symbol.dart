import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/waypoint.dart';

/// APP-6 / MIL-STD-2525 sadakat çerçevesi rengi.
Color affiliationColor(Affiliation a) {
  switch (a) {
    case Affiliation.friend:
      return const Color(0xFF2E7DFF); // mavi
    case Affiliation.hostile:
      return const Color(0xFFE03131); // kırmızı
    case Affiliation.neutral:
      return const Color(0xFF2FB344); // yeşil
    case Affiliation.unknown:
      return const Color(0xFFF2B500); // sarı
    case Affiliation.waypoint:
      return const Color(0xFFE03131);
  }
}

/// Bir APP-6 sembolünü çizen küçük widget: sadakat çerçevesi + isteğe bağlı
/// echelon (büyüklük, çerçeve üstü) + ana ikon (rol, çerçeve içi).
/// dost = dikdörtgen, düşman = eşkenar dörtgen, nötr = kare,
/// bilinmeyen = dörtyaprak (quatrefoil).
class NatoSymbol extends StatelessWidget {
  const NatoSymbol({
    super.key,
    required this.affiliation,
    this.echelon = Echelon.none,
    this.role = SymbolRole.none,
    this.size = 30,
  });

  final Affiliation affiliation;
  final Echelon echelon;
  final SymbolRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FramePainter(affiliation, echelon, role)),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.affiliation, this.echelon, this.role);

  final Affiliation affiliation;
  final Echelon echelon;
  final SymbolRole role;

  @override
  void paint(Canvas canvas, Size size) {
    final color = affiliationColor(affiliation);

    // Echelon varsa üstte bir şerit ayır, çerçeveyi aşağı/küçült.
    final hasEchelon = echelon != Echelon.none;
    final topReserve = hasEchelon ? size.height * 0.22 : 0.0;
    final c = Offset(size.width / 2, topReserve + (size.height - topReserve) / 2);
    final r = (size.height - topReserve) / 2 * 0.86;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.35);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final path = _framePath(affiliation, c, r);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    if (role != SymbolRole.none) _paintRole(canvas, color, c, r);
    if (hasEchelon) {
      _paintEchelon(canvas, color, Offset(size.width / 2, topReserve / 2), size);
    }
  }

  ui.Path _framePath(Affiliation a, Offset c, double r) {
    switch (a) {
      case Affiliation.friend:
        // Dikdörtgen (en > boy).
        final rect = Rect.fromCenter(
            center: c, width: r * 2, height: r * 1.45);
        return ui.Path()..addRect(rect);
      case Affiliation.neutral:
        // Kare.
        final rect =
            Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.7);
        return ui.Path()..addRect(rect);
      case Affiliation.hostile:
        // Eşkenar dörtgen (45° kare).
        return ui.Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
      case Affiliation.waypoint:
      case Affiliation.unknown:
        // Dörtyaprak (4 lob birleşimi).
        final lr = r * 0.62;
        final d = r * 0.55;
        ui.Path p = ui.Path()
          ..addOval(Rect.fromCircle(center: c + Offset(-d, -d), radius: lr));
        for (final o in [Offset(d, -d), Offset(d, d), Offset(-d, d)]) {
          p = ui.Path.combine(ui.PathOperation.union, p,
              ui.Path()..addOval(Rect.fromCircle(center: c + o, radius: lr)));
        }
        return p;
    }
  }

  /// Çerçeve içi ana ikon (rol).
  void _paintRole(Canvas canvas, Color color, Offset c, double r) {
    final g = r * 0.5;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (role) {
      case SymbolRole.infantry:
        // ✕
        canvas.drawLine(c + Offset(-g, -g), c + Offset(g, g), p);
        canvas.drawLine(c + Offset(-g, g), c + Offset(g, -g), p);
      case SymbolRole.armor:
        // yatay oval
        canvas.drawOval(
            Rect.fromCenter(center: c, width: g * 2.2, height: g * 1.2), p);
      case SymbolRole.artillery:
        // ● dolu nokta
        canvas.drawCircle(c, g * 0.55, Paint()..color = color);
      case SymbolRole.recon:
        // / çapraz çizgi
        canvas.drawLine(c + Offset(-g, g), c + Offset(g, -g), p);
      case SymbolRole.none:
        break;
    }
  }

  /// Çerçeve üstü büyüklük amplifikatörü (echelon).
  void _paintEchelon(Canvas canvas, Color color, Offset center, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillDot = Paint()..color = color;
    final unit = size.width * 0.07; // işaret birimi
    switch (echelon) {
      case Echelon.team:
        // Ø — küçük çember
        canvas.drawCircle(center, unit, p);
      case Echelon.squad:
        // ••• — 3 dolu nokta
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(
              center + Offset(i * unit * 1.4, 0), unit * 0.5, fillDot);
        }
      case Echelon.company:
        // I — 1 dikey çubuk
        canvas.drawLine(
            center + Offset(0, -unit), center + Offset(0, unit), p);
      case Echelon.battalion:
        // II — 2 dikey çubuk
        canvas.drawLine(center + Offset(-unit * 0.8, -unit),
            center + Offset(-unit * 0.8, unit), p);
        canvas.drawLine(center + Offset(unit * 0.8, -unit),
            center + Offset(unit * 0.8, unit), p);
      case Echelon.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.affiliation != affiliation ||
      old.echelon != echelon ||
      old.role != role;
}
