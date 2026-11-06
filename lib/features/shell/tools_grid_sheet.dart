import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tr_text.dart';
import 'adaptive_sheet.dart';

/// ≡ ızgarasındaki bir araç.
class ToolGridItem {
  const ToolGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Özel renk (ör. acil silme kırmızı).
  final Color? color;

  /// Şu an açık olan araç (vurgulanır).
  final bool active;
}

/// Bir bölüm: başlık + araçlar.
class ToolGridSection {
  const ToolGridSection(this.title, this.items);
  final String title;
  final List<ToolGridItem> items;
}

/// ≡ Bütün araçlar (ATAK "Additional Tools & Plugins", kılavuz s.5).
/// Dikeyde alttan, yatayda sağdan açılır. Bir araca dokununca ızgara kapanır,
/// sonra araç çalışır.
Future<void> showToolsGridSheet(
  BuildContext context, {
  required List<ToolGridSection> sections,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ToolsGrid(
      sections: sections,
      onPick: (item) {
        Navigator.of(sheetContext).pop();
        item.onTap();
      },
    ),
  );
}

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid({required this.sections, required this.onPick});

  final List<ToolGridSection> sections;
  final void Function(ToolGridItem) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            // Eldivenle seçilebilecek kare kutular: en az ~84 pt genişlik.
            final columns = (c.maxWidth / 92).floor().clamp(3, 6);
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Text(
                    'Araçlar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                for (final s in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text(
                      upperTr(s.title),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.95,
                    children: [
                      for (final item in s.items)
                        _Tile(item: item, onTap: () => onPick(item)),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.onTap});

  final ToolGridItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        item.color ??
        (item.active ? Colors.lightGreenAccent : scheme.onSurface);
    return Material(
      color: item.active
          ? Colors.lightGreenAccent.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11.5, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
