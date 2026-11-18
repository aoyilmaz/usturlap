import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/map_graphic.dart';
import '../../providers/graphic_providers.dart';
import '../elevation/elevation_profile_panel.dart';
import '../shell/adaptive_sheet.dart';
import 'geofence_panel.dart';
import 'graphic_labels.dart';
import 'save_graphic_dialog.dart';
import 'measure_common.dart';

/// Kayıtlı taktik grafikler paneli: renk/tip/ölçü göster; dokununca
/// düzenle (ad, renk, kalınlık…); geofence, profil, sil.
Future<void> showGraphicListSheet(BuildContext context, WidgetRef ref) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _GraphicListBody(),
  );
}

class _GraphicListBody extends ConsumerWidget {
  const _GraphicListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mapGraphicsProvider);
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
              child: Text('Kayıtlı çizimler',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Düzenlemek için dokun. Şekli değiştirmek için haritada '
                'çizime dokun → Şekil.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                        'Henüz çizim yok. Araçlardan mesafe/alan çizip '
                        'üst şeritteki yer-imi butonuyla kaydedin.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final g = list[i];
                      return ListTile(
                        onTap: () => showEditGraphicDialog(context, ref, g),
                        leading: Icon(
                          graphicIcon(g.type),
                          color: Color(g.colorValue),
                        ),
                        title: Text(g.name),
                        subtitle: Text(
                          '${g.type.label} · ${graphicMeasure(g)}'
                          '${g.dashed ? ' · kesikli' : ''}'
                          '${g.height == null ? '' : ' · 3B ${g.height!.round()} m'}'
                          '${g.geofence == null ? '' : ' · geofence: ${g.geofence!.label.toLowerCase()}'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Çizgi boyunca yükseklik profili (F2).
                            if (g.type == GraphicType.line &&
                                g.points.length >= 2)
                              IconButton(
                                icon: const Icon(Icons.area_chart_outlined),
                                tooltip: 'Yükseklik profili: ${g.name}',
                                onPressed: () => showElevationProfilePanel(
                                  context,
                                  title: '${g.name}: yükseklik profili',
                                  points: g.points,
                                ),
                              ),
                            // Kapalı şekle giriş / çıkış uyarısı (G3).
                            if (g.closed)
                              IconButton(
                                icon: Icon(
                                  Icons.fence,
                                  color: g.geofence == null
                                      ? null
                                      : Colors.orangeAccent,
                                ),
                                tooltip: 'Geofence: ${g.name}',
                                onPressed: () =>
                                    showGeofenceDialog(context, ref, g),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Sil',
                              onPressed: () async {
                                final repo = ref.read(
                                  mapGraphicRepositoryProvider,
                                );
                                if (await confirmDeleteNamed(context, g.name)) {
                                  await repo.delete(g.id!);
                                }
                              },
                            ),
                          ],
                        ),
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
