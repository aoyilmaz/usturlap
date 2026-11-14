import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/mapbox_offline_store.dart';
import '../../domain/models/offline_region.dart';
import '../../providers/offline_providers.dart';
import '../shell/adaptive_sheet.dart';

String fmtBytes(int b) {
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Çevrimdışı haritalar: indirilen bölgeler, yeni bölge, ağ kesme testi.
Future<void> showOfflineRegionsSheet(
  BuildContext context, {
  required void Function(OfflineRegion region) onShowRegion,
  required VoidCallback onNewRegion,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _OfflineRegionsSheet(
      onShowRegion: onShowRegion,
      onNewRegion: onNewRegion,
    ),
  );
}

class _OfflineRegionsSheet extends ConsumerWidget {
  const _OfflineRegionsSheet({required this.onShowRegion, required this.onNewRegion});

  final void Function(OfflineRegion region) onShowRegion;
  final VoidCallback onNewRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(offlineRegionsProvider);
    final offlineTest = ref.watch(offlineTestModeProvider);
    final download = ref.watch(offlineDownloadProvider);
    final list = regions.value ?? const <OfflineRegion>[];
    final total = list.fold<int>(0, (s, r) => s + r.sizeBytes);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Çevrimdışı haritalar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (list.isNotEmpty)
                  Text('${list.length} bölge · ${fmtBytes(total)}',
                      style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Mapbox uydu + yol/yer adları + 3B arazi. Ağ yokken indirilen '
              'bölgeler otomatik kullanılır.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (download?.running ?? false)
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onNewRegion();
                    },
              icon: const Icon(Icons.crop_free),
              label: Text((download?.running ?? false)
                  ? 'İndirme sürüyor…'
                  : 'Yeni bölge indir'),
            ),
            const SizedBox(height: 8),
            if (regions.isLoading && list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (regions.hasError)
              Text('Bölgeler okunamadı: ${regions.error}')
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Henüz indirilmiş bölge yok.',
                    textAlign: TextAlign.center),
              )
            else
              for (final r in list) _RegionTile(region: r, onShow: onShowRegion),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(offlineTest ? Icons.cloud_off : Icons.cloud_done,
                  color: offlineTest ? Colors.redAccent : null),
              title: const Text('Ağı kapat (çevrimdışı test)'),
              subtitle: const Text(
                  'Harita yalnızca indirilen bölgeleri kullanır. Uygulama '
                  'yeniden açılınca ağ açılır.'),
              value: offlineTest,
              onChanged: (v) =>
                  ref.read(offlineTestModeProvider.notifier).set(v),
            ),
            const SizedBox(height: 4),
            const Text(
              'Not: Mapbox tüm bölgeler için toplam '
              '${MapboxOfflineStore.tilePackLimit} karo paketine izin verir; '
              'dolarsa yeni indirme için eski bölgeleri silin.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionTile extends ConsumerWidget {
  const _RegionTile({required this.region, required this.onShow});

  final OfflineRegion region;
  final void Function(OfflineRegion region) onShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = region;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(r.isComplete ? Icons.map : Icons.warning_amber,
          color: r.isComplete ? null : Colors.orangeAccent),
      title: Text(r.name),
      subtitle: Text(
        '${r.types.map((t) => t.label).join(' + ')} · '
        '${fmtBytes(r.sizeBytes)} · z0–z${r.maxZoom} · ${_fmtDate(r.createdAt)}'
        '${r.isComplete ? '' : ' · yarım kaldı'}',
      ),
      onTap: !r.hasBounds
          ? null
          : () {
              Navigator.of(context).pop();
              onShow(r);
            },
      trailing: IconButton(
        tooltip: 'Sil',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Bölgeyi sil'),
              content: Text('“${r.name}” (${fmtBytes(r.sizeBytes)}) '
                  'cihazdan silinecek.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Vazgeç')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Sil')),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(offlineRegionsProvider.notifier).delete(r.id);
          }
        },
      ),
    );
  }
}
