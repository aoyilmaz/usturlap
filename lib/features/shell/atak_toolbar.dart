import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Araç çubuğu düğmesi (eldivenle basılabilecek büyüklükte).
const double kToolbarButtonSize = 48;

/// Araç çubuğunun toplam yüksekliği (kenar boşluğu dahil).
const double kAtakToolbarHeight = kToolbarButtonSize + 8;

/// Araç çubuğundaki bir düğme. Harita ekranı seçili araçlardan üretir
/// (bkz. `ToolbarTool`); etiket erişilebilirlik adıdır.
class ToolbarItem {
  const ToolbarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.accent,
    this.activeForeground = Colors.black,
    this.haptic = HapticFeedback.selectionClick,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Açık/çalışan araç (vurgulu arka plan).
  final bool active;

  /// Vurgu rengi (null: gündüz sarı, gece kırmızı).
  final Color? accent;
  final Color activeForeground;
  final Future<void> Function() haptic;
}

/// ATAK araç çubuğu (kılavuz s.5): haritanın üstünde, solda ≡, yanında
/// kullanıcının seçtiği araçlar (Toolbar Manager, s.55–57).
///
/// ≡ bütün araçların ızgarasını açar; ≡'ye uzun basınca çubuk gizlenir.
/// Bir araca uzun basınca [onEdit] (Araç çubuğu paneli: ekle/çıkar/sırala).
class AtakToolbar extends StatelessWidget {
  const AtakToolbar({
    super.key,
    required this.onMenu,
    required this.onHide,
    required this.items,
    this.onEdit,
    this.night = false,
  });

  final VoidCallback onMenu;
  final VoidCallback onHide;
  final List<ToolbarItem> items;
  final VoidCallback? onEdit;
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
        if (items.isNotEmpty) const _Divider(),
        for (final item in items)
          _ToolbarButton(
            icon: item.icon,
            label: item.label,
            active: item.active,
            accent: item.accent ?? accent,
            activeForeground: item.activeForeground,
            onTap: item.onTap,
            onLongPress: onEdit,
            night: night,
            haptic: item.haptic,
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
