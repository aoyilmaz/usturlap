import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/bearing_format.dart';
import '../../core/coord_format.dart';
import '../../core/coord_parse.dart';
import '../../core/geo_math.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Konumu düzelt (ATAK self-marker ince ayar / polar giriş, kılavuz s.8):
/// GPS yokken ya da hatalıyken konumu elle ver. Haritada dokunarak
/// ([onPickOnMap]), koordinat yazarak ya da bilinen bir noktadan kerteriz
/// ve mesafeyle. Konum verilince [onApplied].
Future<void> showManualPositionSheet(
  BuildContext context, {
  required VoidCallback onPickOnMap,
  required ValueChanged<LatLng> onApplied,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'manual-position',
    isScrollControlled: true,
    builder: (_) =>
        ManualPositionPanel(onPickOnMap: onPickOnMap, onApplied: onApplied),
  );
}

class ManualPositionPanel extends ConsumerStatefulWidget {
  const ManualPositionPanel({
    super.key,
    required this.onPickOnMap,
    required this.onApplied,
  });

  final VoidCallback onPickOnMap;
  final ValueChanged<LatLng> onApplied;

  @override
  ConsumerState<ManualPositionPanel> createState() =>
      _ManualPositionPanelState();
}

class _ManualPositionPanelState extends ConsumerState<ManualPositionPanel> {
  final _coord = TextEditingController();
  final _bearing = TextEditingController();
  final _distance = TextEditingController();
  int? _landmarkId;
  String? _coordError;
  String? _polarError;

  @override
  void dispose() {
    _coord.dispose();
    _bearing.dispose();
    _distance.dispose();
    super.dispose();
  }

  void _apply(LatLng p) {
    ref.read(manualPositionProvider.notifier).set(p);
    Navigator.of(context).pop();
    widget.onApplied(p);
  }

  void _applyCoord() {
    final p = CoordParse.parse(_coord.text);
    if (p == null) {
      setState(() => _coordError = 'Koordinat anlaşılamadı');
      return;
    }
    _apply(p);
  }

  static double? _number(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  void _applyPolar(List<Waypoint> waypoints, BearingFormatter fmt) {
    final wp = waypoints.where((w) => w.id == _landmarkId).firstOrNull;
    final b = _number(_bearing.text);
    final d = _number(_distance.text);
    final full = fmt.unit == AngleUnit.mils ? 6400.0 : 360.0;
    final String? error = wp == null
        ? 'Bir nokta seç'
        : b == null || b < 0 || b >= full
        ? 'Kerteriz 0 ile ${full.toInt()} arasında olmalı'
        : d == null || d <= 0 || d > 100000
        ? 'Mesafe 0 ile 100 000 m arasında olmalı'
        : null;
    if (error != null) {
      setState(() => _polarError = error);
      return;
    }
    final deg = fmt.unit == AngleUnit.mils ? b! * 360 / 6400 : b!;
    // Kerteriz ayarlardaki kuzeye göre girilir (el pusulası: manyetik).
    final trueDeg = NorthMath.toTrue(deg, wp!.position, fmt.ref);
    _apply(GeoMath.positionFromSighting(wp.position, trueDeg, d!));
  }

  @override
  Widget build(BuildContext context) {
    final manual = ref.watch(manualPositionProvider);
    final waypoints = ref.watch(waypointsProvider).value ?? const <Waypoint>[];
    final fmt = ref.watch(bearingFormatterProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final unit = fmt.unit == AngleUnit.mils ? 'mil' : '°';

    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text(
          'Konumu düzelt',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'GPS yokken ya da hatalıyken konumunu elle ver. "GPS\'e dön" '
          'diyene kadar haritada ve konum kutusunda bu konum kullanılır; '
          'iz kaydı GPS\'le sürer.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        if (manual != null) ...[
          const SizedBox(height: 12),
          Text(
            'Şu an elle: ${CoordFormat.mgrs(manual)}',
            style: const TextStyle(color: Colors.orangeAccent),
          ),
          const SizedBox(height: 6),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.gps_fixed),
            label: const Text('GPS\'e dön'),
            onPressed: () {
              ref.read(manualPositionProvider.notifier).clear();
              Navigator.of(context).pop();
            },
          ),
        ],
        section('Haritada'),
        OutlinedButton.icon(
          icon: const Icon(Icons.touch_app_outlined),
          label: const Text('Haritada dokunarak göster'),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onPickOnMap();
          },
        ),
        section('Koordinat'),
        TextField(
          controller: _coord,
          decoration: InputDecoration(
            hintText: 'MGRS, UTM ya da enlem boylam',
            errorText: _coordError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_coordError != null) setState(() => _coordError = null);
          },
          onSubmitted: (_) => _applyCoord(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _applyCoord,
            child: const Text('Uygula'),
          ),
        ),
        section('Bilinen noktadan'),
        Text(
          'Kayıtlı bir noktayı hangi yönde, ne kadar uzakta görüyorsun?',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 8),
        if (waypoints.isEmpty)
          Text('Kayıtlı nokta yok.', style: TextStyle(color: muted))
        else ...[
          DropdownButtonFormField<int>(
            initialValue: _landmarkId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Nokta',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final w in waypoints)
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) => setState(() {
              _landmarkId = v;
              _polarError = null;
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bearing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Kerteriz ($unit, ${fmt.ref.label})',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _distance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Mesafe (m)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (_polarError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _polarError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => _applyPolar(waypoints, fmt),
              child: const Text('Uygula'),
            ),
          ),
        ],
      ],
    );
  }
}
