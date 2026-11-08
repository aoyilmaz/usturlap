import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/models/bullseye.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/bullseye_providers.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';
import 'measure_common.dart';

/// Bullseye paneli (ATAK, kılavuz s.14): kur / taşı / kaldır, halka aralığı
/// ve sayısı, konumumun bullseye çağrısı. Panel modal değil: değişiklikler
/// haritada hemen görünür.
Future<void> showBullseyePanel(
  BuildContext context, {
  required LatLng Function() mapCenter,
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'bullseye',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => BullseyePanel(mapCenter: mapCenter, onCenter: onCenter),
  );
}

class BullseyePanel extends ConsumerWidget {
  const BullseyePanel({
    super.key,
    required this.mapCenter,
    required this.onCenter,
  });

  /// Haritanın o anki ortası ("Harita ortasına kur / taşı").
  final LatLng Function() mapCenter;
  final ValueChanged<LatLng> onCenter;

  static const _title = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rb = ref.watch(resolvedBullseyeProvider);
    final notifier = ref.read(bullseyeProvider.notifier);
    final self = ref.watch(selfContactProvider)?.position;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (rb == null) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('Bullseye', style: _title),
          const SizedBox(height: 6),
          Text(
            'Yerleri tek bir referans noktasına göre "kerteriz / mesafe" '
            'olarak bildirmek için. Bir noktayı bullseye yapmak için: '
            'noktaya dokun → Detay → Bullseye yap.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    notifier.set(Bullseye(center: RbEnd(mapCenter()))),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Harita ortasına kur'),
              ),
              OutlinedButton.icon(
                // Sabit nokta olarak: bullseye benimle hareket etmesin.
                onPressed: self == null
                    ? null
                    : () => notifier.set(Bullseye(center: RbEnd(self))),
                icon: const Icon(Icons.my_location),
                label: const Text('Konumuma kur'),
              ),
            ],
          ),
        ],
      );
    }

    final b = rb.bullseye;
    final fmt = ref.watch(bearingFormatterProvider);
    final format = ref.watch(coordFormatProvider);
    final wps = {
      for (final w in ref.watch(waypointsProvider).value ?? const <Waypoint>[])
        w.uid: w,
    };

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, color: muted)),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(b.name, style: _title),
        MeasureRow(
          'Merkez',
          anchorDescription(b.center, rb.center, wps, format),
        ),
        if (self != null && !b.center.isSelf)
          MeasureRow('Konumum', 'BE ${Bullseye.call(rb.center, self, fmt)}'),
        caption('Halka aralığı'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in Bullseye.spacingChoices)
              ChoiceChip(
                label: Text(GeoMath.fmtDistance(s)),
                selected: b.ringSpacing == s,
                onSelected: (_) =>
                    notifier.update((b) => b.copyWith(ringSpacing: s)),
              ),
          ],
        ),
        caption('Halka sayısı'),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Halka azalt',
              icon: const Icon(Icons.remove),
              onPressed: b.ringCount <= 1
                  ? null
                  : () => notifier.update(
                      (b) => b.copyWith(ringCount: b.ringCount - 1),
                    ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                '${b.ringCount} · ${GeoMath.fmtDistance(b.outerRadius)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Halka ekle',
              icon: const Icon(Icons.add),
              onPressed: b.ringCount >= Bullseye.maxRings
                  ? null
                  : () => notifier.update(
                      (b) => b.copyWith(ringCount: b.ringCount + 1),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => onCenter(rb.center),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Ortala'),
            ),
            OutlinedButton.icon(
              onPressed: () => notifier.update(
                (b) => b.copyWith(center: RbEnd(mapCenter())),
              ),
              icon: const Icon(Icons.open_with),
              label: const Text('Harita ortasına taşı'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final name = await promptRename(context, b.name);
                if (name != null) {
                  notifier.update((b) => b.copyWith(name: name));
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Yeniden adlandır'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                if (await confirmDeleteNamed(context, b.name)) {
                  notifier.set(null);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Kaldır'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sol alttaki bilgi şeridi: konumumun bullseye çağrısı ("BE 045° /
/// 2.30 km"). Bullseye yoksa, konum yoksa ya da merkez benimse görünmez.
class BullseyeBanner extends ConsumerWidget {
  const BullseyeBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rb = ref.watch(resolvedBullseyeProvider);
    final self = ref.watch(selfContactProvider)?.position;
    if (rb == null || self == null || rb.bullseye.center.isSelf) {
      return const SizedBox.shrink();
    }
    final night = ref.watch(nightModeProvider);
    final accent = night ? Colors.redAccent : Colors.white;
    final fmt = ref.watch(bearingFormatterProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        button: true,
        label: 'Bullseye',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.track_changes, size: 18, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'BE ${Bullseye.call(rb.center, self, fmt)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nokta detayında: noktanın bullseye çağrısı. Bullseye yoksa ya da bu
/// nokta bullseye'ın kendisiyse boş.
class BullseyeCallLine extends ConsumerWidget {
  const BullseyeCallLine({super.key, required this.waypoint});

  final Waypoint waypoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rb = ref.watch(resolvedBullseyeProvider);
    if (rb == null || rb.bullseye.center.waypointUid == waypoint.uid) {
      return const SizedBox.shrink();
    }
    final fmt = ref.watch(bearingFormatterProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'BE ${Bullseye.call(rb.center, waypoint.position, fmt)} '
        '(${rb.bullseye.name})',
      ),
    );
  }
}
