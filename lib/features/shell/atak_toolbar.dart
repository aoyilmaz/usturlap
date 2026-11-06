import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Araç çubuğu düğmesi (eldivenle basılabilecek büyüklükte).
const double kToolbarButtonSize = 48;

/// Araç çubuğunun toplam yüksekliği (kenar boşluğu dahil).
const double kAtakToolbarHeight = kToolbarButtonSize + 8;

/// ATAK araç çubuğu (kılavuz s.5): haritanın üstünde, solda ≡.
///
/// ≡ bütün araçların ızgarasını açar; ≡'ye uzun basınca çubuk gizlenir.
/// Sıra: ≡ · Nokta bırak · Ölçüm (R&B) · Koordinat/Git · Haritalar · İz kaydı.
class AtakToolbar extends StatelessWidget {
  const AtakToolbar({
    super.key,
    required this.onMenu,
    required this.onHide,
    required this.onDropPoint,
    required this.onMeasure,
    required this.onGoTo,
    required this.onMaps,
    required this.onRecord,
    this.dropActive = false,
    this.measureActive = false,
    this.recording = false,
    this.night = false,
  });

  final VoidCallback onMenu;
  final VoidCallback onHide;
  final VoidCallback onDropPoint;
  final VoidCallback onMeasure;
  final VoidCallback onGoTo;
  final VoidCallback onMaps;
  final VoidCallback onRecord;
  final bool dropActive;
  final bool measureActive;
  final bool recording;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    return _Bar(
      night: night,
      children: [
        _ToolbarButton(
          icon: Icons.menu,
          label: 'Bütün araçlar',
          onTap: onMenu,
          onLongPress: onHide,
          night: night,
        ),
        const _Divider(),
        _ToolbarButton(
          icon: Icons.add_location_alt_outlined,
          label: 'Nokta bırak',
          active: dropActive,
          accent: accent,
          onTap: onDropPoint,
          night: night,
        ),
        _ToolbarButton(
          icon: Icons.straighten,
          label: 'Ölçüm (R&B)',
          active: measureActive,
          accent: accent,
          onTap: onMeasure,
          night: night,
        ),
        _ToolbarButton(
          icon: Icons.travel_explore,
          label: 'Koordinat / Git',
          onTap: onGoTo,
          night: night,
        ),
        _ToolbarButton(
          icon: Icons.map_outlined,
          label: 'Haritalar',
          onTap: onMaps,
          night: night,
        ),
        _ToolbarButton(
          icon: recording ? Icons.stop_circle : Icons.radio_button_checked,
          label: recording ? 'İz kaydını durdur' : 'İz kaydını başlat',
          active: recording,
          accent: Colors.red.shade700,
          activeForeground: Colors.white,
          onTap: onRecord,
          night: night,
          haptic: HapticFeedback.mediumImpact,
        ),
      ],
    );
  }
}

/// Çubuk gizliyken sol üstte kalan küçük ≡ (dokun → çubuğu geri getir).
class AtakToolbarHandle extends StatelessWidget {
  const AtakToolbarHandle({
    super.key,
    required this.onShow,
    this.night = false,
  });

  final VoidCallback onShow;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return _Bar(
      night: night,
      children: [
        _ToolbarButton(
          icon: Icons.menu,
          label: 'Araç çubuğunu göster',
          onTap: onShow,
          night: night,
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.children, required this.night});

  final List<Widget> children;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: night ? Colors.red.withValues(alpha: 0.5) : Colors.white24,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: kToolbarButtonSize - 16,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    color: Colors.white24,
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.accent = Colors.amber,
    this.activeForeground = Colors.black,
    this.night = false,
    this.haptic = HapticFeedback.selectionClick,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final Color accent;
  final Color activeForeground;
  final bool night;
  final Future<void> Function() haptic;

  @override
  Widget build(BuildContext context) {
    final idle = night ? Colors.red.shade200 : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: active ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            haptic();
            onTap();
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  onLongPress!();
                },
          child: SizedBox(
            width: kToolbarButtonSize,
            height: kToolbarButtonSize,
            child: Icon(
              icon,
              size: 26,
              color: active ? activeForeground : idle,
            ),
          ),
        ),
      ),
    );
  }
}
