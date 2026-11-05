import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coord_format.dart';
import '../../providers/location_providers.dart';

/// Koordinat: kendi konumun ve artı imlecin koordinatı — üç biçimde, kopyala.
/// İmleçteki noktayı kaydet ya da hedef yap.
Future<void> showCoordinateSheet(
  BuildContext context, {
  required LatLng crosshair,
  required void Function(LatLng p) onSaveHere,
  required void Function(LatLng p) onNavigateHere,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _CoordinateSheet(
      crosshair: crosshair,
      onSaveHere: onSaveHere,
      onNavigateHere: onNavigateHere,
    ),
  );
}

class _CoordinateSheet extends ConsumerWidget {
  const _CoordinateSheet({
    required this.crosshair,
    required this.onSaveHere,
    required this.onNavigateHere,
  });

  final LatLng crosshair;
  final void Function(LatLng p) onSaveHere;
  final void Function(LatLng p) onNavigateHere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfContactProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text('Koordinat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _Block(
              title: 'Konumum',
              point: self?.position,
              extra: self?.accuracyMeters == null
                  ? null
                  : 'GPS ±${self!.accuracyMeters!.round()} m',
            ),
            const SizedBox(height: 16),
            _Block(title: 'Artı imleç (harita merkezi)', point: crosshair),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSaveHere(crosshair);
                    },
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Nokta kaydet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNavigateHere(crosshair);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Git & yön bul'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.point, this.extra});

  final String title;
  final LatLng? point;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final p = point;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (extra != null)
              Text(extra!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        if (p == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Konum bekleniyor…'),
          )
        else
          for (final f in CoordFormatType.values) _CopyLine(format: f, point: p),
      ],
    );
  }
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({required this.format, required this.point});
  final CoordFormatType format;
  final LatLng point;

  @override
  Widget build(BuildContext context) {
    final text = CoordFormat.format(point, format);
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        HapticFeedback.selectionClick();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kopyalandı: $text')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: 58,
                child: Text(format.label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12))),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
            const Icon(Icons.copy, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
