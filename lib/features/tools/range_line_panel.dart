import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/elevation_providers.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';
import 'measure_common.dart';

/// R&B çizgisi detayı (ATAK R&B Line, kılavuz s.12): uçlar, mesafe,
/// kerteriz / ters kerteriz, yükseklik farkı ve eğim açısı. Uçlar bağlıysa
/// değerler canlı güncellenir. Panel modal değil: harita kullanılabilir.
Future<void> showRangeLinePanel(
  BuildContext context, {
  required int lineId,
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'rb:$lineId',
    isScrollControlled: true,
    builder: (_) => RangeLinePanel(lineId: lineId, onCenter: onCenter),
  );
}

class RangeLinePanel extends ConsumerWidget {
  const RangeLinePanel({
    super.key,
    required this.lineId,
    required this.onCenter,
  });

  final int lineId;
  final ValueChanged<LatLng> onCenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref
        .watch(resolvedRangeLinesProvider)
        .where((r) => r.line.id == lineId)
        .firstOrNull;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Bu R&B çizgisi silinmiş.'),
      );
    }
    final fmt = ref.watch(bearingFormatterProvider);
    final format = ref.watch(coordFormatProvider);
    final wps = {
      for (final w in ref.watch(waypointsProvider).value ?? const <Waypoint>[])
        w.uid: w,
    };

    // Ucun yüksekliği: bağlı noktada elle girilen, yoksa arazi verisi.
    double? elevation(RbEnd e, LatLng at) {
      final manual = wps[e.waypointUid]?.elevation;
      if (manual != null) return manual;
      return ref.watch(terrainElevationProvider(at)).value?.toDouble();
    }

    final m = RbMeasure.between(
      r.from,
      r.to,
      elevationFrom: elevation(r.line.start, r.from),
      elevationTo: elevation(r.line.end, r.to),
    );
    String endText(RbEnd e, LatLng at) => anchorDescription(e, at, wps, format);

    String elevText(double? v) => v == null ? '—' : '${v.round()} m';

    final slope = m.slopeDeg;
    final rise = m.rise;
    final slopeText = slope == null
        ? 'Eğim: yükseklik verisi yok'
        : 'Eğim: ${slope >= 0 ? '↗' : '↘'} '
              '${slope.abs().toStringAsFixed(1)}° '
              '(${rise! >= 0 ? '+' : '−'}${rise.abs().round()} m)';

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          r.line.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        MeasureRow('Başlangıç', endText(r.line.start, r.from)),
        MeasureRow('Bitiş', endText(r.line.end, r.to)),
        const Divider(height: 24),
        MeasureRow('Mesafe', GeoMath.fmtDistance(m.meters)),
        MeasureRow('Kerteriz', fmt.format(m.bearing, r.from)),
        MeasureRow('Ters kerteriz', fmt.format(m.backBearing, r.to)),
        MeasureRow(
          'Yükseklik',
          '${elevText(m.elevationFrom)} → ${elevText(m.elevationTo)}',
        ),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(slopeText)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => onCenter(r.middle),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Ortala'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final repo = ref.read(rangeLineRepositoryProvider);
                final name = await promptRename(context, r.line.name);
                if (name != null) await repo.rename(r.line.id!, name);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Yeniden adlandır'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                // Panel kapanınca ref kullanılamaz: depoyu önce al.
                final repo = ref.read(rangeLineRepositoryProvider);
                if (await confirmDeleteNamed(context, r.line.name) &&
                    context.mounted) {
                  Navigator.of(context).pop();
                  await repo.delete(r.line.id!);
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
