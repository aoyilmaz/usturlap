import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_math.dart';
import '../../domain/models/map_graphic.dart';
import '../../providers/graphic_providers.dart';

/// Kayıtlı taktik grafikler paneli: renk/tip/ölçü göster, sil.
Future<void> showGraphicListSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
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
                        leading: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Color(g.colorValue),
                            shape: g.type == GraphicType.area
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        title: Text(g.name),
                        subtitle: Text(
                          '${g.type.label} · ${_measure(g)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Sil',
                          onPressed: () => ref
                              .read(mapGraphicRepositoryProvider)
                              .delete(g.id!),
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

  /// Tipe göre kısa ölçü metni (çizgi → uzunluk, alan → alan + çevre).
  String _measure(MapGraphic g) {
    if (g.type == GraphicType.area && g.points.length >= 3) {
      return '${GeoMath.fmtArea(GeoMath.polygonArea(g.points))}'
          ' · ${g.points.length} köşe';
    }
    return '${GeoMath.fmtDistance(GeoMath.pathLength(g.points))}'
        ' · ${g.points.length} nokta';
  }
}
