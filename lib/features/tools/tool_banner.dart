import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bearing_format.dart';
import '../../core/geo_math.dart';
import '../../core/sequential_name.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/waypoint_providers.dart';
import 'save_graphic_dialog.dart';

/// İki noktalı ölçümü kalıcı R&B çizgisi yapar (ATAK R&B Line): ad sıra
/// numaralı (R&B-1…), nesneye dokunularak konan uç o nesneye bağlı kalır.
/// Kaydedince ölçüm noktaları temizlenir; araç açık kalır.
Future<void> saveRangeLine(BuildContext context, WidgetRef ref) async {
  final tool = ref.read(toolProvider);
  if (tool.points.length != 2) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final existing = ref.read(rangeLinesProvider).value ?? const <RangeLine>[];
  final name = nextSequentialName('R&B', [for (final l in existing) l.name]);
  final start = RbEnd(tool.points[0], tool.refAt(0));
  final end = RbEnd(tool.points[1], tool.refAt(1));
  await ref
      .read(rangeLineRepositoryProvider)
      .add(name: name, start: start, end: end);
  ref.read(toolProvider.notifier).clearPoints();
  final linked = [start, end].where((e) => e.ref != null).length;
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        linked == 0
            ? '$name kaydedildi.'
            : '$name kaydedildi; $linked ucu nesneye bağlı, onunla hareket eder.',
      ),
    ),
  );
}

/// Aktif aracın ölçüm şeridi: değer + kaydet · göster/gizle · geri al · temizle.
/// Range Tools çubuğunun (RangeToolsBar) altında durur.
/// Menzil halkası aracını kalıcı halka grubu yapar (ATAK R&B Circle):
/// R, 2R, 3R; ad HALKA-1…; merkez bir nesneye dokunularak konduysa ona bağlı.
/// Düşman / şüpheli noktası merkezliyse tehdit halkası (kırmızı).
Future<void> saveRangeRing(BuildContext context, WidgetRef ref) async {
  final tool = ref.read(toolProvider);
  if (tool.points.length != 2) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final existing = ref.read(rangeRingsProvider).value ?? const <RangeRing>[];
  final name = nextSequentialName('HALKA', [for (final r in existing) r.name]);
  final center = RbEnd(tool.points[0], tool.refAt(0));
  final r = GeoMath.distance(tool.points[0], tool.points[1]);
  final threat = ref
          .read(waypointsProvider)
          .value
          ?.where((w) => w.uid == center.waypointUid)
          .any((w) =>
              w.affiliation == Affiliation.hostile ||
              w.affiliation == Affiliation.suspect) ??
      false;
  await ref.read(rangeRingRepositoryProvider).add(
        name: name,
        center: center,
        radii: RangeRing.evenRadii(r),
        colorValue: threat ? RangeRing.threatColor : RangeLine.defaultColor,
      );
  ref.read(toolProvider.notifier).clearPoints();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        '$name kaydedildi${center.ref == null ? '' : '; merkez nesneye bağlı'}. '
        'Mesafeleri etikete dokunup Detay\'dan değiştirebilirsin.',
      ),
    ),
  );
}

class ToolBanner extends ConsumerWidget {
  const ToolBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    if (!tool.active) return const SizedBox.shrink();

    final notifier = ref.read(toolProvider.notifier);
    // Gece modunda kırmızı tonla (gece görüşü).
    final night = ref.watch(nightModeProvider);
    final accent = night ? Colors.redAccent : Colors.amberAccent;
    final fmt = ref.watch(bearingFormatterProvider);

