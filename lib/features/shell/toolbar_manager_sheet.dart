import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_providers.dart';
import 'adaptive_sheet.dart';
import 'toolbar_tools.dart';

/// Araç çubuğu düzenleyici (ATAK Toolbar Manager, kılavuz s.55–57): üst
/// çubukta hangi araçların, hangi sırayla duracağı. Panel modal olmadığı
/// için değişiklik çubukta hemen görünür.
Future<void> showToolbarManagerSheet(BuildContext context) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'toolbar',
    toggle: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const ToolbarManager(),
  );
}

class ToolbarManager extends ConsumerWidget {
  const ToolbarManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(toolbarToolsProvider);
    final notifier = ref.read(toolbarToolsProvider.notifier);
    final full = tools.length >= ToolbarTool.maxOnBar;
    final available = [
      for (final t in ToolbarTool.values)
        if (!tools.contains(t)) t,
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );

    return ReorderableListView(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 12),
      onReorderItem: (from, to) {
        HapticFeedback.selectionClick();
        notifier.move(from, to);
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Araç çubuğu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Çubukta ${tools.length}/${ToolbarTool.maxOnBar} araç. Sırayı '
              '≡ tutamağından sürükleyerek değiştir. Çubuktan çıkan araç '
              '≡ Bütün araçlar menüsünde kalır.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
          section('Çubukta'),
          if (tools.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Çubukta yalnız ≡ var.',
                style: TextStyle(color: muted),
              ),
            ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Eklenebilir'),
          if (full)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Çubuk dolu: eklemek için önce bir aracı çıkar.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          for (final t in available)
            ListTile(
              leading: Icon(t.icon, color: full ? muted : null),
              title: Text(t.label),
              trailing: IconButton(
                tooltip: 'Ekle: ${t.label}',
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.lightGreenAccent,
                onPressed: full ? null : () => notifier.add(t),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Varsayılana dön'),
                onPressed: notifier.reset,
              ),
            ),
          ),
        ],
      ),
      children: [
        for (final (i, t) in tools.indexed)
          ListTile(
            key: ValueKey(t),
            contentPadding: const EdgeInsets.only(left: 4, right: 8),
            leading: ReorderableDragStartListener(
              index: i,
              child: Semantics(
                label: 'Sürükle: ${t.label}',
                child: SizedBox(
                  key: ValueKey('surukle-${t.name}'),
                  width: 48,
                  height: 48,
                  child: const Icon(Icons.drag_handle),
                ),
              ),
            ),
            title: Row(
              children: [
                Icon(t.icon),
                const SizedBox(width: 12),
                Expanded(child: Text(t.label)),
              ],
            ),
            trailing: IconButton(
              tooltip: 'Çıkar: ${t.label}',
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.redAccent,
              onPressed: () => notifier.remove(t),
            ),
          ),
      ],
    );
  }
}
