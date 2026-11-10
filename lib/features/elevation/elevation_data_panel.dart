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
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'elevation-data',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => ElevationDataPanel(onCenter: onCenter),
  );
}

class ElevationDataPanel extends ConsumerWidget {
  const ElevationDataPanel({super.key, required this.onCenter});

  final ValueChanged<LatLng> onCenter;

  static String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(elevationTilesProvider);
    final coverage = ref.watch(showElevationCoverageProvider);
    final self = ref.watch(selfContactProvider)?.position;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = tiles.value ?? const <ElevationTileInfo>[];

    // Konumum için gereken kare var mı (kullanıcı hangi dosyayı
    // indireceğini bilsin).
    Widget? needed;
    if (self != null && tiles.hasValue) {
      final key = DemTile.keyFor(self.latitude.floor(), self.longitude.floor());
      final have = list.any((t) => t.key == key);
      needed = Text(
        have
            ? 'Bulunduğun kare ($key) cihazda.'
            : 'Bulunduğun kare ($key) yok: $key.hgt ya da DTED dosyasını '
                  'içe aktar.',
        style: TextStyle(color: have ? null : Colors.orangeAccent),
      );
    }

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
          'Görüş hattı, profil, nokta yüksekliği ve arazi analizi bu '
          'dosyalardan okunur: SRTM (.hgt) ya da DTED (.dt0/.dt1/.dt2), '
          '1°×1° kareler. Zip olarak indirdiysen önce Dosyalar '
          'uygulamasında dokunup aç.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 10),
        ?needed,
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
      final info = await store.importBytes(
        await File(path).readAsBytes(),
        f.name,
      );
      added.add(info.key);
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
