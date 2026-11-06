import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_math.dart';
import '../../core/nav_math.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/settings_providers.dart';

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

    String info;
    String? detail;
    if (self == null) {
      info = 'Konum bekleniyor…';
    } else {
      final brg = NavMath.bearing(self.position, target.position);
      final dist = NavMath.distance(self.position, target.position);
      info = 'KRT ${GeoMath.fmtBearing(brg)}  ·  ${GeoMath.fmtDistance(dist)}';
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
              ],
            ),
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
}
