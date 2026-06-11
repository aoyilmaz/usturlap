import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/export/track_exporter.dart';
import '../../domain/models/track.dart';
import '../../providers/track_providers.dart';

/// Kayıtlı izlerin paneli: haritada göster, KML/GeoJSON paylaş, sil.
Future<void> showTrackListSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _TrackListBody(),
  );
}

class _TrackListBody extends ConsumerWidget {
  const _TrackListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tracksProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('İzler',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Henüz iz yok. Alt-soldaki kayıt butonuyla başlat.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) =>
                        _TrackTile(track: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  const _TrackTile({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dur = _fmtDuration(track.duration);
    return ListTile(
      leading: Icon(
        track.isRecording ? Icons.fiber_manual_record : Icons.route,
        color: track.isRecording ? Colors.redAccent : Colors.lightBlueAccent,
      ),
      title: Text(track.name),
      subtitle: Text('${track.pointCount} nokta · $dur'
          '${track.isRecording ? ' · kaydediliyor' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Dışa aktar',
            onSelected: (v) => _export(context, ref, kml: v == 'kml'),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'geojson', child: Text('GeoJSON paylaş')),
              PopupMenuItem(value: 'kml', child: Text('KML paylaş')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Sil',
            onPressed: () =>
                ref.read(trackRepositoryProvider).deleteTrack(track.id!),
          ),
        ],
      ),
      onTap: () {
        // Haritada göster.
        ref.read(displayedTrackIdProvider.notifier).show(track.id);
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref,
      {required bool kml}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final points = await ref.read(trackRepositoryProvider).pointsOf(track.id!);
      if (points.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('İzde nokta yok.')));
        return;
      }
      final content =
          kml ? TrackExporter.toKml(track, points) : TrackExporter.toGeoJson(track, points);
      final safeName = track.name.replaceAll(RegExp(r'[^A-Za-z0-9-_]'), '_');
      final ext = kml ? 'kml' : 'geojson';
      final path = '${Directory.systemTemp.path}/$safeName.$ext';
      await File(path).writeAsString(content, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: track.name,
          text: '${track.name} (${points.length} nokta)',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Dışa aktarma hatası: $e')));
    }
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}s ${m}dk';
    if (m > 0) return '${m}dk ${s}sn';
    return '${s}sn';
  }
}
