import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/map_graphic.dart';
import '../../providers/geofence_providers.dart';
import '../../providers/graphic_providers.dart';
import '../shell/adaptive_sheet.dart';
import 'graphic_labels.dart';

/// Geofence uyarı türü seçimi: Yok / Girişte / Çıkışta / İkisinde.
class GeofenceChips extends StatelessWidget {
  const GeofenceChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final GeofenceTrigger? selected;
  final ValueChanged<GeofenceTrigger?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final t in <GeofenceTrigger?>[null, ...GeofenceTrigger.values])
        ChoiceChip(
          label: Text(t?.label ?? 'Yok'),
          selected: selected == t,
          onSelected: (_) => onChanged(t),
        ),
    ],
  );
}

/// Bir çizimin geofence uyarısını değiştirme penceresi.
Future<void> showGeofenceDialog(
  BuildContext context,
  WidgetRef ref,
  MapGraphic g,
) async {
  var trigger = g.geofence;
  final repo = ref.read(mapGraphicRepositoryProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text('${g.name}: geofence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu alana girince / çıkınca uyar:'),
            const SizedBox(height: 8),
            GeofenceChips(
              selected: trigger,
              onChanged: (t) => setLocal(() => trigger = t),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) await repo.setGeofence(g.id!, trigger);
}

/// Geofence paneli (ATAK Geofencing, kılavuz s.43): uyarılı şekiller, şu an
/// içeride / dışarıda, son uyarılar.
Future<void> showGeofencePanel(
  BuildContext context, {
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'geofence',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => GeofencePanel(onCenter: onCenter),
  );
}

class GeofencePanel extends ConsumerWidget {
  const GeofencePanel({super.key, required this.onCenter});

  final ValueChanged<LatLng> onCenter;

  static String _time(DateTime utcOrLocal) {
    final t = utcOrLocal.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(geofenceProvider);
    final fences = [
      for (final g
          in ref.watch(mapGraphicsProvider).value ?? const <MapGraphic>[])
        if (g.geofence != null && g.closed) g,
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget caption(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Geofence',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Kapalı bir çizime (alan, daire, dikdörtgen) giriş / çıkış uyarısı '
          'koy: Çizimler listesindeki çit simgeli düğme ya da kaydederken. Uygulama '
          'açıkken titreşir ve uyarı gösterir; arka planda (iz kaydı '
          'sürerken) olanlar aşağıdaki listeye yazılır.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        caption('Uyarılı alanlar (${fences.length})'),
        if (fences.isEmpty) Text('Henüz yok.', style: TextStyle(color: muted)),
        for (final g in fences)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(graphicIcon(g.type), color: Color(g.colorValue)),
            title: Text(g.name),
            subtitle: Text(
              '${g.geofence!.label} · '
              '${switch (state.inside[g.uid]) {
                true => 'şu an içeridesin',
                false => 'şu an dışarıdasın',
                null => 'konum bekleniyor',
              }}',
            ),
            trailing: IconButton(
              tooltip: 'Geofence: ${g.name}',
              icon: const Icon(Icons.fence),
              onPressed: () => showGeofenceDialog(context, ref, g),
            ),
            onTap: () => onCenter(g.outline.first),
          ),
        caption('Son uyarılar'),
        if (state.history.isEmpty)
          Text('Henüz uyarı yok.', style: TextStyle(color: muted)),
        for (final e in state.history.reversed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              e.entered ? Icons.login : Icons.logout,
              color: e.entered ? Colors.orangeAccent : Colors.lightBlueAccent,
            ),
            title: Text('${e.name}: ${e.entered ? 'girildi' : 'çıkıldı'}'),
            trailing: Text(_time(e.at)),
          ),
        if (state.history.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: ref.read(geofenceProvider.notifier).clearHistory,
              icon: const Icon(Icons.clear_all),
              label: const Text('Geçmişi temizle'),
            ),
          ),
      ],
    );
  }
}
