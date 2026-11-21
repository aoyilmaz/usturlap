import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/elevation/dem_tile.dart';
import '../../data/elevation/elevation_store.dart';
import '../../providers/elevation_providers.dart';
import '../../providers/location_providers.dart';
import '../shell/adaptive_sheet.dart';
import '../tools/measure_common.dart';

/// Yükseklik verisi (ATAK Elevation Data, kılavuz s.25): cihazdaki HGT /
/// DTED kareleri, içe aktarma, silme, haritada kapsama.
Future<void> showElevationDataPanel(
  BuildContext context, {
  required ValueChanged<LatLng> onCenter,
  LatLng Function()? mapCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'elevation-data',
    toggle: true,
    isScrollControlled: true,
    builder: (_) =>
        ElevationDataPanel(onCenter: onCenter, mapCenter: mapCenter),
  );
}

class ElevationDataPanel extends ConsumerWidget {
  const ElevationDataPanel({super.key, required this.onCenter, this.mapCenter});

  final ValueChanged<LatLng> onCenter;

  /// Haritanın ortası (o karenin indirilmesi için).
  final LatLng Function()? mapCenter;

  static String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(elevationTilesProvider);
    final coverage = ref.watch(showElevationCoverageProvider);
    final self = ref.watch(selfContactProvider)?.position;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = tiles.value ?? const <ElevationTileInfo>[];

    // Bulunduğun ve haritanın ortasındaki kare: varsa yazar, yoksa tek
    // dokunuşla indirilir.
    String keyOf(LatLng p) =>
        DemTile.keyFor(p.latitude.floor(), p.longitude.floor());
    bool have(String key) => list.any((t) => t.key == key && !t.bundled);
    final selfKey = self == null ? null : keyOf(self);
    final center = mapCenter?.call();
    final centerKey = center == null ? null : keyOf(center);
    final rows = <Widget>[
      if (selfKey != null && tiles.hasValue)
        have(selfKey)
            ? Text('Bulunduğun kare ($selfKey) cihazda.')
            : _DownloadTile(tileKey: selfKey, label: 'Bulunduğun kare'),
      if (centerKey != null && centerKey != selfKey && tiles.hasValue)
        have(centerKey)
            ? Text('Harita ortasındaki kare ($centerKey) cihazda.')
            : _DownloadTile(tileKey: centerKey, label: 'Harita ortası'),
    ];

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Yükseklik verisi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Görüş alanı, eğim, eş yükselti, yükseklik profili ve nokta '
          'yüksekliği bu verilerden çevrimdışı hesaplanır. Her dosya '
          '1°×1°lik bir kare (yaklaşık 110 × 85 km). İnternet varken '
          'gereken kareyi indir; ya da elinde olan SRTM (.hgt) / DTED '
          '(.dt0–.dt2) dosyasını içe aktar (zip ya da .gz ise açmana '
          'gerek yok).',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 10),
        ...rows,
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'İndirme kaynağı: Terrain Tiles (Mapzen, AWS Açık Veri) · '
            'NASA/USGS SRTM, 1″ (~30 m). Kare başına ~5–15 MB indirilir.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => importElevationFiles(context, ref),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Dosya içe aktar'),
            ),
            FilterChip(
              label: const Text('Haritada kapsama'),
              selected: coverage,
              onSelected: (on) =>
                  ref.read(showElevationCoverageProvider.notifier).set(on),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tiles.isLoading && !tiles.hasValue)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Text(
            '${list.length} kare · '
            '${_mb(list.where((t) => !t.bundled).fold(0, (n, t) => n + t.sizeBytes))}',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          for (final t in list)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 4),
              leading: const Icon(Icons.terrain),
              title: Text(t.key),
              subtitle: Text(
                '${t.description} · ${_mb(t.sizeBytes)}'
                '${t.bundled ? ' · uygulamayla gelen örnek' : ''}',
              ),
              onTap: () => onCenter(LatLng(t.south + 0.5, t.west + 0.5)),
              trailing: t.bundled
                  ? null
                  : IconButton(
                      tooltip: 'Sil: ${t.key}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final store = ref.read(elevationStoreProvider);
                        if (!await confirmDeleteNamed(context, t.fileName)) {
                          return;
                        }
                        await store.delete(t.fileName);
                        refreshElevationData(ref);
                      },
                    ),
            ),
        ],
      ],
    );
  }
}

/// Dosyalar'dan bir ya da birkaç yükseklik dosyası seçtirip içe aktarır;
/// sonucu kısa iletiyle söyler.
Future<void> importElevationFiles(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final store = ref.read(elevationStoreProvider);
  // FileType.any: .hgt / .dtN için iOS'ta sistem türü yok (bkz. katman
  // içe aktarma); uzantı ve içerik aşağıda doğrulanır.
  final res = await FilePicker.pickFiles(
    type: FileType.any,
    allowMultiple: true,
    withData: false,
  );
  if (res == null || res.files.isEmpty) return;
  final added = <String>[];
  final failed = <String>[];
  for (final f in res.files) {
    final path = f.path;
    if (path == null) {
      failed.add('${f.name} (okunamadı)');
      continue;
    }
    try {
      if (await File(path).length() > ElevationStore.maxFileBytes) {
        failed.add('${f.name}: çok büyük');
        continue;
      }
      // .hgt / .dtN, .hgt.gz ya da birçok kare içeren .zip.
      final infos = await store.importFile(
        await File(path).readAsBytes(),
        f.name,
      );
      added.addAll(infos.map((i) => i.key));
    } on FormatException catch (e) {
      failed.add('${f.name}: ${e.message}');
    } catch (e) {
      failed.add('${f.name}: $e');
    }
  }
  if (added.isNotEmpty) refreshElevationData(ref);
  messenger?.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(
        [
          if (added.isNotEmpty) 'Eklendi: ${added.join(', ')}',
          if (failed.isNotEmpty) 'Eklenemedi: ${failed.join('; ')}',
        ].join('\n'),
      ),
    ),
  );
}

/// "N38E034 yok · İndir" satırı: internetten indirir, ilerlemeyi gösterir.
class _DownloadTile extends ConsumerStatefulWidget {
  const _DownloadTile({required this.tileKey, required this.label});

  final String tileKey;
  final String label;

  @override
  ConsumerState<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends ConsumerState<_DownloadTile> {
  bool _busy = false;
  double? _progress;

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = null;
    });
    // Panel kapanırsa da iş bitsin; sonuç uygulama düzeyinde bildirilir.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final container = ProviderScope.containerOf(context);
    final store = container.read(elevationStoreProvider);
    final key = widget.tileKey;
    String message;
    try {
      await store.download(
        key,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      container.read(hgtParserProvider).invalidate();
      container.invalidate(elevationTilesProvider);
      container.invalidate(terrainElevationProvider);
      message = '$key indirildi.';
    } on FormatException catch (e) {
      message = e.message;
    } on SocketException {
      message = 'İnternet yok: $key indirilemedi.';
    } on TimeoutException {
      message = 'Bağlantı zaman aşımına uğradı: $key indirilemedi.';
    } catch (e) {
      message = '$key indirilemedi: $e';
    }
    if (mounted) setState(() => _busy = false);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.label} (${widget.tileKey}) cihazda yok.',
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
          const SizedBox(width: 8),
          if (_busy)
            SizedBox(
              width: 96,
              child: LinearProgressIndicator(value: _progress),
            )
          else
            OutlinedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('İndir'),
            ),
        ],
      ),
    );
  }
}
