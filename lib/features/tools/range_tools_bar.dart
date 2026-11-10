import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_providers.dart';
import '../../providers/tool_providers.dart';
import '../shell/atak_toolbar.dart' show kToolbarButtonSize;
import 'tool_banner.dart';

/// Ölçüm araçları çubuğu — ATAK "Range Tools" (kılavuz s.12): ana araç
/// çubuğunun altında küçük bir çubuk. Araca dokun → açılır (sarı), tekrar
/// dokun → kapanır. Altında aktif aracın ölçümü (ToolBanner).
///
/// ✕ çubuğu kapatır ve aracı sıfırlar.
class RangeToolsBar extends ConsumerWidget {
  const RangeToolsBar({
    super.key,
    required this.onClose,
    this.tools = rangeTools,
    this.closeLabel = 'Ölçüm araçlarını kapat',
    this.hint = 'Bir ölçüm aracı seçin',
  });

  final VoidCallback onClose;
  final List<(ToolMode, IconData, String)> tools;
  final String closeLabel;
  final String hint;

  /// Çizim araçları çubuğu (ATAK Drawing Tools, kılavuz s.40–42).
  const RangeToolsBar.drawing({super.key, required this.onClose})
    : tools = drawTools,
      closeLabel = 'Çizim araçlarını kapat',
      hint = 'Bir çizim aracı seçin';

  /// Ölçüm araçları (ATAK sırası: halka, R&B çizgisi; Pusula'nın diğerleri).
  static const rangeTools = <(ToolMode, IconData, String)>[
    (ToolMode.rangeRings, Icons.radar, 'Menzil halkası'),
    (ToolMode.distance, Icons.straighten, 'Mesafe / R&B çizgisi'),
    (ToolMode.polygon, Icons.pentagon_outlined, 'Alan'),
    (ToolMode.sector, Icons.pie_chart_outline, 'Sektör'),
    (ToolMode.lineOfSight, Icons.landscape_outlined, 'Görüş hattı'),
  ];

  static const drawTools = <(ToolMode, IconData, String)>[
    (ToolMode.polyline, Icons.polyline_outlined, 'Çizgi'),
    (ToolMode.polygon, Icons.pentagon_outlined, 'Alan'),
    (ToolMode.circle, Icons.circle_outlined, 'Daire'),
    (ToolMode.rectangle, Icons.crop_square, 'Dikdörtgen'),
    (ToolMode.freehand, Icons.gesture, 'Serbest çizim'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    final night = ref.watch(nightModeProvider);
    final notifier = ref.read(toolProvider.notifier);
    final accent = night ? Colors.redAccent : Colors.amber;
    final idle = night ? Colors.red.shade200 : Colors.white;

    Widget button(
      IconData icon,
      String label,
      bool active,
      VoidCallback onTap,
    ) => Semantics(
      button: true,
      label: label,
      selected: active,
      child: Material(
        color: active ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: kToolbarButtonSize,
            height: kToolbarButtonSize,
            child: Icon(icon, size: 24, color: active ? Colors.black : idle),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.black.withValues(alpha: 0.78),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accent.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (mode, icon, label) in tools)
                  button(icon, label, tool.mode == mode, () {
                    // Aynı araca tekrar dokunmak onu kapatır (ATAK: sarı ↔ beyaz).
                    tool.mode == mode
                        ? notifier.reset()
                        : notifier.setMode(mode);
                  }),
                Container(
                  width: 1,
                  height: kToolbarButtonSize - 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: Colors.white24,
                ),
                button(Icons.close, closeLabel, false, onClose),
              ],
            ),
          ),
        ),
        if (tool.active)
          const Padding(padding: EdgeInsets.only(top: 6), child: ToolBanner())
        else
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              hint,
              style: TextStyle(
                color: idle,
                fontSize: 12,
                shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
              ),
            ),
          ),
      ],
    );
  }
}
