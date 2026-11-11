import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coord_format.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/nav_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../import/import_action.dart';
import '../symbols/nato_symbol.dart';
import '../shell/adaptive_sheet.dart';

/// Kayıtlı waypoint'leri listeleyen alt panel. Dokun → haritada ortala,
/// çöp kutusu → sil. Liste drift akışından canlı güncellenir.
Future<void> showWaypointListSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function(Waypoint) onTapWaypoint,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _WaypointListBody(onTapWaypoint: onTapWaypoint),
  );
}

class _WaypointListBody extends ConsumerWidget {
  const _WaypointListBody({required this.onTapWaypoint});

  final void Function(Waypoint) onTapWaypoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(waypointsProvider);
    final format = ref.watch(coordFormatProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Text('Waypoint\'ler',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => runImport(context, ref),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('İçe aktar'),
                  ),
                ],
              ),
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
                        'Henüz waypoint yok. Haritaya uzun basarak ekleyin.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final wp = list[i];
                      return ListTile(
                        leading: PointSymbol(
                          affiliation: wp.affiliation,
                          echelon: wp.echelon,
                          role: wp.role,
                          size: 28,
                        ),
                        title: Text(wp.name),
                        subtitle: Text(
                          CoordFormat.format(wp.position, format),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Sil',
                          onPressed: () {
                            final target = ref.read(navTargetProvider);
                            if (target != null && target.position == wp.position) {
                              ref.read(navTargetProvider.notifier).clear();
                            }
                            ref
                                .read(attachmentRepositoryProvider)
                                .deleteAllFor(wp.uid);
                            ref.read(waypointRepositoryProvider).delete(wp.id!);
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          onTapWaypoint(wp);
                        },
                      );
                    },
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
