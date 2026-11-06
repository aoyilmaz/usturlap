import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coord_format.dart';
import '../../providers/repeater_providers.dart';
import '../../providers/settings_providers.dart';
import 'adaptive_sheet.dart';

/// ⚙ Ayarlar: görünüm, koordinat biçimi, callsign, iz filtresi, röleler.
Future<void> showSettingsSheet(BuildContext context) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final night = ref.watch(nightModeProvider);
    final format = ref.watch(coordFormatProvider);
    final callsign = ref.watch(callsignProvider);
    final accFilter = ref.watch(accuracyFilterProvider);
    final repeatersOn = ref.watch(showRepeatersProvider);
    final repeaterCount = ref.watch(repeatersProvider).value?.length ?? 0;
    final band = ref.watch(repeaterBandProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Ayarlar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              secondary: Icon(
                  night ? Icons.nightlight_round : Icons.nightlight_outlined,
                  color: night ? Colors.redAccent : null),
              title: const Text('Gece modu'),
              subtitle: const Text('Işık disiplini — karartma + kırmızı'),
              value: night,
              onChanged: (_) => ref.read(nightModeProvider.notifier).toggle(),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Callsign'),
              subtitle: Text(callsign),
              trailing: const Icon(Icons.edit),
              onTap: () => _editCallsign(context, ref, callsign),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.grid_on, color: Colors.grey),
                  const SizedBox(width: 16),
                  const Text('Koordinat'),
                  const Spacer(),
                  SegmentedButton<CoordFormatType>(
                    segments: [
                      for (final f in CoordFormatType.values)
                        ButtonSegment(value: f, label: Text(f.label)),
                    ],
                    selected: {format},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      // Notifier yalnızca döngü sunuyor: hedefe kadar ilerlet.
                      final n = ref.read(coordFormatProvider.notifier);
                      while (ref.read(coordFormatProvider) != s.first) {
                        n.cycle();
                      }
                    },
                  ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.gps_fixed),
              title: const Text('İz doğruluk filtresi'),
              subtitle: const Text('Düşük doğruluklu (>20 m) noktaları atla'),
              value: accFilter,
              onChanged: (_) =>
                  ref.read(accuracyFilterProvider.notifier).toggle(),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.cell_tower),
              title: const Text('Telsiz röleleri'),
              subtitle: Text('Haritada göster ($repeaterCount röle)'),
              value: repeatersOn,
              onChanged: (_) =>
                  ref.read(showRepeatersProvider.notifier).toggle(),
            ),
            if (repeatersOn)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Band:', style: TextStyle(color: Colors.grey)),
                    for (final b in const [null, 'VHF', 'UHF'])
                      ChoiceChip(
                        label: Text(b ?? 'Tümü'),
                        selected: band == b,
                        onSelected: (_) =>
                            ref.read(repeaterBandProvider.notifier).set(b),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _editCallsign(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    void save(BuildContext c) {
      ref.read(callsignProvider.notifier).set(ctrl.text);
      Navigator.of(c).pop();
    }

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Callsign'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Callsign'),
          onSubmitted: (_) => save(c),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('İptal')),
          FilledButton(onPressed: () => save(c), child: const Text('Kaydet')),
        ],
      ),
    );
  }
}
