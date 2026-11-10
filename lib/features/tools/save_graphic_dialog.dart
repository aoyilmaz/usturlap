import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/sequential_name.dart';
import '../../domain/models/map_graphic.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/tool_providers.dart';
import 'graphic_labels.dart';

/// Kalınlık seçenekleri (mantıksal piksel).
const graphicStrokeWidths = <double>[2, 3, 5, 8];

/// 3B yükseklik seçenekleri (m); null = düz.
const graphicHeights = <double?>[null, 10, 25, 50, 100];

/// Aktif araç çizimini kalıcı taktik grafik olarak kaydeder (ATAK Drawing
/// Tools): ad, renk, kalınlık, kesikli stil. Kaydedince aracın noktalarını
/// temizler. [points]: dairede merkez + kenar, dikdörtgende 4 köşe.
Future<void> showSaveGraphicDialog(
  BuildContext context,
  WidgetRef ref, {
  required GraphicType type,
  required List<LatLng> points,
}) async {
  final names = [
    for (final g in ref.read(mapGraphicsProvider).value ?? const <MapGraphic>[])
      g.name,
  ];
  final defaultName = nextSequentialName(graphicPrefix(type), names);
  final nameCtrl = TextEditingController(text: defaultName);
  var color = graphicPalette.first;
  var width = MapGraphic.defaultStrokeWidth;
  var dashed = false;
  double? height;
  final closed = type != GraphicType.line;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          const caption = TextStyle(fontSize: 12, color: Colors.grey);
          return AlertDialog(
            title: Text('${type.label} kaydet'),
            content: SingleChildScrollView(
              child: Column(
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
                  const Text('Renk', style: caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final c in graphicPalette)
                        Semantics(
                          button: true,
                          selected: color == c,
                          label: 'Renk',
                          child: GestureDetector(
                            onTap: () => setLocal(() => color = c),
                            child: Container(
                              width: 36,
                              height: 36,
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
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Kalınlık', style: caption),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final w in graphicStrokeWidths)
                        ChoiceChip(
                          label: Text('${w.round()}'),
                          selected: width == w,
                          onSelected: (_) => setLocal(() => width = w),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kesikli çizgi'),
                    value: dashed,
                    onChanged: (v) => setLocal(() => dashed = v),
                  ),
                  // 3B: harita eğikken (pusula okuna uzun bas → 3B) kutu
                  // olarak yükselir (ATAK 3D Shapes).
                  if (closed) ...[
                    const Text('3B yükseklik', style: caption),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final h in graphicHeights)
                          ChoiceChip(
                            label: Text(h == null ? 'Düz' : '${h.round()} m'),
                            selected: height == h,
                            onSelected: (_) => setLocal(() => height = h),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    type == GraphicType.circle
                        ? 'Merkez + kenar'
                        : '${points.length} nokta',
                    style: caption,
                  ),
                ],
              ),
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
                  await ref
                      .read(mapGraphicRepositoryProvider)
                      .add(
                        name: name,
                        type: type,
                        points: points,
                        colorValue: color,
                        strokeWidth: width,
                        dashed: dashed,
                        height: closed ? height : null,
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
const List<int> graphicPalette = [
  0xFFE03131, // kırmızı
  0xFF2E7DFF, // mavi
  0xFF2FB344, // yeşil
  0xFFF2B500, // sarı
  0xFF15AABF, // camgöbeği
  0xFFFFFFFF, // beyaz
];
