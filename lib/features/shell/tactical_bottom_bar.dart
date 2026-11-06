import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Alt çubuğun yüksekliği (güvenli alan hariç). Harita ornamentleri, sağ
/// kontroller ve kartlar bunun üstüne yerleşir.
const double kBottomBarHeight = 72;

/// Yatay ekranda alt çubuğun dönüştüğü sol şeridin genişliği.
const double kSideRailWidth = 76;

/// Kerteriz tarzı alt çubuk: Koordinat · Araçlar · ● İz · Rota · Görevler.
///
/// Ortadaki büyük düğme iz kaydını başlatır/durdurur (en sık kullanılan iş,
/// başparmağın en kolay eriştiği yer). Hedefler eldivenle basılabilecek kadar
/// büyüktür (≥ 56 pt).
class TacticalBottomBar extends StatelessWidget {
  const TacticalBottomBar({
    super.key,
    required this.recording,
    required this.toolActive,
    required this.navActive,
    required this.onCoordinate,
    required this.onTools,
    required this.onRecord,
    required this.onRoute,
    required this.onMissions,
    this.night = false,
    this.vertical = false,
  });

  final bool recording;
  final bool toolActive;
  final bool navActive;
  final VoidCallback onCoordinate;
  final VoidCallback onTools;
  final VoidCallback onRecord;
  final VoidCallback onRoute;
  final VoidCallback onMissions;
  final bool night;

  /// true → yatay ekranda sol kenarda dikey şerit (ATAK gibi).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        top: vertical,
        right: !vertical,
        child: SizedBox(
          height: vertical ? double.infinity : kBottomBarHeight,
          width: vertical ? kSideRailWidth : double.infinity,
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            children: [
              _Tab(
                  icon: Icons.my_location,
                  label: 'Koordinat',
                  onTap: onCoordinate),
              _Tab(
                  icon: Icons.straighten,
                  label: 'Araçlar',
                  active: toolActive,
                  accent: accent,
                  onTap: onTools),
              Expanded(
                child: Center(
                  child: _RecordButton(
                      recording: recording, accent: accent, onTap: onRecord),
                ),
              ),
              _Tab(
                  icon: Icons.alt_route,
                  label: 'Rota',
                  active: navActive,
                  accent: accent,
                  onTap: onRoute),
              _Tab(
                  icon: Icons.folder_open,
                  label: 'Görevler',
                  onTap: onMissions),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.accent = Colors.amber,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Colors.white70;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton(
      {required this.recording, required this.accent, required this.onTap});

  final bool recording;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'İz kaydını durdur' : 'İz kaydını başlat',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? Colors.red.shade700 : Colors.black,
            border: Border.all(color: recording ? Colors.white : accent, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(recording ? Icons.stop : Icons.play_arrow,
                  color: recording ? Colors.white : accent, size: 28),
              Text(recording ? 'Durdur' : 'İz',
                  style: TextStyle(
                      color: recording ? Colors.white : accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
