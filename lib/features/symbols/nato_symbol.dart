import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/waypoint.dart';

/// Görev noktası rozet rengi (mor: sadakat renkleriyle karışmasın). ATAK'a
/// giden işaretçi de bu renkte (`CotMapper.missionColor`).
const missionColor = Color(0xFFB04CFF);

/// Tür rengi: APP-6 sadakat çerçevesi, görev noktası rozeti ya da iğne.
Color affiliationColor(Affiliation a) => switch (a) {
  Affiliation.friend || Affiliation.assumedFriend => const Color(0xFF2E7DFF),
  Affiliation.hostile || Affiliation.suspect => const Color(0xFFE03131),
  Affiliation.neutral => const Color(0xFF2FB344),
  Affiliation.unknown => const Color(0xFFF2B500),
  Affiliation.waypoint => const Color(0xFFE03131),
  Affiliation.observationPost ||
  Affiliation.checkpoint ||
  Affiliation.rallyPoint ||
  Affiliation.sensor => missionColor,
};

/// Görev noktası rozetindeki ikon.
IconData missionIcon(Affiliation a) => switch (a) {
  Affiliation.observationPost => Icons.visibility,
  Affiliation.checkpoint => Icons.flag,
  Affiliation.rallyPoint => Icons.groups,
  Affiliation.sensor => Icons.sensors,
  _ => Icons.location_on,
};

/// Her nokta türünü çizen tek widget: sade nokta = kırmızı iğne, görev
/// noktası = mor rozet + ikon, sadakat = APP-6 çerçevesi ([NatoSymbol]).
class PointSymbol extends StatelessWidget {
  const PointSymbol({
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
    if (affiliation.isNato) {
      return NatoSymbol(
        affiliation: affiliation,
        echelon: echelon,
        role: role,
        size: size,
      );
    }
    if (affiliation.isMission) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: missionColor, width: size * 0.075),
            ),
            child: Icon(
              missionIcon(affiliation),
              color: missionColor,
              size: size * 0.55,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.location_on, color: Colors.redAccent, size: size),
    );
  }
}

/// Bir APP-6 sembolünü çizen küçük widget: sadakat çerçevesi + isteğe bağlı
/// echelon (büyüklük, çerçeve üstü) + ana ikon (rol, çerçeve içi).
/// dost = dikdörtgen, düşman = eşkenar dörtgen, nötr = kare,
/// bilinmeyen = dörtyaprak (quatrefoil). Varsayılan dost / şüpheli: dost /
/// düşman çerçevesi kesik çizgiyle (MIL-STD-2525D kesinleşmemiş kimlik).
/// Sade nokta ve görev noktaları için [PointSymbol] kullanılır.
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
    canvas.drawPath(
      affiliation.isUncertain ? _dashed(path, r * 0.34, r * 0.22) : path,
      stroke,
    );

    if (role != SymbolRole.none) _paintRole(canvas, color, c, r);
    if (hasEchelon) {
      _paintEchelon(canvas, color, Offset(size.width / 2, topReserve / 2), size);
    }
  }

  ui.Path _framePath(Affiliation a, Offset c, double r) {
    switch (a) {
      case Affiliation.friend:
      case Affiliation.assumedFriend:
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
      case Affiliation.suspect:
        // Eşkenar dörtgen (45° kare).
        return ui.Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
      case Affiliation.unknown:
      case Affiliation.waypoint:
      case Affiliation.observationPost:
      case Affiliation.checkpoint:
      case Affiliation.rallyPoint:
      case Affiliation.sensor:
        // Dörtyaprak (4 lob birleşimi). NATO olmayan türler buraya
        // gelmez ([PointSymbol] kendi çizer); yine de bir çerçeve olsun.
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

  /// Çerçeveyi kesik çizgiye çevirir (eşit aralıklı parçalar).
  static ui.Path _dashed(ui.Path src, double dash, double gap) {
    final out = ui.Path();
    for (final m in src.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        out.addPath(
          m.extractPath(d, math.min(d + dash, m.length)),
          Offset.zero,
        );
      }
    }
    return out;
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
      case SymbolRole.mine:
        // Dolu daire + 8 diken (topçunun düz noktasından ayrılsın).
        canvas.drawCircle(c, g * 0.5, Paint()..color = color);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final u = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + u * (g * 0.5), c + u * (g * 0.95), p);
        }
      case SymbolRole.cbrn:
        // Çapraz iki imbik: ✕ ve alt uçlarda birer hazne.
        final bulb = g * 0.28;
        for (final sx in [-1.0, 1.0]) {
          final top = c + Offset(sx * g * 0.85, -g * 0.85);
          final bottom = c + Offset(-sx * g * 0.55, g * 0.55);
          canvas.drawLine(top, bottom, p);
          canvas.drawCircle(
            bottom + Offset(-sx * bulb * 0.7, bulb * 0.7),
            bulb,
            Paint()..color = color,
          );
        }
      case SymbolRole.barrier:
        // Zikzak (tel örgü / duvar hattı).
        final zig = ui.Path()..moveTo(c.dx - g, c.dy + g * 0.3);
        for (var i = 1; i <= 4; i++) {
          zig.lineTo(
            c.dx - g + i * g / 2,
            c.dy + (i.isOdd ? -g * 0.3 : g * 0.3),
          );
        }
        canvas.drawPath(zig, p);
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
