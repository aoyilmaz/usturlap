import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/clear_item.dart';
import '../../providers/map_cleaner.dart';
import '../shell/adaptive_sheet.dart';

/// Haritayı temizle (D4b): haritada görünenleri türüne göre sayıyla
/// listeler; işaretlenenleri tek seferde siler ya da gizler. Ardından
/// birkaç saniye "Geri al".
Future<void> showClearMapSheet(BuildContext context) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'clear-map',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => const ClearMapPanel(),
  );
}

class ClearMapPanel extends ConsumerStatefulWidget {
  const ClearMapPanel({super.key});

  /// "Geri al" süresi.
  /// Geri al süresi (kısa: şerit haritayı uzun süre kapatmasın).
  static const undoWindow = Duration(seconds: 3);

  @override
  ConsumerState<ClearMapPanel> createState() => _ClearMapPanelState();
}

class _ClearMapPanelState extends ConsumerState<ClearMapPanel> {
  final _selected = {
    for (final i in ClearItem.values)
      if (i.selectedByDefault) i,
  };
  bool _hideOnly = false;

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(mapClearTargetsProvider);
    final present = [
      for (final i in ClearItem.values)
        if (targets.count(i) > 0) i,
    ];
    final chosen = present.where(_selected.contains).toList();
    final total = chosen.fold<int>(0, (n, i) => n + targets.count(i));
    final deletesPermanent = !_hideOnly && chosen.any((i) => i.permanent);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget tile(ClearItem i) {
      final hidden = _hideOnly && i.canHide;
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _selected.contains(i),
        onChanged: (on) => setState(() {
          on == true ? _selected.add(i) : _selected.remove(i);
        }),
        title: Text('${i.label} (${targets.count(i)})'),
        subtitle: _hideOnly
            ? Text(
                hidden ? 'gizlenir' : 'temizlenir',
                style: TextStyle(fontSize: 12, color: muted),
              )
            : null,
      );
    }

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Haritayı temizle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Haritada görünenler. İşaretlileri tek seferde temizle; '
          'ardından birkaç saniye "Geri al" çıkar.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        if (present.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Haritada temizlenecek bir şey yok.',
              style: TextStyle(color: muted),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.delete_outline),
                label: Text('Sil'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.visibility_off_outlined),
                label: Text('Yalnız gizle'),
              ),
            ],
            selected: {_hideOnly},
            onSelectionChanged: (v) => setState(() => _hideOnly = v.single),
          ),
          // Düğme listenin üstünde: yarım ekranlık panelde kaydırmadan
          // görünsün (eldiven).
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: total == 0 ? null : () => _run(chosen),
            icon: Icon(
              _hideOnly ? Icons.visibility_off : Icons.cleaning_services,
            ),
            label: Text(
              _hideOnly ? 'Gizle / temizle ($total)' : 'Temizle ($total)',
            ),
          ),
          if (deletesPermanent)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Haritadaki noktalar / çizimler silinir (fotoğraflarıyla). '
                'Yalnız "Geri al" süresince geri getirilebilir.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
              ),
            ),
          if (present.any((i) => !i.permanent)) caption('Ölçümler ve geçici'),
          for (final i in present)
            if (!i.permanent) tile(i),
          if (present.any((i) => i.permanent)) caption('Kalıcı veri'),
          for (final i in present)
            if (i.permanent) tile(i),
        ],
      ],
    );
  }

  Future<void> _run(List<ClearItem> chosen) async {
    final cleaner = ref.read(mapCleanerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final snapshot = await cleaner.clear(chosen.toSet(), hideOnly: _hideOnly);
    if (mounted) Navigator.of(context).pop();
    final bar = messenger?.showSnackBar(
      SnackBar(
        duration: ClearMapPanel.undoWindow,
        // Düğmeli şerit Flutter'da varsayılan olarak kalıcı; süre dolunca
        // kapansın.
        persist: false,
        content: Text(
          _hideOnly ? 'Harita sadeleştirildi.' : 'Harita temizlendi.',
        ),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => cleaner.undo(snapshot),
        ),
      ),
    );
    final reason = await bar?.closed;
    if (reason != SnackBarClosedReason.action) {
      await cleaner.finalize(snapshot);
    }
  }
}
