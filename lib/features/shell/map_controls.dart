import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/engine/map_types.dart';
import 'atak_toolbar.dart' show kToolbarButtonSize;

/// Sol kenardaki harita kontrolleri (ATAK, kılavuz s.5–6), yukarıdan aşağı:
/// pusula oku · kendine ortala (◎) · yakınlaştır/uzaklaştır.
///
/// Pusula oku haritayla birlikte döner (kuzeyi gösterir).
/// - Dokun: kuzey-yukarı ↔ yön-yukarı.
/// - Uzun bas: yanında ek düğmeler açılır: döndürmeyi kilitle, 3B,
///   taktik pusula.
class MapSideControls extends StatefulWidget {
  const MapSideControls({
    super.key,
    required this.camera,
    required this.trackUp,
    required this.onToggleOrientation,
    required this.rotationLocked,
    required this.onToggleRotationLock,
    required this.following,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    this.onToggleTerrain,
    this.terrainOn = false,
    this.onTacticalCompass,
    this.night = false,
  });

  /// Haritanın anlık kamerası (pusula okunun açısı için).
  final ValueListenable<MapCameraState> camera;
  final bool trackUp;
  final VoidCallback onToggleOrientation;
  final bool rotationLocked;
  final VoidCallback onToggleRotationLock;
  final bool following;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// null → 3B düğmesi gösterilmez (motor desteklemiyor).
  final VoidCallback? onToggleTerrain;
  final bool terrainOn;

  /// null → taktik pusula düğmesi gösterilmez.
  final VoidCallback? onTacticalCompass;
  final bool night;

  @override
  State<MapSideControls> createState() => _MapSideControlsState();
}

