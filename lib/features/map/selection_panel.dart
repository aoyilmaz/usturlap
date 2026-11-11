import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/hashtags.dart';
import '../../core/tr_text.dart';
import '../../data/export/selection_exporter.dart';
import '../../domain/models/clear_item.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/map_cleaner.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/selection_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';
import '../tools/measure_common.dart';

/// Lasso seçimi paneli (ATAK Multi-Select, kılavuz s.44): seçilenleri
/// listeler; işareti kaldırılan işleme girmez. Toplu #etiket, KML paylaş,
/// sil (Geri al'lı). Panel kapanınca seçim biter.
Future<void> showSelectionPanel(BuildContext context) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'selection',
    isScrollControlled: true,
    builder: (_) => const SelectionPanel(),
  );
}

class SelectionPanel extends ConsumerStatefulWidget {
  const SelectionPanel({super.key});

  @override
  ConsumerState<SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends ConsumerState<SelectionPanel> {
  /// İşareti kaldırılanların uid'leri.
  final _off = <String>{};
  late final SelectionNotifier _selection;

  @override
  void initState() {
    super.initState();
    _selection = ref.read(selectionProvider.notifier);
  }

  @override
  void dispose() {
    // Ağaç kapanırken sağlayıcı değiştirilemez: bir sonraki turda.
    final s = _selection;
    scheduleMicrotask(s.clear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(selectionProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (sel == null || sel.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Seçimde nesne yok.'),
      );
    }
    final on = MapSelection(
      polygon: sel.polygon,
      waypoints: [
        for (final w in sel.waypoints)
          if (!_off.contains(w.uid)) w,
      ],
      graphics: [
        for (final g in sel.graphics)
          if (!_off.contains(g.uid)) g,
      ],
      rangeLines: [
        for (final l in sel.rangeLines)
          if (!_off.contains(l.uid)) l,
      ],
      rangeRings: [
        for (final r in sel.rangeRings)
          if (!_off.contains(r.uid)) r,
      ],
    );

    Widget caption(String t) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );

    Widget tile(String uid, String name, IconData icon) => CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(name),
      value: !_off.contains(uid),
      onChanged: (v) =>
          setState(() => v == true ? _off.remove(uid) : _off.add(uid)),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Text(
          'Seçim (${on.count}/${sel.count})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Lasso ile seçilenler. İşaretini kaldırdığın işleme girmez.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: on.isEmpty ? null : () => _tag(on),
              icon: const Icon(Icons.tag),
              label: const Text('Etiket ekle'),
            ),
            OutlinedButton.icon(
              onPressed: on.isEmpty ? null : () => _share(on),
              icon: const Icon(Icons.ios_share),
              label: const Text('KML paylaş'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: on.isEmpty ? null : () => _delete(on),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
          ],
        ),
        if (sel.waypoints.isNotEmpty) caption('Noktalar'),
        for (final w in sel.waypoints) tile(w.uid, w.name, Icons.place),
        if (sel.graphics.isNotEmpty) caption('Çizimler'),
        for (final g in sel.graphics) tile(g.uid, g.name, Icons.draw_outlined),
        if (sel.rangeLines.isNotEmpty) caption('R&B çizgileri'),
        for (final l in sel.rangeLines) tile(l.uid, l.name, Icons.straighten),
        if (sel.rangeRings.isNotEmpty) caption('Menzil halkaları'),
        for (final r in sel.rangeRings) tile(r.uid, r.name, Icons.radar),
      ],
    );
  }

  /// Seçilenlere #etiket ekler: noktaların notuna, diğerlerinin adına.
  Future<void> _tag(MapSelection on) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ctrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etiket ekle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '#',
            hintText: 'ör. kuzey',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    final word = tag?.trim().replaceAll(RegExp(r'^#+'), '');
    if (word == null || word.isEmpty || word.contains(RegExp(r'\s'))) return;
    final key = lowerTr(word);
    String withTag(String text) =>
        extractHashtags(text).contains(key) ? text : '$text #$word';
    var done = 0;
    final wps = ref.read(waypointRepositoryProvider);
    for (final w in on.waypoints) {
      final note = w.note ?? '';
      if (extractHashtags(note).contains(key)) continue;
      await wps.setNote(w.id!, note.isEmpty ? '#$word' : '$note #$word');
      done++;
    }
    Future<void> rename(String name, Future<void> Function(String) save) async {
      final next = withTag(name);
      if (next == name || next.length > 80) return;
      await save(next);
      done++;
    }

    final gfx = ref.read(mapGraphicRepositoryProvider);
    for (final g in on.graphics) {
      await rename(g.name, (n) => gfx.rename(g.id!, n));
    }
    final rbs = ref.read(rangeLineRepositoryProvider);
    for (final l in on.rangeLines) {
      await rename(l.name, (n) => rbs.rename(l.id!, n));
    }
    final rings = ref.read(rangeRingRepositoryProvider);
    for (final r in on.rangeRings) {
      await rename(r.name, (n) => rings.rename(r.id!, n));
    }
    messenger?.showSnackBar(
      SnackBar(content: Text('$done nesneye #$word eklendi.')),
    );
  }

  Future<void> _share(MapSelection on) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final kml = SelectionExporter.toKml(
        name: 'Pusula seçimi',
        waypoints: on.waypoints,
        graphics: on.graphics,
        rangeLines: on.rangeLines,
        rangeRings: on.rangeRings,
      );
      final path = '${Directory.systemTemp.path}/pusula_secim.kml';
      await File(path).writeAsString(kml, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'Pusula seçimi',
          text: 'Pusula seçimi (${on.count} nesne)',
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Paylaşılamadı: $e')));
    }
  }

  /// Seçilenleri siler (Haritayı temizle altyapısı: 6 sn Geri al,
  /// fotoğraflar süre dolunca silinir).
  Future<void> _delete(MapSelection on) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cleaner = ref.read(mapCleanerProvider);
    if (!await confirmDeleteNamed(context, '${on.count} nesne')) return;
    final snapshot = await cleaner.clear(
      {
        ClearItem.waypoints,
        ClearItem.graphics,
        ClearItem.rangeLines,
        ClearItem.rangeRings,
      },
      targets: MapClearTargets(
        tool: const ToolState(),
        rangeLines: on.rangeLines,
        rangeRings: on.rangeRings,
        bullseye: null,
        bloodhounds: const [],
        navTarget: null,
        activeRoute: null,
        displayedTrackId: null,
        viewshed: null,
        terrain: null,
        waypoints: on.waypoints,
        graphics: on.graphics,
      ),
    );
    if (mounted) Navigator.of(context).pop();
    final bar = messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${on.count} nesne silindi.'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => cleaner.undo(snapshot),
        ),
      ),
    );
    if (await bar?.closed != SnackBarClosedReason.action) {
      await cleaner.finalize(snapshot);
    }
  }
}
