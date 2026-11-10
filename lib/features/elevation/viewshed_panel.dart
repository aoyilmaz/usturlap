import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/usecases/viewshed.dart';
import '../../providers/location_providers.dart';
import '../../providers/viewshed_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Görüş alanı (ATAK Viewshed, kılavuz s.48): bir noktadan nereler
/// görülür. Sonuç haritada yeşil (görünür) / kırmızı (görünmez) katman.
/// [observer] verilirse (ör. bir nokta) oradan; yoksa konumum ya da
/// harita ortası seçilir.
Future<void> showViewshedPanel(
  BuildContext context, {
  required LatLng Function() mapCenter,
  required ValueChanged<LatLng> onCenter,
  LatLng? observer,
  String? observerName,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'viewshed',
    isScrollControlled: true,
    builder: (_) => ViewshedPanel(
      mapCenter: mapCenter,
      onCenter: onCenter,
      observer: observer,
      observerName: observerName,
    ),
  );
}

class ViewshedPanel extends ConsumerStatefulWidget {
  const ViewshedPanel({
    super.key,
    required this.mapCenter,
    required this.onCenter,
    this.observer,
    this.observerName,
  });

  final LatLng Function() mapCenter;
  final ValueChanged<LatLng> onCenter;
  final LatLng? observer;
  final String? observerName;

  static const observerHeights = <double>[2, 5, 10, 30];
  static const targetHeights = <(double, String)>[
    (0, 'zemin'),
    (2, 'insan'),
    (4, 'araç'),
  ];
  static const radii = <double>[500, 1000, 2000, 5000, 10000];

  @override
  ConsumerState<ViewshedPanel> createState() => _ViewshedPanelState();
}

class _ViewshedPanelState extends ConsumerState<ViewshedPanel> {
  double _observerHeight = 2;
  double _targetHeight = 2;
  double _radius = 2000;

  /// Gözlemci noktası verilmediyse: konumum mu, harita ortası mı.
  bool _useMapCenter = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(viewshedProvider);
    final self = ref.watch(selfContactProvider)?.position;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final fixed = widget.observer;
    final useCenter = fixed == null && (_useMapCenter || self == null);

    Widget caption(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(t, style: TextStyle(fontSize: 12, color: muted)),
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

    void run() {
      final LatLng at;
      final String name;
      if (fixed != null) {
        at = fixed;
        name = widget.observerName ?? 'nokta';
      } else if (useCenter) {
        at = widget.mapCenter();
        name = 'harita ortası';
      } else {
        at = self!;
        name = 'konumum';
      }
      ref
          .read(viewshedProvider.notifier)
          .run(
            ViewshedParams(
              observer: at,
              observerHeight: _observerHeight,
              targetHeight: _targetHeight,
              radius: _radius,
            ),
            observerName: name,
          );
    }

    final grid = state?.grid;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Görüş alanı',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Bir noktadan nereleri görebileceğini cihazdaki arazi verisiyle '
          'hesaplar. Yeşil görünür, kırmızı görünmez (bitki örtüsü ve binalar '
          'hesaba katılmaz).',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        caption('Gözlemci'),
        if (fixed != null)
          Text(widget.observerName ?? 'Seçilen nokta')
        else
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                enabled: self != null,
                icon: const Icon(Icons.my_location),
                label: const Text('Konumum'),
              ),
              const ButtonSegment(
                value: true,
                icon: Icon(Icons.center_focus_strong),
                label: Text('Harita ortası'),
              ),
            ],
            selected: {useCenter},
            onSelectionChanged: (v) => setState(() => _useMapCenter = v.single),
          ),
        caption('Gözlemci yüksekliği (yerden)'),
        chips(
          ViewshedPanel.observerHeights,
          _observerHeight,
          (v) => '${v.round()} m',
          (v) => _observerHeight = v,
        ),
        caption('Görülecek hedef'),
        chips(
          ViewshedPanel.targetHeights,
          ViewshedPanel.targetHeights.firstWhere((t) => t.$1 == _targetHeight),
          (t) => '${t.$2} (${t.$1.round()} m)',
          (t) => _targetHeight = t.$1,
        ),
        caption('Yarıçap'),
        chips(
          ViewshedPanel.radii,
          _radius,
          GeoMath.fmtDistance,
          (v) => _radius = v,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: state?.busy == true ? null : run,
          icon: state?.busy == true
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility),
          label: Text(state?.busy == true ? 'Hesaplanıyor…' : 'Hesapla'),
        ),
        if (state?.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              state!.error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (state != null && grid != null) ...[
          const SizedBox(height: 12),
          Text(
            'Görünen: %${(grid.visibleFraction * 100).round()} · '
            '${grid.visibleKm2.toStringAsFixed(2)} km² '
            '(${state.observerName ?? 'gözlemci'}, '
            '${GeoMath.fmtDistance(state.params.radius)})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Gözlemci yeri ${grid.observerGround.round()} m · hücre '
            '${grid.cellMeters.round()} m',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onCenter(state.params.observer),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Ortala'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.read(viewshedProvider.notifier).clear(),
                icon: const Icon(Icons.layers_clear),
                label: const Text('Haritadan kaldır'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
