import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bearing_format.dart';
import '../../core/geo_math.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/sensor_fov.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';

/// Menzil metni ("1500", "1,5km") → metre; geçersizse null.
double? parseFovRange(String text) {
  final v = RangeRing.parseRadii(text);
  if (v == null || v.length != 1) return null;
  final r = v.single;
  return r < SensorFov.minRange || r > SensorFov.maxRange ? null : r;
}

/// Nokta detayında görüş konisi satırı: yoksa "ekle", varsa özet +
/// düzenle / kaldır.
class FovSection extends ConsumerWidget {
  const FovSection({super.key, required this.waypoint});

  final Waypoint waypoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fov = waypoint.fov;
    final fmt = ref.watch(bearingFormatterProvider);
    final repo = ref.read(waypointRepositoryProvider);

    Future<void> edit() async {
      final v = await showFovDialog(context, waypoint);
      if (v == null) return;
      await repo.setFov(waypoint.id!, v.fov);
    }

    if (fov == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: edit,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Görüş konisi ekle'),
        ),
      );
    }
    return Row(
      children: [
        const Icon(Icons.visibility_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Görüş: ${fmt.format(fov.azimuth, waypoint.position)} · '
            '${fov.width.round()}° · ${GeoMath.fmtDistance(fov.range)}',
          ),
        ),
        TextButton(onPressed: edit, child: const Text('Düzenle')),
      ],
    );
  }
}

/// Görüş konisi penceresi. Sonuç: `(fov: …)` kaydet (null = kaldır);
/// vazgeçilirse null.
Future<({SensorFov? fov})?> showFovDialog(BuildContext context, Waypoint wp) {
  return showDialog<({SensorFov? fov})>(
    context: context,
    builder: (_) => _FovDialog(wp: wp),
  );
}

class _FovDialog extends ConsumerStatefulWidget {
  const _FovDialog({required this.wp});

  final Waypoint wp;

  @override
  ConsumerState<_FovDialog> createState() => _FovDialogState();
}

class _FovDialogState extends ConsumerState<_FovDialog> {
  final _azimuth = TextEditingController();
  final _range = TextEditingController();
  late double _width = widget.wp.fov?.width ?? 60;
  String? _azError, _rangeError;

  BearingFormatter get _fmt => ref.read(bearingFormatterProvider);

  /// Coğrafi kerterizi alanda kullanıcının kuzey/birimiyle yazılacak sayıya
  /// çevirir ("045", "0800").
  String _asInput(double trueDeg) {
    final v = NorthMath.fromTrue(trueDeg, widget.wp.position, _fmt.ref);
    return _fmt.unit == AngleUnit.mils
        ? '${(v * 6400 / 360).round() % 6400}'
        : '${v.round() % 360}';
  }

  @override
  void initState() {
    super.initState();
    final f = widget.wp.fov;
    if (f != null) {
      _azimuth.text = _asInput(f.azimuth);
      _range.text = f.range == f.range.roundToDouble()
          ? '${f.range.round()}'
          : '${f.range}';
    } else {
      _range.text = '1000';
    }
  }

  @override
  void dispose() {
    _azimuth.dispose();
    _range.dispose();
    super.dispose();
  }

  void _save() {
    final az = _fmt.parseToTrue(_azimuth.text, widget.wp.position);
    final range = parseFovRange(_range.text);
    setState(() {
      _azError = az == null
          ? (_fmt.unit == AngleUnit.mils ? '0–6400' : '0–360')
          : null;
      _rangeError = range == null ? '1 m – 100 km (ör. 800, 1,5km)' : null;
    });
    if (az == null || range == null) return;
    Navigator.of(
      context,
    ).pop((fov: SensorFov(azimuth: az, width: _width, range: range)));
  }

  @override
  Widget build(BuildContext context) {
    final heading = ref.watch(selfContactProvider)?.headingDeg;
    final unit = _fmt.unit == AngleUnit.mils ? 'mil' : '°';
    return AlertDialog(
      title: Text('${widget.wp.name}: görüş konisi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _azimuth,
                    autofocus: widget.wp.fov == null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Yön ($unit, ${_fmt.ref.label})',
                      errorText: _azError,
                    ),
                  ),
                ),
                // Noktada durup telefonu bakış yönüne çevir.
                IconButton(
                  tooltip: 'Yönü pusuladan al',
                  icon: const Icon(Icons.explore),
                  onPressed: heading == null
                      ? null
                      : () => setState(() => _azimuth.text = _asInput(heading)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Açıklık',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final w in [...SensorFov.widthChoices, 360.0])
                  ChoiceChip(
                    label: Text(w == 360 ? 'Her yön' : '${w.round()}°'),
                    selected: _width == w,
                    onSelected: (_) => setState(() => _width = w),
                  ),
              ],
            ),
            TextField(
              controller: _range,
              decoration: InputDecoration(
                labelText: 'Menzil (m; "km" eki olabilir)',
                errorText: _rangeError,
                errorMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.wp.fov != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop((fov: null)),
            child: const Text('Kaldır'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