class _MapSideControlsState extends State<MapSideControls> {
  bool _extras = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.night ? Colors.redAccent : Colors.amber;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompassButton(
              camera: widget.camera,
              trackUp: widget.trackUp,
              locked: widget.rotationLocked,
              accent: accent,
              night: widget.night,
              onTap: () {
                if (_extras) setState(() => _extras = false);
                widget.onToggleOrientation();
              },
              onLongPress: () => setState(() => _extras = !_extras),
            ),
            if (_extras) ...[
              const SizedBox(width: 8),
              _SquareButton(
                icon: widget.rotationLocked ? Icons.lock : Icons.lock_open,
                label: widget.rotationLocked
                    ? 'Döndürme kilitli (dokun: aç)'
                    : 'Döndürmeyi kilitle',
                active: widget.rotationLocked,
                accent: accent,
                night: widget.night,
                onTap: widget.onToggleRotationLock,
              ),
              if (widget.onToggleTerrain != null) ...[
                const SizedBox(width: 6),
                _SquareButton(
                  text: '3B',
                  label: widget.terrainOn ? '3B arazi (dokun: kapat)' : '3B arazi',
                  active: widget.terrainOn,
                  accent: accent,
                  night: widget.night,
                  onTap: widget.onToggleTerrain!,
                ),
              ],
              if (widget.onTacticalCompass != null) ...[
                const SizedBox(width: 6),
                _SquareButton(
                  icon: Icons.explore,
                  label: 'Taktik pusula',
                  active: false,
                  accent: accent,
                  night: widget.night,
                  onTap: () {
                    setState(() => _extras = false);
                    widget.onTacticalCompass!();
                  },
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 10),
        _SquareButton(
          icon: widget.following ? Icons.my_location : Icons.location_searching,
          label: 'Kendine ortala / takip et',
          active: widget.following,
          accent: Colors.lightBlueAccent,
          night: widget.night,
          onTap: widget.onRecenter,
        ),
        const SizedBox(height: 10),
        // Yakınlaştır / uzaklaştır: tek dikey hap (ATAK büyüteçleri).
        Material(
          color: Colors.black.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlainButton(
                  icon: Icons.add,
                  label: 'Yakınlaştır',
                  night: widget.night,
                  onTap: widget.onZoomIn),
              Container(width: 28, height: 1, color: Colors.white24),
              _PlainButton(
                  icon: Icons.remove,
                  label: 'Uzaklaştır',
                  night: widget.night,
                  onTap: widget.onZoomOut),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pusula oku: kırmızı kuzey oku haritanın dönüşüyle birlikte döner; harita
/// dönükse altında açısı yazar. Yön-yukarıda halka vurgulu, kilitliyken 🔒.
class _CompassButton extends StatelessWidget {
  const _CompassButton({
    required this.camera,
    required this.trackUp,
    required this.locked,
    required this.accent,
    required this.night,
    required this.onTap,
    required this.onLongPress,
  });

  final ValueListenable<MapCameraState> camera;
  final bool trackUp;
  final bool locked;
  final Color accent;
  final bool night;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: trackUp
          ? 'Pusula: yön-yukarı (dokun: kuzey-yukarı, uzun bas: seçenekler)'
          : 'Pusula: kuzey-yukarı (dokun: yön-yukarı, uzun bas: seçenekler)',
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        shape: CircleBorder(
          side: BorderSide(
              color: trackUp ? accent : Colors.white24, width: trackUp ? 2 : 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.heavyImpact();
            onLongPress();
          },
          child: SizedBox(
            width: kToolbarButtonSize,
            height: kToolbarButtonSize,
            child: ValueListenableBuilder<MapCameraState>(
              valueListenable: camera,
              builder: (context, cam, _) {
                final bearing = ((cam.bearing % 360) + 360) % 360;
                final rotated = bearing > 0.5 && bearing < 359.5;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -bearing * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(24, 30),
                        painter: _NorthArrowPainter(night: night),
                      ),
                    ),
                    if (rotated)
                      Positioned(
                        bottom: 1,
                        child: Text('${bearing.round()}°',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (locked)
                      const Positioned(
                        top: 2,
                        right: 4,
                        child: Icon(Icons.lock, size: 11, color: Colors.white70),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NorthArrowPainter extends CustomPainter {
  _NorthArrowPainter({required this.night});
  final bool night;

  @override
  void paint(Canvas canvas, Size s) {
    final north = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height / 2)
      ..lineTo(0, s.height / 2)
      ..close();
    final south = Path()
      ..moveTo(0, s.height / 2)
      ..lineTo(s.width, s.height / 2)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(
        north, Paint()..color = night ? Colors.redAccent : Colors.red);
    canvas.drawPath(south,
        Paint()..color = night ? Colors.red.shade900 : Colors.white70);
  }

  @override
  bool shouldRepaint(_NorthArrowPainter old) => old.night != night;
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    this.icon,
    this.text,
    required this.label,
    required this.onTap,
    this.active = false,
    this.accent = Colors.amber,
    this.night = false,
  });

  final IconData? icon;
  final String? text;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color accent;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.black : (night ? Colors.red.shade200 : Colors.white);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: active ? accent : Colors.black.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: kToolbarButtonSize,
            height: kToolbarButtonSize,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: fg, size: 24)
                  : Text(text ?? '',
                      style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlainButton extends StatelessWidget {
  const _PlainButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.night = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: kToolbarButtonSize,
          height: kToolbarButtonSize,
          child: Icon(icon,
              color: night ? Colors.red.shade200 : Colors.white, size: 26),
        ),
      ),
    );
  }
}

/// Haritanın ortasındaki artı imleç (eldivenle nokta koymak için).
class MapCrosshair extends StatelessWidget {
  const MapCrosshair({super.key, this.night = false});
  final bool night;

  @override
  Widget build(BuildContext context) {
    final c = night ? Colors.redAccent : Colors.amber;
    return IgnorePointer(
      child: Center(
        child: CustomPaint(size: const Size(36, 36), painter: _CrossPainter(c)),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final halo = Paint()
      ..color = Colors.black54
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const gap = 4.0;
    final r = size.width / 2;
    for (final p in [halo, line]) {
      canvas.drawLine(c.translate(-r, 0), c.translate(-gap, 0), p);
      canvas.drawLine(c.translate(gap, 0), c.translate(r, 0), p);
      canvas.drawLine(c.translate(0, -r), c.translate(0, -gap), p);
      canvas.drawLine(c.translate(0, gap), c.translate(0, r), p);
    }
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}
