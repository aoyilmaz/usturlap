import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/usecases/terrain_grid.dart';
import '../../providers/location_providers.dart';
import '../../providers/terrain_analysis_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Arazi analizi (ATAK Contour Lines s.49, eğim / yükseklik s.48): seçilen
/// alanda eş yükselti eğrileri ve renkli eğim / yükseklik katmanı.
Future<void> showTerrainAnalysisPanel(
  BuildContext context, {
  required LatLng Function() mapCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'terrain',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => TerrainAnalysisPanel(mapCenter: mapCenter),
  );
}

class TerrainAnalysisPanel extends ConsumerStatefulWidget {
  const TerrainAnalysisPanel({super.key, required this.mapCenter});

  final LatLng Function() mapCenter;

  static const radii = <double>[1000, 2000, 5000, 10000];

  /// null = otomatik.
  static const intervals = <double?>[null, 10, 20, 50, 100];

  @override
  ConsumerState<TerrainAnalysisPanel> createState() =>
      _TerrainAnalysisPanelState();
}

class _TerrainAnalysisPanelState extends ConsumerState<TerrainAnalysisPanel> {
  double _radius = 2000;
  double? _interval;
  TerrainColorMode _mode = TerrainColorMode.slope;
  bool _useMapCenter = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terrainAnalysisProvider);
    final n = ref.read(terrainAnalysisProvider.notifier);
    final self = ref.watch(selfContactProvider)?.position;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final useCenter = _useMapCenter || self == null;
    final busy = state?.busy == true;

    LatLng center() => useCenter ? widget.mapCenter() : self;

    Widget caption(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );

    Widget chips<T>(
      List<T> values,
      T selected,
      String Function(T) label,
      ValueChanged<T> onPick,
    ) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => setState(() => onPick(v)),
          ),
      ],
    );

    final range = state?.range;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Arazi analizi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Cihazdaki arazi verisiyle seçilen alanda eş yükselti eğrileri ve '
          'renkli eğim / yükseklik katmanı.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        caption('Alan'),
        SegmentedButton<bool>(
          segments: [
            const ButtonSegment(
              value: true,
              icon: Icon(Icons.center_focus_strong),
              label: Text('Harita ortası'),
            ),
            ButtonSegment(
              value: false,
              enabled: self != null,
              icon: const Icon(Icons.my_location),
              label: const Text('Konumum'),
            ),
          ],
          selected: {useCenter},
          onSelectionChanged: (v) => setState(() => _useMapCenter = v.single),
        ),
        const SizedBox(height: 8),
        chips(
          TerrainAnalysisPanel.radii,
          _radius,
          (r) => '${GeoMath.fmtDistance(r)} çevresi',
          (r) => _radius = r,
        ),
        caption('Eş yükselti eğrileri'),
        chips(
          TerrainAnalysisPanel.intervals,
          _interval,
          (i) => i == null ? 'Otomatik' : '${i.round()} m',
          (i) => _interval = i,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () =>
                        n.drawContours(center(), _radius, interval: _interval),
              icon: const Icon(Icons.stacked_line_chart),
              label: const Text('Eğrileri çiz'),
            ),
            if (state?.contours.isNotEmpty == true)
              OutlinedButton(
                onPressed: n.clearContours,
                child: const Text('Kaldır'),
              ),
          ],
        ),
        if (state?.interval != null && state!.contours.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Aralık ${state.interval!.round()} m · '
              '${state.contours.length} eğri'
              '${range == null ? '' : ' · ${range.$1.round()}–${range.$2.round()} m'}',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        caption('Renkli katman'),
        SegmentedButton<TerrainColorMode>(
          segments: [
            for (final m in TerrainColorMode.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.single),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => n.drawColor(center(), _radius, _mode),
              icon: const Icon(Icons.gradient),
              label: const Text('Katmanı çiz'),
            ),
            if (state?.image != null)
              OutlinedButton(
                onPressed: n.clearColor,
                child: const Text('Kaldır'),
              ),
          ],
        ),
        if (state?.colorMode == TerrainColorMode.slope && state?.image != null)
          const _SlopeLegend()
        else if (state?.colorMode == TerrainColorMode.elevation &&
            state?.image != null &&
            range != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Yeşil ${range.$1.round()} m → beyaz ${range.$2.round()} m',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (state?.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              state!.error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
      ],
    );
  }
}

class _SlopeLegend extends StatelessWidget {
  const _SlopeLegend();

  @override
  Widget build(BuildContext context) {
    Widget item((int, int, int) c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          color: Color.fromARGB(255, c.$1, c.$2, c.$3),
        ),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 12)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          item(TerrainGrid.slopeColor(5), '< 10°'),
          item(TerrainGrid.slopeColor(15), '10–20°'),
          item(TerrainGrid.slopeColor(25), '20–30°'),
          item(TerrainGrid.slopeColor(35), '> 30°'),
        ],
      ),
    );
  }
}
