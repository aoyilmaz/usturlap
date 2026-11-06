import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_math.dart';
import '../../core/nav_math.dart';
import '../../providers/location_providers.dart';
import '../../providers/route_providers.dart';
import '../../providers/settings_providers.dart';

// ------------------------------------------------------------- planlama

/// Rota planlama çubuğunun yüksekliği (güvenli alan hariç).
const double kPlanBarHeight = 72;

/// Planlama modunda ekranın altında:
/// Geri al · Temizle · (+ Nokta) · Kaydet · Çık.
/// (D2'de ATAK tarzı araç alt çubuğuna dönüşecek.)
class RoutePlanBar extends ConsumerWidget {
  const RoutePlanBar({super.key, required this.onAddAtCrosshair});

  /// Artı imleçteki (haritanın ortası) noktayı rotaya ekle.
  final VoidCallback onAddAtCrosshair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(routePlanningProvider);
    final n = ref.read(routePlanningProvider.notifier);
    final has = plan.points.isNotEmpty;

    Widget btn(IconData icon, String label, VoidCallback? onTap,
            {Color? color}) =>
        Expanded(
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: onTap == null ? Colors.white24 : (color ?? Colors.white70),
                    size: 26),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: onTap == null
                            ? Colors.white24
                            : (color ?? Colors.white70),
                        fontSize: 11)),
              ],
            ),
          ),
        );

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kPlanBarHeight,
          child: Row(
            children: [
              btn(Icons.undo, 'Geri al', has ? n.undo : null),
              btn(Icons.layers_clear, 'Temizle', has ? n.clear : null),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onAddAtCrosshair();
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.amber),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.black, size: 28),
                          Text('Nokta',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              btn(Icons.save, 'Kaydet',
                  plan.points.length >= 2 ? () => _save(context, ref) : null,
                  color: Colors.amber),
              btn(Icons.close, 'Çık', () => _exit(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final count = ref.read(routesProvider).value?.length ?? 0;
    final ctrl = TextEditingController(text: 'Rota ${count + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rotayı kaydet'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Rota adı'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (name == null) return;
    final trimmed = name.trim().isEmpty ? 'Rota ${count + 1}' : name.trim();
    final route = await ref.read(routePlanningProvider.notifier).save(trimmed);
    if (route == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('“$trimmed” kaydedildi · ${GeoMath.fmtDistance(route.length)}'),
      action: SnackBarAction(
        label: 'TAKİP ET',
        onPressed: () => ref.read(activeRouteProvider.notifier).start(route),
      ),
    ));
  }

  Future<void> _exit(BuildContext context, WidgetRef ref) async {
    final plan = ref.read(routePlanningProvider);
    if (plan.points.length >= 2) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Planlamadan çık'),
          content: const Text('Kaydedilmemiş noktalar silinecek.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Çık ve sil')),
          ],
        ),
      );
      if (ok != true) return;
    }
    ref.read(routePlanningProvider.notifier).cancel();
  }
}

/// Planlama sırasında üstte: toplam mesafe + nokta sayısı + ipucu.
class RoutePlanInfo extends ConsumerWidget {
  const RoutePlanInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(routePlanningProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alt_route, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              plan.points.isEmpty
                  ? 'Rota planla: imleci yerleştirip "+ Nokta" ya da haritaya dokunun'
                  : 'MESAFE ${GeoMath.fmtDistance(plan.length)}  ·  '
                      'NOKTA ${plan.points.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- takip

/// Rota takip paneli (alt çubuğun üstünde).
class RouteFollowPanel extends ConsumerWidget {
  const RouteFollowPanel({super.key, this.night = false});
  final bool night;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeRouteProvider);
    if (active == null) return const SizedBox.shrink();
    final self = ref.watch(selfContactProvider);
    final fmt = ref.watch(bearingFormatterProvider);
    final p = active.progress;
    final n = ref.read(activeRouteProvider.notifier);
    final ok = night ? Colors.redAccent : Colors.lightGreenAccent;
    final warn = night ? Colors.red.shade300 : Colors.orangeAccent;

    String status;
    Color statusColor;
    if (p == null) {
      status = 'KONUM BEKLENİYOR';
      statusColor = Colors.white70;
    } else if (p.finished) {
      status = 'VARDINIZ';
      statusColor = ok;
    } else if (p.toStart) {
      status = 'BAŞLANGIÇ NOKTASINA';
      statusColor = Colors.amber;
    } else if (p.offRoute) {
      final side = p.crossTrack > 0 ? 'sağında' : 'solunda';
      status = 'ROTADAN SAPTINIZ · ${p.crossTrack.abs().round()} m $side';
      statusColor = warn;
    } else {
      status = 'ROTADASINIZ';
      statusColor = ok;
    }

    String turn = '';
    if (p != null && !p.finished && self?.headingDeg != null &&
        (self!.speedMps ?? 0) >= 0.5) {
      turn = NavMath.fmtTurn(
          NavMath.relativeBearing(p.bearingToNext, self.headingDeg!));
    }
    final eta = p == null ? null : NavMath.eta(p.remaining, self?.speedMps);
    final moving = (self?.speedMps ?? 0) >= 0.5;
    String etaText = '—';
    if (eta != null && p != null && !p.finished) {
      final at = DateTime.now().add(eta);
      etaText = '${moving ? '' : '~'}${NavMath.fmtDuration(eta)}\n'
          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    }

    Widget metric(String label, String value, {String? sub}) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()])),
              if (sub != null && sub.isNotEmpty)
                Text(sub,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        );

    final leg = p == null || p.toStart
        ? 'BAŞLANGIÇ'
        : p.finished
            ? 'BİTTİ'
            : 'AYAK ${p.targetIndex}/${p.legCount}';

    return Card(
      color: Colors.black.withValues(alpha: 0.85),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(leg,
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(active.route.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Önceki nokta',
                  icon: const Icon(Icons.skip_previous, color: Colors.white70),
                  onPressed: n.back,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Sonraki nokta (atla)',
                  icon: const Icon(Icons.skip_next, color: Colors.white70),
                  onPressed: n.skip,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Takibi bitir',
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: n.stop,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(status,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (p != null && !p.finished)
              Row(
                children: [
                  metric('SONRAKİ', GeoMath.fmtDistance(p.distToNext)),
                  metric(
                      'KERTERİZ',
                      self == null
                          ? GeoMath.fmtBearing(p.bearingToNext)
                          : fmt.format(p.bearingToNext, self.position),
                      sub: turn),
                  metric('KALAN', GeoMath.fmtDistance(p.remaining)),
                  metric('VARIŞ', etaText),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
