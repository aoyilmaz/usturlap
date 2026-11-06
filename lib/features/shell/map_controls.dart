import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sağ kenardaki harita kontrolleri (Kerteriz tarzı, yukarıdan aşağı):
/// Ayarlar · Katmanlar · 3B · Ekle (+) · Konum/takip · Kuzey/yön.
class MapControlsColumn extends StatelessWidget {
  const MapControlsColumn({
    super.key,
    required this.onSettings,
    required this.onLayers,
    required this.onAdd,
    required this.addLabel,
    required this.onRecenter,
    required this.following,
    required this.onOrientation,
    required this.trackUp,
    this.onTerrain,
    this.terrainOn = false,
    this.night = false,
    this.compact = false,
  });

  /// Yatay ekranda daha küçük düğmeler (yükseklik az).
  final bool compact;

  final VoidCallback onSettings;
  final VoidCallback onLayers;

  /// Artı imlecin altına nokta ekle (araç açıksa araç noktası).
  final VoidCallback onAdd;
  final String addLabel;
  final VoidCallback onRecenter;
  final bool following;
  final VoidCallback onOrientation;
  final bool trackUp;

  /// null → 3B düğmesi gösterilmez (motor desteklemiyor).
  final VoidCallback? onTerrain;
  final bool terrainOn;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapButton(
            icon: Icons.settings, tooltip: 'Ayarlar', onTap: onSettings, compact: compact),
        _MapButton(
            icon: Icons.layers, tooltip: 'Katmanlar', onTap: onLayers, compact: compact),
        if (onTerrain != null)
          _MapButton(
            label: '3B',
            tooltip: terrainOn ? '3B arazi (dokun: kapat)' : '3B arazi',
            active: terrainOn,
            accent: accent,
            onTap: onTerrain!,
            compact: compact,
          ),
        _MapButton(
          icon: Icons.add_location_alt,
          tooltip: addLabel,
          accent: accent,
          onTap: onAdd,
          compact: compact,
        ),
        _MapButton(
          icon: following ? Icons.my_location : Icons.location_searching,
          tooltip: 'Konuma ortala / takip',
          active: following,
          accent: Colors.lightBlueAccent,
          onTap: onRecenter,
          compact: compact,
        ),
        _MapButton(
          icon: trackUp ? Icons.navigation : Icons.explore,
          tooltip: trackUp ? 'Yön-yukarı (dokun: kuzey)' : 'Kuzey-yukarı',
          active: trackUp,
          accent: accent,
          onTap: onOrientation,
          compact: compact,
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.accent = Colors.amber,
    this.compact = false,
  });

  final bool compact;
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.black : Colors.white;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active ? accent : Colors.black.withValues(alpha: 0.72),
          shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              width: compact ? 42 : 48,
              height: compact ? 42 : 48,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: fg, size: 24)
                    : Text(label ?? '',
                        style: TextStyle(
                            color: fg, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
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
