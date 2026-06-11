import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coord_format.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';

/// Haritaya uzun basınca açılan "waypoint ekle" diyaloğu.
/// İsim (varsayılan WP-N) ve isteğe bağlı not alır, drift'e kaydeder.
Future<void> showAddWaypointDialog(
  BuildContext context,
  WidgetRef ref,
  LatLng point,
) async {
  final count = ref.read(waypointsProvider).value?.length ?? 0;
  final format = ref.read(coordFormatProvider);
  final nameCtrl = TextEditingController(text: 'WP-${count + 1}');
  final noteCtrl = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Waypoint ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(CoordFormat.format(point, format),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(CoordFormat.wgs84(point),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'İsim'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().isEmpty
                  ? 'WP-${count + 1}'
                  : nameCtrl.text.trim();
              await ref.read(waypointRepositoryProvider).add(
                    name: name,
                    position: point,
                    note: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      );
    },
  );
}
