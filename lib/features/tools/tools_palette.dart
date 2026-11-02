import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/graphic_providers.dart';
import '../../providers/tool_providers.dart';
import 'graphic_list_sheet.dart';

/// Ölçüm/çizim araçları paleti. Bir araç seçince haritaya dokunarak nokta
/// koyulur; üstteki ölçüm şeridi (ToolBanner) değeri gösterir.
Future<void> showToolsPalette(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final tool = ref.watch(toolProvider);
      final notifier = ref.read(toolProvider.notifier);

      Widget item(ToolMode mode, IconData icon, String label, String hint) {
        final selected = tool.mode == mode;
        return ListTile(
          leading: Icon(icon,
              color: selected ? Colors.lightGreenAccent : null),
          title: Text(label,
              style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(hint),
          trailing: selected
              ? const Icon(Icons.check, color: Colors.lightGreenAccent)
              : null,
          onTap: () {
            notifier.setMode(mode);
            Navigator.of(context).pop();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Araçlar',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            item(ToolMode.distance, Icons.straighten, 'Mesafe',
                'Nokta koy → toplam mesafe'),
            item(ToolMode.polygon, Icons.pentagon_outlined, 'Alan (poligon)',
                'Köşe koy → alan + çevre'),
            item(ToolMode.sector, Icons.pie_chart_outline, 'Sektör',
                'Merkez, yarıçap, bitiş kerterizi (3 dokunuş)'),
            item(ToolMode.lineOfSight, Icons.landscape_outlined, 'Görüş Hattı',
                'İki nokta seç → Yükseklik profili ve engel analizi'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: Text(
                  'Kayıtlı çizimler (${ref.read(mapGraphicsProvider).value?.length ?? 0})'),
              subtitle: const Text('Taktik grafikleri göster/sil'),
              onTap: () {
                Navigator.of(context).pop();
                showGraphicListSheet(context, ref);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility),
              title: const Text('Çizimi göster'),
              value: tool.visible,
              onChanged:
                  tool.active ? (_) => notifier.toggleVisible() : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Noktaları temizle'),
              enabled: tool.points.isNotEmpty,
              onTap: () {
                notifier.clearPoints();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Aracı kapat'),
              enabled: tool.active,
              onTap: () {
                notifier.reset();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}
