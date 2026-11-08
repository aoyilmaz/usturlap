import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';
import 'measure_common.dart';

/// Menzil / tehdit halkası detayı (ATAK R&B Circle, Threat Rings): merkez,
/// halka mesafeleri ve kendi konumumun hangi halkanın içinde olduğu.
/// Mesafeler tek tek düzenlenebilir (ör. silah menzilleri).
Future<void> showRangeRingPanel(
  BuildContext context, {
  required int ringId,
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'rr:$ringId',
    isScrollControlled: true,
    builder: (_) => RangeRingPanel(ringId: ringId, onCenter: onCenter),
  );
}

class RangeRingPanel extends ConsumerWidget {
  const RangeRingPanel({
    super.key,
    required this.ringId,
    required this.onCenter,
  });

  final int ringId;
  final ValueChanged<LatLng> onCenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref
        .watch(resolvedRangeRingsProvider)
        .where((r) => r.ring.id == ringId)
        .firstOrNull;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Bu halka silinmiş.'),
      );
    }
    final ring = r.ring;
    final format = ref.watch(coordFormatProvider);
    final fmt = ref.watch(bearingFormatterProvider);
    final self = ref.watch(selfContactProvider)?.position;
    final wps = {
      for (final w in ref.watch(waypointsProvider).value ?? const <Waypoint>[])
        w.uid: w,
    };

    // Kendi konumum halkaların neresinde (merkez ben değilsem).
    String? mine;
    if (self != null && !ring.center.isSelf && ring.radii.isNotEmpty) {
      final d = GeoMath.distance(r.center, self);
      final i = ring.ringIndexAt(d);
      final where = i == null
          ? 'bütün halkaların dışında'
          : '${i + 1}. halkanın içinde (${GeoMath.fmtDistance(ring.radii[i])})';
      final b = (GeoMath.bearing(r.center, self) % 360 + 360) % 360;
      mine =
          'Merkeze ${GeoMath.fmtDistance(d)}, ${fmt.format(b, r.center)} · '
          '$where';
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          ring.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        MeasureRow(
          'Merkez',
          anchorDescription(ring.center, r.center, wps, format),
        ),
        MeasureRow(
          'Halkalar',
          ring.radii.isEmpty
              ? '—'
              : ring.radii.map(GeoMath.fmtDistance).join(' · '),
        ),
        if (mine != null) MeasureRow('Konumum', mine),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => onCenter(r.center),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Ortala'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final repo = ref.read(rangeRingRepositoryProvider);
                final radii = await promptRadii(context, ring.radii);
                if (radii != null) await repo.setRadii(ring.id!, radii);
              },
              icon: const Icon(Icons.radar),
              label: const Text('Mesafeler'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final repo = ref.read(rangeRingRepositoryProvider);
                final name = await promptRename(context, ring.name);
                if (name != null) await repo.rename(ring.id!, name);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Yeniden adlandır'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                // Panel kapanınca ref kullanılamaz: depoyu önce al.
                final repo = ref.read(rangeRingRepositoryProvider);
                if (await confirmDeleteNamed(context, ring.name) &&
                    context.mounted) {
                  Navigator.of(context).pop();
                  await repo.delete(ring.id!);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Halka mesafelerini sorar ("500 1000 1,5km"). Vazgeçilirse null.
Future<List<double>?> promptRadii(BuildContext context, List<double> current) {
  final ctrl = TextEditingController(text: RangeRing.formatRadii(current));
  String? error;
  return showDialog<List<double>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) {
        void submit() {
          final v = RangeRing.parseRadii(ctrl.text);
          if (v == null) {
            setLocal(
              () => error =
                  '1 ile ${RangeRing.maxRings} arası mesafe girin '
                  '(1 m – ${(RangeRing.maxRadius / 1000).round()} km)',
            );
            return;
          }
          Navigator.of(context).pop(v);
        }

        return AlertDialog(
          title: const Text('Halka mesafeleri'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Mesafeler',
              helperText: 'Metre; boşlukla ayırın. Ör: 500 1000 1,5km',
              helperMaxLines: 2,
              errorText: error,
              errorMaxLines: 2,
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(onPressed: submit, child: const Text('Kaydet')),
          ],
        );
      },
    ),
  );
}
