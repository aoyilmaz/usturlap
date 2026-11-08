import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/bearing_format.dart';
import '../../core/coord_format.dart';
import '../../core/geo_math.dart';
import '../../core/sequential_name.dart';
import '../../domain/models/waypoint.dart';
import '../../domain/usecases/resection.dart';
import '../../providers/location_providers.dart';
import '../../providers/resection_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Geriden kestirme (ATAK Resection, kılavuz s.50): bilinen 2–3 noktaya
/// pusulayla alınan kerterizlerden konum ve hata alanı. Haritada nişan
/// çizgileri ve hata alanı canlı görünür; sonuç elle konum yapılabilir.
Future<void> showResectionPanel(
  BuildContext context, {
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'resection',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => ResectionPanel(onCenter: onCenter),
  );
}

class ResectionPanel extends ConsumerStatefulWidget {
  const ResectionPanel({super.key, required this.onCenter});

  final ValueChanged<LatLng> onCenter;

  @override
  ConsumerState<ResectionPanel> createState() => _ResectionPanelState();
}

class _Row {
  int? waypointId;
  final bearing = TextEditingController();
}

class _ResectionPanelState extends ConsumerState<ResectionPanel> {
  static const _sigmas = [1.0, 2.0, 5.0];

  final _rows = [_Row(), _Row()];
  double _sigma = Resection.defaultSigma;
  late final ResectionPreviewNotifier _preview;

  @override
  void initState() {
    super.initState();
    _preview = ref.read(resectionPreviewProvider.notifier);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.bearing.dispose();
    }
    // Ağaç kapanırken sağlayıcı değiştirilemez: bir sonraki turda temizle.
    final preview = _preview;
    scheduleMicrotask(() => preview.show(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waypoints = ref.watch(waypointsProvider).value ?? const <Waypoint>[];
    final byId = {for (final w in waypoints) w.id: w};
    final fmt = ref.watch(bearingFormatterProvider);
    final format = ref.watch(coordFormatProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final unit = fmt.unit == AngleUnit.mils ? 'mil' : '°';

    // Nişanlar ve satır hataları (yalnız yazılmış ama geçersiz kerteriz).
    final sightings = <Sighting>[];
    final errors = <int, String>{};
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final wp = byId[row.waypointId];
      final text = row.bearing.text.trim();
      if (wp == null || text.isEmpty) continue;
      final t = fmt.parseToTrue(text, wp.position);
      if (t == null) {
        errors[i] = fmt.unit == AngleUnit.mils ? '0–6400' : '0–360';
        continue;
      }
      sightings.add(Sighting(wp.position, t));
    }
    final result = sightings.length >= 2
        ? Resection.solve(sightings, sigma: _sigma)
        : null;
    // Haritadaki önizleme (çizim bittikten sonra; build içinde sağlayıcı
    // değiştirilmez).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _preview.show(
        sightings.isEmpty
            ? null
            : ResectionPreview(
                sightings,
                result ?? const ResectionResult.failed(ResectionFailure.tooFew),
              ),
      );
    });

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text(
          'Geriden kestirme',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Bilinen 2–3 noktaya pusulayla kerteriz al; konumun ve hata alanı '
          'bulunur. En iyisi aralarında ~90° olan noktalar. Kerteriz '
          '${fmt.ref.label.toLowerCase()} kuzeye göre ($unit).',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: byId.containsKey(_rows[i].waypointId)
                        ? _rows[i].waypointId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Nokta ${i + 1}'),
                    items: [
                      for (final w in waypoints)
                        DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) => setState(() => _rows[i].waypointId = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _rows[i].bearing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Kerteriz $unit',
                      errorText: errors[i],
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_rows.length > 2)
                  IconButton(
                    tooltip: 'Noktayı çıkar',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _rows.removeAt(i).bearing.dispose();
                    }),
                  ),
              ],
            ),
          ),
        if (_rows.length < 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(_Row())),
              icon: const Icon(Icons.add),
              label: const Text('Üçüncü nokta (daha güvenilir)'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            'Pusula hassasiyeti',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final s in _sigmas)
              ChoiceChip(
                label: Text('±${s.round()}°'),
                selected: _sigma == s,
                onSelected: (_) => setState(() => _sigma = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._result(result, format, muted),
      ],
    );
  }

  List<Widget> _result(
    ResectionResult? r,
    CoordFormatType format,
    Color muted,
  ) {
    if (r == null) {
      return [
        Text(
          'En az iki nokta ve kerteriz gir.',
          style: TextStyle(color: muted),
        ),
      ];
    }
    final failure = r.failure;
    if (failure != null) {
      return [
        Text(switch (failure) {
          ResectionFailure.tooFew => 'En az iki nişan gerekli.',
          ResectionFailure.parallel =>
            'Çizgiler neredeyse paralel: aralarında daha geniş açı olan '
                'noktalar seç.',
          ResectionFailure.behind =>
            'Kerterizler tutarsız: bir nokta bulunan yerin arkasında kalıyor. '
                'Okumayı (ters kerteriz?) ve noktayı kontrol et.',
        }, style: const TextStyle(color: Colors.redAccent)),
      ];
    }
    final p = r.position!;
    final err = '± ${GeoMath.fmtDistance(r.errorRadius)}';
    return [
      Text(
        CoordFormat.format(p, format),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      Text('Hata alanı: $err'),
      if (r.weak)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Kesişme açısı dar (${r.bestAngle.round()}°): sonuç güvenilmez. '
            'Aralarında ~90° olan noktalar seç.',
            style: const TextStyle(color: Colors.amber),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _useAsMyPosition(p, err),
            icon: const Icon(Icons.person_pin_circle),
            label: const Text('Konumum yap'),
          ),
          OutlinedButton.icon(
            onPressed: () => _saveAsPoint(p, err),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Nokta olarak kaydet'),
          ),
          OutlinedButton.icon(
            onPressed: () => widget.onCenter(p),
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Ortala'),
          ),
        ],
      ),
    ];
  }

  void _useAsMyPosition(LatLng p, String err) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    ref.read(manualPositionProvider.notifier).set(p);
    Navigator.of(context).pop();
    widget.onCenter(p);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Elle konum: geriden kestirme ($err). GPS\'e dönmek için kendi '
          'işaretine dokun.',
        ),
      ),
    );
  }

  Future<void> _saveAsPoint(LatLng p, String err) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final names = [
      for (final w in ref.read(waypointsProvider).value ?? const <Waypoint>[])
        w.name,
    ];
    final name = nextSequentialName('KESTİRME', names);
    await ref
        .read(waypointRepositoryProvider)
        .add(name: name, position: p, note: 'Geriden kestirme, hata $err');
    messenger?.showSnackBar(SnackBar(content: Text('$name kaydedildi.')));
  }
}
