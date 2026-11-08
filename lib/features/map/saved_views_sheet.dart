import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coord_format.dart';
import '../../domain/models/saved_view.dart';
import '../../providers/saved_view_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Kayıtlı görünümler (ATAK Favorites, kılavuz s.22): o anki görünümü
/// kaydet, listeden tek dokunuşla dön, yeniden adlandır, sil.
///
/// [current]: haritanın o anki görünümü (ad verilerek; kimliği sağlayıcı
/// verir). [layerLabel]: katman kimliğinden ad (bulunamazsa null).
Future<void> showSavedViewsSheet(
  BuildContext context, {
  required SavedView Function(String name) current,
  required ValueChanged<SavedView> onApply,
  required String? Function(String? layerId) layerLabel,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'saved-views',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => SavedViewsPanel(
      current: current,
      onApply: onApply,
      layerLabel: layerLabel,
    ),
  );
}

class SavedViewsPanel extends ConsumerWidget {
  const SavedViewsPanel({
    super.key,
    required this.current,
    required this.onApply,
    required this.layerLabel,
  });

  final SavedView Function(String name) current;
  final ValueChanged<SavedView> onApply;
  final String? Function(String? layerId) layerLabel;

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ad'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(savedViewsProvider);
    final notifier = ref.read(savedViewsProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text(
          'Kayıtlı görünümler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Haritanın konumu, yakınlığı, yönü ve harita kaynağı birlikte '
          'kaydedilir.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Bu görünümü kaydet'),
          onPressed: () async {
            final name = await _askName(
              context,
              title: 'Görünümü kaydet',
              initial: 'Görünüm ${views.length + 1}',
            );
            final n = name?.trim();
            if (n == null || n.isEmpty) return;
            notifier.add(current(n));
          },
        ),
        const SizedBox(height: 8),
        if (views.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Henüz kayıtlı görünüm yok.',
              style: TextStyle(color: muted),
            ),
          ),
        for (final v in views.reversed)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 4),
            leading: const Icon(Icons.bookmark_outline),
            title: Text(v.name),
            subtitle: Text(
              '${CoordFormat.mgrs(v.center)} · z${v.zoom.toStringAsFixed(0)}'
              ' · ${layerLabel(v.layerId) ?? 'harita bulunamadı'}',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => onApply(v),
            trailing: PopupMenuButton<String>(
              tooltip: 'Seçenekler: ${v.name}',
              onSelected: (action) async {
                if (action == 'delete') {
                  notifier.delete(v.id);
                  return;
                }
                final name = await _askName(
                  context,
                  title: 'Yeniden adlandır',
                  initial: v.name,
                );
                final n = name?.trim();
                if (n != null && n.isNotEmpty) notifier.rename(v.id, n);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Yeniden adlandır')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
          ),
      ],
    );
  }
}
