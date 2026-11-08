import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/bearing_format.dart';
import '../../core/geo_math.dart';
import '../../core/nav_math.dart';
import '../../domain/models/bloodhound.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/bloodhound_providers.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';

/// ETA rengi: kırmızı yakın, sarı yaklaşıyor, yeşil uzak; ETA yoksa (iki
/// sabit nokta) beyaz. Anlam taşıdığı için gece modunda da değişmez.
Color etaColor(EtaLevel? level) => switch (level) {
  EtaLevel.close => Colors.redAccent,
  EtaLevel.near => Colors.amber,
  EtaLevel.far => Colors.lightGreenAccent,
  null => Colors.white70,
};

/// Ucun kısa adı: "Ben", noktanın adı ya da "nokta".
String bloodhoundEndName(RbEnd e, Map<String, Waypoint> waypointsByUid) {
  if (e.isSelf) return 'Ben';
  final uid = e.waypointUid;
  if (uid != null) return waypointsByUid[uid]?.name ?? 'silinmiş nokta';
  return 'nokta';
}

/// "045° · 1.20 km · ~12 dk (14:05)". [now] testte sabitlenir.
String bloodhoundText(
  BloodhoundReading r,
  LatLng from,
  BearingFormatter fmt, {
  DateTime? now,
}) {
  final parts = [fmt.format(r.bearing, from), GeoMath.fmtDistance(r.meters)];
  final eta = r.eta;
  if (eta != null) {
    final at = (now ?? DateTime.now()).add(eta);
    String two(int v) => v.toString().padLeft(2, '0');
    parts.add(
      '${r.estimated ? '~' : ''}${NavMath.fmtDuration(eta)} '
      '(${two(at.hour)}:${two(at.minute)})',
    );
  }
  return parts.join(' · ');
}

/// Takip paneli (ATAK Multiple Bloodhounds, kılavuz s.18–19): açık
/// takipler canlı, iki nokta arası takip ekleme, ETA renk eşikleri.
Future<void> showBloodhoundPanel(
  BuildContext context, {
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'bloodhound',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => BloodhoundPanel(onCenter: onCenter),
  );
}

class BloodhoundPanel extends ConsumerStatefulWidget {
  const BloodhoundPanel({super.key, required this.onCenter});

  final ValueChanged<LatLng> onCenter;

  @override
  ConsumerState<BloodhoundPanel> createState() => _BloodhoundPanelState();
}

class _BloodhoundPanelState extends ConsumerState<BloodhoundPanel> {
  /// Seçimler: `RbEnd.selfRef` ya da `wp:<uid>`.
  String _from = RbEnd.selfRef;
  String? _to;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(resolvedBloodhoundsProvider);
    final notifier = ref.read(bloodhoundsProvider.notifier);
    final thresholds = ref.watch(etaThresholdsProvider);
    final fmt = ref.watch(bearingFormatterProvider);
    final waypoints = ref.watch(waypointsProvider).value ?? const <Waypoint>[];
    final wps = {for (final w in waypoints) w.uid: w};
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    String title(Bloodhound b) =>
        '${bloodhoundEndName(b.from, wps)} → ${bloodhoundEndName(b.to, wps)}';

    // Seçilen nokta silinmişse seçim düşer.
    if (_to != null && !wps.containsKey(_to!.substring(3))) _to = null;
    if (_from != RbEnd.selfRef && !wps.containsKey(_from.substring(3))) {
      _from = RbEnd.selfRef;
    }

    // Uç: nokta ya da ben. Benim için kurulduğu andaki konumum saklanır;
    // GPS yoksa hedefin konumu (çizgi konum gelince uzar).
    RbEnd endOf(String choice, {required LatLng fallback}) {
      if (choice == RbEnd.selfRef) {
        final me = ref.read(selfContactProvider)?.position;
        return RbEnd(me ?? fallback, RbEnd.selfRef);
      }
      return RbEnd(wps[choice.substring(3)]!.position, choice);
    }

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );

    Widget stepper({
      required Color color,
      required String label,
      required int minutes,
      required ValueChanged<int> onChanged,
    }) => Row(
      children: [
        Icon(Icons.circle, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text('$label ≤ $minutes dk')),
        IconButton.outlined(
          tooltip: '$label eşiğini azalt',
          icon: const Icon(Icons.remove),
          onPressed: () => onChanged(minutes - 1),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: '$label eşiğini artır',
          icon: const Icon(Icons.add),
          onPressed: () => onChanged(minutes + 1),
        ),
      ],
    );

    final items = <DropdownMenuItem<String>>[
      for (final w in waypoints)
        DropdownMenuItem(value: RbEnd.waypointRef(w.uid), child: Text(w.name)),
    ];

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text(
          'Takip (Bloodhound)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Hedefe canlı kerteriz, mesafe ve varış süresi. Renk varış '
          'süresine göre; kırmızıya girince telefon titrer.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Henüz takip yok. Noktaya dokun → Takip; ya da aşağıdan iki '
              'nokta seç.',
              style: TextStyle(color: muted),
            ),
          ),
        for (final r in list)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 4),
            leading: Icon(Icons.pets, color: etaColor(r.reading.level)),
            title: Text(title(r.bloodhound)),
            subtitle: Text(bloodhoundText(r.reading, r.from, fmt)),
            onTap: () => widget.onCenter(r.to),
            trailing: IconButton(
              tooltip: 'Takibi kaldır: ${title(r.bloodhound)}',
              icon: const Icon(Icons.close),
              onPressed: () => notifier.remove(r.bloodhound.id),
            ),
          ),
        if (list.length > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: notifier.clear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Hepsini kaldır'),
            ),
          ),
        caption('Takip ekle'),
        DropdownButtonFormField<String>(
          initialValue: _from,
          decoration: const InputDecoration(labelText: 'Başlangıç'),
          items: [
            const DropdownMenuItem(value: RbEnd.selfRef, child: Text('Ben')),
            ...items,
          ],
          onChanged: (v) => setState(() => _from = v ?? RbEnd.selfRef),
        ),
        DropdownButtonFormField<String>(
          initialValue: _to,
          decoration: const InputDecoration(labelText: 'Hedef'),
          items: items,
          onChanged: (v) => setState(() => _to = v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _to == null || _to == _from
                ? null
                : () {
                    final to = endOf(_to!, fallback: const LatLng(0, 0));
                    final added = notifier.add(
                      endOf(_from, fallback: to.point),
                      to,
                    );
                    if (!added) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Bu takip zaten açık.')),
                      );
                    }
                  },
            icon: const Icon(Icons.pets),
            label: const Text('Takip ekle'),
          ),
        ),
        caption('Varış süresi renkleri'),
        stepper(
          color: etaColor(EtaLevel.near),
          label: 'Sarı',
          minutes: thresholds.warn.inMinutes,
          onChanged: (m) =>
              ref.read(etaThresholdsProvider.notifier).setMinutes(warn: m),
        ),
        stepper(
          color: etaColor(EtaLevel.close),
          label: 'Kırmızı',
          minutes: thresholds.alarm.inMinutes,
          onChanged: (m) =>
              ref.read(etaThresholdsProvider.notifier).setMinutes(alarm: m),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Varış süresi hızımdan hesaplanır; duruyorsam yürüyüş hızıyla '
            'tahmin edilir (~). İki nokta arasında hız olmadığı için süre ve '
            'renk yok.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    );
  }
}