    // İki noktalı mesafe → kalıcı R&B çizgisi; daha uzun yol / alan →
    // kalıcı grafik.
    final rangeLine =
        tool.mode == ToolMode.distance && tool.points.length == 2;
    final ring = tool.mode == ToolMode.rangeRings && tool.points.length == 2;
    final GraphicType? savable;
    if (tool.mode == ToolMode.distance && tool.points.length >= 3) {
      savable = GraphicType.line;
    } else if (tool.mode == ToolMode.polygon && tool.points.length >= 3) {
      savable = GraphicType.area;
    } else {
      savable = null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(_icon(tool.mode), size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _measurement(tool, fmt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.bookmark_add_outlined,
                color: savable == null && !rangeLine && !ring
                    ? Colors.white24
                    : accent,
                size: 20),
            tooltip: rangeLine
                ? 'R&B çizgisi olarak kaydet'
                : ring
                    ? 'Halkayı kaydet'
                    : 'Çizimi kaydet',
            onPressed: rangeLine
                ? () => saveRangeLine(context, ref)
                : ring
                    ? () => saveRangeRing(context, ref)
                    : savable == null
                    ? null
                    : () => showSaveGraphicDialog(context, ref,
                        type: savable!, points: tool.points),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(tool.visible ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70, size: 20),
            tooltip: tool.visible ? 'Çizimi gizle' : 'Çizimi göster',
            onPressed: notifier.toggleVisible,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo, color: Colors.white70, size: 20),
            tooltip: 'Geri al',
            onPressed: tool.points.isEmpty ? null : notifier.undo,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.layers_clear, color: Colors.white70, size: 20),
            tooltip: 'Temizle',
            onPressed: tool.points.isEmpty ? null : notifier.clearPoints,
          ),
        ],
      ),
    );
  }

  IconData _icon(ToolMode m) {
    switch (m) {
      case ToolMode.distance:
        return Icons.straighten;
      case ToolMode.polygon:
        return Icons.pentagon_outlined;
      case ToolMode.sector:
        return Icons.pie_chart_outline;
      case ToolMode.none:
        return Icons.straighten;
      case ToolMode.lineOfSight:
        return Icons.landscape_outlined;
      case ToolMode.rangeRings:
        return Icons.radar;
    }
  }

  String _measurement(ToolState tool, BearingFormatter fmt) {
    final pts = tool.points;
    switch (tool.mode) {
      case ToolMode.distance:
        if (pts.length < 2) return 'Mesafe: nokta koyun (${pts.length})';
        if (pts.length == 2) {
          // Mesafe-kerteriz çizgisi: ileri + ters kerteriz.
          final b = (GeoMath.bearing(pts[0], pts[1]) + 360) % 360;
          return 'Mesafe: ${GeoMath.fmtDistance(GeoMath.distance(pts[0], pts[1]))}'
              ' · KRT ${fmt.format(b, pts[0])} (ters ${fmt.format(b + 180, pts[1])})';
        }
        return 'Mesafe: ${GeoMath.fmtDistance(GeoMath.pathLength(pts))}'
            ' · ${pts.length} nokta';
      case ToolMode.polygon:
        if (pts.length < 3) {
          return 'Alan: en az 3 köşe (${pts.length})';
        }
        return 'Alan: ${GeoMath.fmtArea(GeoMath.polygonArea(pts))}'
            ' · Çevre: ${GeoMath.fmtDistance(GeoMath.polygonPerimeter(pts))}';
      case ToolMode.sector:
        if (pts.isEmpty) return 'Sektör: merkezi seçin';
        if (pts.length == 1) return 'Sektör: yarıçap/başlangıç için dokunun';
        final r = GeoMath.distance(pts[0], pts[1]);
        if (pts.length == 2) {
          return 'Sektör: bitiş kerterizi için dokunun · R=${GeoMath.fmtDistance(r)}';
        }
        final b1 = GeoMath.bearing(pts[0], pts[1]);
        final b2 = GeoMath.bearing(pts[0], pts[2]);
        var sweep = (b2 - b1) % 360;
        if (sweep <= 0) sweep += 360;
        return 'Sektör: R=${GeoMath.fmtDistance(r)} · ${sweep.round()}°';
      case ToolMode.none:
        return '';
      case ToolMode.lineOfSight:
        if (pts.isEmpty) return 'Görüş Hattı: 1. noktayı seçin';
        if (pts.length == 1) return 'Görüş Hattı: 2. noktayı seçin';
        return 'Görüş Hattı: Analiz tamamlandı';
      case ToolMode.rangeRings:
        if (pts.isEmpty) return 'Menzil halkası: merkezi seçin';
        if (pts.length == 1) return 'Menzil halkası: yarıçap için dokunun';
        final r = GeoMath.distance(pts[0], pts[1]);
        return 'Menzil: R=${GeoMath.fmtDistance(r)} · ${GeoMath.fmtDistance(2 * r)}'
            ' · ${GeoMath.fmtDistance(3 * r)}';
    }
  }
}
