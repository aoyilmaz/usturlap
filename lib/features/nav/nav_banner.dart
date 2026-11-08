import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_math.dart';
import '../../core/nav_math.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/settings_providers.dart';

/// Buluşma satırı (E7): "Buluşma 14:30 · gereken 4.2 km/h · 3 dk geç".
/// Hareket ediyorsam (≥ 0,5 m/s) şimdiki hızla erken / geç de söylenir.
({String text, bool late}) rendezvousLine({
  required double meters,
  required DateTime arriveBy,
  required DateTime now,
  double? speedMps,
}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final hhmm = '${two(arriveBy.hour)}:${two(arriveBy.minute)}';
  final remaining = arriveBy.difference(now);
  if (remaining.inSeconds <= 0) {
    return (text: 'Buluşma $hhmm · saat geçti', late: true);
  }
  final kmh = meters / remaining.inSeconds * 3.6;
  final parts = ['Buluşma $hhmm', 'gereken ${kmh.toStringAsFixed(1)} km/h'];
  var late = false;
  if (speedMps != null && speedMps >= 0.5) {
    final eta = Duration(seconds: (meters / speedMps).round());
    final diff = now.add(eta).difference(arriveBy); // + = geç
    final m = diff.inMinutes.abs();
    late = diff.inSeconds > 0;
    parts.add(late ? '$m dk geç' : (m == 0 ? 'zamanında' : '$m dk erken'));
  }
  return (text: parts.join(' · '), late: late);
}

/// Aktif "Git" hedefine kerteriz + mesafe gösteren şerit (HUD'un altında).
///
/// Bloodhound (ATAK) gibi: gidiş yönüne göre dönüş ("sağa 35°") ve tahmini
/// varış (hız yoksa yürüyüş hızıyla, "~" ile) da gösterilir.
class NavBanner extends ConsumerWidget {
  const NavBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(navTargetProvider);
    if (target == null) return const SizedBox.shrink();

    final self = ref.watch(selfContactProvider);
    final night = ref.watch(nightModeProvider);
    final accent = night ? Colors.redAccent : Colors.limeAccent;
    final fmt = ref.watch(bearingFormatterProvider);

    String info;
    String? detail;
    ({String text, bool late})? meet;
    if (self == null) {
      info = 'Konum bekleniyor…';
    } else {
      final brg = NavMath.bearing(self.position, target.position);
      final dist = NavMath.distance(self.position, target.position);
      info = 'KRT ${fmt.format(brg, self.position)}  ·  ${GeoMath.fmtDistance(dist)}';
      final parts = <String>[];
      final moving = (self.speedMps ?? 0) >= 0.5;
      if (self.headingDeg != null && moving) {
        parts.add(NavMath.fmtTurn(
            NavMath.relativeBearing(brg, self.headingDeg!)));
      }
      final eta = NavMath.eta(dist, self.speedMps);
      if (eta != null && dist > 20) {
        final at = DateTime.now().add(eta);
        final hhmm = '${at.hour.toString().padLeft(2, '0')}:'
            '${at.minute.toString().padLeft(2, '0')}';
        parts.add('${moving ? '' : '~'}${NavMath.fmtDuration(eta)} ($hhmm)');
      }
      if (dist <= 20) parts.add('hedefe vardınız');
      if (parts.isNotEmpty) detail = parts.join('  ·  ');
      final arriveBy = target.arriveBy;
      if (arriveBy != null && dist > 20) {
        meet = rendezvousLine(
          meters: dist,
          arriveBy: arriveBy,
          now: DateTime.now(),
          speedMps: self.speedMps,
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.navigation, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('→ ${target.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(info,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()])),
                if (detail != null)
                  Text(detail,
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                if (meet != null)
                  Text(meet.text,
                      style: TextStyle(
                          color: meet.late ? Colors.orangeAccent : accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.schedule,
                color: target.arriveBy == null ? Colors.white70 : accent,
                size: 20),
            tooltip: 'Buluşma saati',
            onPressed: () => _pickArrival(context, ref, target.arriveBy),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Navigasyonu durdur',
            onPressed: () => ref.read(navTargetProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }

  /// Buluşma saati seç / değiştir / kaldır. Geçmiş bir saat seçilirse
  /// ertesi gün sayılır (ör. 23:00'te 01:00).
  Future<void> _pickArrival(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    final notifier = ref.read(navTargetProvider.notifier);
    if (current != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Buluşma saati'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('clear'),
              child: const Text('Kaldır'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('change'),
              child: const Text('Değiştir'),
            ),
          ],
        ),
      );
      if (action == 'clear') notifier.setArriveBy(null);
      if (action != 'change' || !context.mounted) return;
    }
    final now = DateTime.now();
    final initial = current ?? now.add(const Duration(minutes: 30));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Hedefte hangi saatte olmalısın?',
    );
    if (picked == null) return;
    var at = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    notifier.setArriveBy(at);
  }
}
