import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Radyal menüdeki bir eylem.
class RadialAction {
  const RadialAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;

  /// Kısa ad (düğmenin içinde yazar; erişilebilirlik adı da budur).
  final String label;
  final VoidCallback onTap;

  /// Özel renk (ör. Sil kırmızı).
  final Color? color;
}

/// ATAK Radial Menu (kılavuz s.11): nesneye dokununca etrafında halka
/// biçiminde eylemler. Düğmeler eldivenle seçilebilecek büyüklükte.
///
/// Ekranı kaplar ama dokunuşları yutmaz: halkanın dışına dokunmak menüyü
/// kapatır ve dokunuş alttaki haritaya / düğmelere de geçer (başka bir
/// nesneye dokununca onun menüsü açılır, harita kaydırılabilir).
class RadialMenu extends StatelessWidget {
  const RadialMenu({
    super.key,
    required this.center,
    required this.title,
    required this.actions,
    required this.onDismiss,
    this.night = false,
  });

  /// Nesnenin ekran konumu (haritayla aynı koordinatlar).
  final Offset center;

  /// Ortada yazan nesne adı.
  final String title;
  final List<RadialAction> actions;
  final VoidCallback onDismiss;
  final bool night;

  /// Düğme çapı (eldiven: ≥ 48 pt).
  static const double buttonSize = 64;

  /// Düğme merkezlerinin halka yarıçapı (8 düğme sığar: 2π·100 > 8 × 72).
  static const double radius = 100;

  /// Halkanın dış yarıçapı.
  static const double extent = radius + buttonSize / 2;

  /// Halka ekrandan taşmasın diye merkez içeri kaydırılır.
  static Offset clampCenter(Offset c, Size size, EdgeInsets safe) {
    double clamp(double v, double lo, double hi) =>
        lo > hi ? (lo + hi) / 2 : v.clamp(lo, hi);
    return Offset(
      clamp(c.dx, safe.left + extent + 4, size.width - safe.right - extent - 4),
      clamp(
        c.dy,
        safe.top + extent + 4,
        size.height - safe.bottom - extent - 4,
      ),
    );
  }

  /// i. düğmenin merkezi: üstten başlayıp saat yönünde.
  static Offset buttonCenter(Offset c, int i, int n) {
    final a = 2 * math.pi * i / n;
    return c + Offset(math.sin(a), -math.cos(a)) * radius;
  }

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    final idle = night ? Colors.red.shade200 : Colors.white;
    return LayoutBuilder(
      builder: (context, box) {
        final c = clampCenter(
          center,
          box.biggest,
          MediaQuery.paddingOf(context),
        );
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Stack(
            children: [
              // Dışarıya dokunuş: menüyü kapat, dokunuş alttakilere de geçsin.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => onDismiss(),
                ),
              ),
              // Nesneden düğmelere ince çizgiler: hangi nesnenin menüsü belli.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RingPainter(
                      center: c,
                      object: center,
                      radius: radius * t,
                      color: accent,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < actions.length; i++)
                _button(
                  Offset.lerp(c, buttonCenter(c, i, actions.length), t)!,
                  actions[i],
                  accent: accent,
                  idle: idle,
                  opacity: t,
                ),
              _title(c, accent),
            ],
          ),
        );
      },
    );
  }

  Widget _button(
    Offset at,
    RadialAction a, {
    required Color accent,
    required Color idle,
    required double opacity,
  }) {
    final fg = a.color ?? idle;
    return Positioned(
      left: at.dx - buttonSize / 2,
      top: at.dy - buttonSize / 2,
      width: buttonSize,
      height: buttonSize,
      child: Opacity(
        opacity: ((opacity - 0.6) / 0.4).clamp(0, 1),
        child: Semantics(
          button: true,
          label: a.label,
          excludeSemantics: true,
          child: Material(
            color: Colors.black.withValues(alpha: 0.82),
            shape: CircleBorder(
              side: BorderSide(
                color: accent.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                // Önce menü kapanır, sonra eylem (eylem panel/diyalog açabilir).
                onDismiss();
                a.onTap();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.icon, color: fg, size: 24),
                  const SizedBox(height: 2),
                  Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 10.5, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ortada nesne adı; dokununca menü kapanır.
  Widget _title(Offset c, Color accent) {
    const w = 120.0;
    return Positioned(
      left: c.dx - w / 2,
      top: c.dy - 16,
      width: w,
      height: 32,
      child: Center(
        child: GestureDetector(
          onTap: onDismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.6)),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Halka çizgisi; merkez ekran kenarı yüzünden kaydırıldıysa nesneye bir
/// bağlantı çizgisi (menünün hangi nesneye ait olduğu belli olsun).
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.center,
    required this.object,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final Offset object;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.45);
    canvas.drawCircle(center, radius, ring);
    if ((object - center).distance > 4) {
      final link = Paint()
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.8);
      canvas.drawLine(center, object, link);
      canvas.drawCircle(object, 5, link);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.center != center ||
      old.object != object ||
      old.radius != radius ||
      old.color != color;
}
