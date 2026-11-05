import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/graphic_providers.dart';
import '../../providers/offline_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../offline/offline_regions_sheet.dart' show fmtBytes;

/// Görevler: kayıtlı her şeyin tek giriş noktası (noktalar, izler, grafikler,
/// çevrimdışı bölgeler, içe aktarma). Her satır ilgili listeyi açar.
Future<void> showMissionsSheet(
  BuildContext context, {
  required VoidCallback onWaypoints,
  required VoidCallback onTracks,
  required VoidCallback onGraphics,
  required VoidCallback onOfflineRegions,
  required VoidCallback onImportGpxKml,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _MissionsSheet(
      onWaypoints: onWaypoints,
      onTracks: onTracks,
      onGraphics: onGraphics,
      onOfflineRegions: onOfflineRegions,
      onImportGpxKml: onImportGpxKml,
    ),
  );
}

class _MissionsSheet extends ConsumerWidget {
  const _MissionsSheet({
    required this.onWaypoints,
    required this.onTracks,
    required this.onGraphics,
    required this.onOfflineRegions,
    required this.onImportGpxKml,
  });

  final VoidCallback onWaypoints;
  final VoidCallback onTracks;
  final VoidCallback onGraphics;
  final VoidCallback onOfflineRegions;
  final VoidCallback onImportGpxKml;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wp = ref.watch(waypointsProvider).value?.length;
    final tr = ref.watch(tracksProvider).value?.length;
    final gr = ref.watch(mapGraphicsProvider).value?.length;
    final regions = ref.watch(offlineRegionsProvider).value;
    final regionBytes = regions?.fold<int>(0, (s, r) => s + r.sizeBytes);

    void go(VoidCallback f) {
      Navigator.of(context).pop();
      f();
    }

    String n(int? v) => v == null ? '…' : '$v';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Görevler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          _Row(
            icon: Icons.place,
            title: 'Noktalar',
            subtitle: '${n(wp)} nokta · git, düzenle, sil',
            onTap: () => go(onWaypoints),
          ),
          _Row(
            icon: Icons.timeline,
            title: 'İzler',
            subtitle: '${n(tr)} iz · göster, paylaş, sil',
            onTap: () => go(onTracks),
          ),
          _Row(
            icon: Icons.polyline,
            title: 'Grafikler',
            subtitle: '${n(gr)} çizgi/alan · göster, sil',
            onTap: () => go(onGraphics),
          ),
          _Row(
            icon: Icons.download_for_offline_outlined,
            title: 'Çevrimdışı bölgeler',
            subtitle: regions == null
                ? '…'
                : regions.isEmpty
                    ? 'bölge indir · sinyalsiz kullan'
                    : '${regions.length} bölge · ${fmtBytes(regionBytes!)}',
            onTap: () => go(onOfflineRegions),
          ),
          const Divider(),
          _Row(
            icon: Icons.file_open_outlined,
            title: 'GPX / KML içe aktar',
            subtitle: 'nokta ve izler — Dosyalar\'dan',
            onTap: () => go(onImportGpxKml),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
