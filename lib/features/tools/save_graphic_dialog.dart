import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/map_graphic.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/tool_providers.dart';

/// Aktif araç çizimini (çizgi/alan) kalıcı taktik grafik olarak kaydeder.
/// Ad + renk sorar; kaydedince aracın noktalarını temizler.
Future<void> showSaveGraphicDialog(
  BuildContext context,
  WidgetRef ref, {
  required GraphicType type,
  required List<LatLng> points,
}) async {
  final count = ref.read(mapGraphicsProvider).value?.length ?? 0;
  final defaultName =
      '${type == GraphicType.area ? "ALAN" : "ÇİZGİ"}-${count + 1}';
  final nameCtrl = TextEditingController(text: defaultName);
  var color = _palette.first;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(type == GraphicType.area
                ? 'Alanı kaydet'
                : 'Çizgiyi kaydet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'İsim'),
                ),
                const SizedBox(height: 14),
                const Text('Renk',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final c in _palette)
                      GestureDetector(
                        onTap: () => setLocal(() => color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c
                                  ? Colors.white
                                  : Colors.black26,
                              width: color == c ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Text('${points.length} nokta',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      ? defaultName
                      : nameCtrl.text.trim();
                  await ref.read(mapGraphicRepositoryProvider).add(
                        name: name,
                        type: type,
                        points: points,
                        colorValue: color,
                      );
                  // Kaydedildi: aracın geçici noktalarını temizle.
                  ref.read(toolProvider.notifier).clearPoints();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Sade renk paleti (ARGB).
const List<int> _palette = [
  0xFFE03131, // kırmızı
  0xFF2E7DFF, // mavi
  0xFF2FB344, // yeşil
  0xFFF2B500, // sarı
  0xFF15AABF, // camgöbeği
  0xFFFFFFFF, // beyaz
];
