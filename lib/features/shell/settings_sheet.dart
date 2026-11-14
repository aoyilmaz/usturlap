import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bearing_format.dart';
import '../../core/coord_format.dart';
import '../../core/wmm.dart';
import '../../providers/alert_providers.dart';
import '../../providers/field_providers.dart';
import '../../providers/location_providers.dart';
import '../../providers/repeater_providers.dart';
import '../../providers/settings_providers.dart';
import 'adaptive_sheet.dart';
import 'clear_content_dialog.dart';

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
    final voice = ref.watch(voiceAlertsProvider);
    final keepOn = ref.watch(keepScreenOnProvider);
    final autoStop = ref.watch(trackAutoStopProvider);
    final lowBattery = ref.watch(lowBatteryAlertProvider);
    final repeatersOn = ref.watch(showRepeatersProvider);
    final repeaterCount = ref.watch(repeatersProvider).value?.length ?? 0;
    final band = ref.watch(repeaterBandProvider);
    final crosshair = ref.watch(crosshairProvider);
    final northRef = ref.watch(northRefProvider);
    final angleUnit = ref.watch(angleUnitProvider);
    final here = ref.watch(selfContactProvider)?.position;

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
            SwitchListTile(
              secondary: const Icon(Icons.center_focus_strong),
              title: const Text('Artı imleç'),
              subtitle: const Text(
                  'Haritanın ortasında; "Nokta bırak" oraya nokta koyar '
                  '(eldivenle kolay)'),
              value: crosshair,
              onChanged: (_) => ref.read(crosshairProvider.notifier).toggle(),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Callsign'),
              subtitle: Text(callsign),
              trailing: const Icon(Icons.edit),
              onTap: () => _editCallsign(context, ref, callsign),
            ),
            _ChipRow<CoordFormatType>(
              icon: Icons.grid_on,
              title: 'Koordinat',
              values: CoordFormatType.values,
              selected: format,
              label: (f) => f.label,
              onSelected: ref.read(coordFormatProvider.notifier).set,
            ),
            // Kerteriz: hangi kuzey, hangi birim (ATAK "Bearing Units").
            _ChipRow<NorthRef>(
              icon: Icons.explore_outlined,
              title: 'Kuzey',
              values: NorthRef.values,
              selected: northRef,
              label: (r) => r.label,
              onSelected: ref.read(northRefProvider.notifier).set,
            ),
            _ChipRow<AngleUnit>(
              icon: Icons.architecture,
              title: 'Açı birimi',
              values: AngleUnit.values,
              selected: angleUnit,
              label: (u) => u.label,
              onSelected: ref.read(angleUnitProvider.notifier).set,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
              child: Text(
                here == null
                    ? 'Manyetik sapma konum gelince hesaplanır (WMM2025).'
                    : 'Burada manyetik sapma ${_ew(Wmm.declination(here.latitude, here.longitude))}, '
                        'grid yakınsaması ${_ew(NorthMath.gridConvergence(here))} '
                        '(WMM2025, internetsiz). Hesaplar coğrafi kuzeyle yapılır; '
                        'seçim yalnızca gösterimi değiştirir.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            // Sesli uyarılar: rota takibi, geofence, takip ETA'sı.
            SwitchListTile(
              secondary: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Sesli uyarılar'),
              subtitle: const Text(
                'Rota, geofence ve takip uyarılarını okur. Ses düzeyi '
                'medya sesidir; telefon sessizdeyken de konuşur.',
              ),
              value: voice,
              onChanged: (v) => ref.read(voiceAlertsProvider.notifier).set(v),
            ),
            if (voice)
              Padding(
                padding: const EdgeInsets.only(left: 56, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => ref
                        .read(speakerProvider)
                        .speak('Sesli uyarılar açık. Rotadan saptınız.'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Sesi dene'),
                  ),
                ),
              ),
            // Saha konforu.
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('Ekranı açık tut'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final k in KeepScreenOn.values)
                          ChoiceChip(
                            label: Text(k.label),
                            selected: keepOn == k,
                            onSelected: (_) =>
                                ref.read(keepScreenOnProvider.notifier).set(k),
                          ),
                      ],
                    ),
                    const Text(
                      'Görevde: iz kaydı, rota takibi ya da Git hedefi varken.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('İz kaydı kendiliğinden dursun'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final m in TrackAutoStopNotifier.choices)
                      ChoiceChip(
                        label: Text(m == 0 ? 'Kapalı' : '${m ~/ 60} sa'),
                        selected: autoStop == m,
                        onSelected: (_) =>
                            ref.read(trackAutoStopProvider.notifier).set(m),
                      ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.battery_alert_outlined),
              title: const Text('Düşük pil uyarısı'),
              subtitle: const Text('%20, %10 ve %5\'te titreşim ve uyarı'),
              value: lowBattery,
              onChanged: (v) =>
                  ref.read(lowBatteryAlertProvider.notifier).set(v),
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
            const Divider(height: 24),
            // ATAK "Clear Content": tehlike anında bütün veriyi sil.
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Acil veri silme',
                  style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Bütün noktaları, izleri, ayarları kalıcı sil'),
              onTap: () => showClearContentDialog(context, ref),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 5.93 → "5.9° D", −1.2 → "1.2° B".
  static String _ew(double deg) =>
      '${deg.abs().toStringAsFixed(1)}° ${deg >= 0 ? 'D' : 'B'}';

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

/// Başlık + seçim çipleri (eldivenle seçilebilecek büyüklükte).
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.icon,
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(icon, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(title),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final v in values)
                      ChoiceChip(
                        label: Text(label(v)),
                        selected: v == selected,
                        onSelected: (_) => onSelected(v),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
