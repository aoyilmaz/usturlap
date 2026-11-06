import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/bearing_format.dart';
import '../../core/coord_format.dart';
import '../../core/coord_parse.dart';
import '../../core/nav_math.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import 'adaptive_sheet.dart';

/// Koordinat: koordinat gir (MGRS/UTM/ondalık-DMS) → haritada göster, nokta
/// kaydet, git. Altta konumum ve artı imleç — üç biçimde, dokun-kopyala.
///
/// Eylemler girilen geçerli koordinata uygulanır; giriş yoksa artı imlece.
Future<void> showCoordinateSheet(
  BuildContext context, {
  required LatLng crosshair,
  required void Function(LatLng p) onShowOnMap,
  required void Function(LatLng p) onSaveHere,
  required void Function(LatLng p) onNavigateHere,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      // Klavye açılınca sayfa yukarı kaysın.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CoordinateSheet(
        crosshair: crosshair,
        onShowOnMap: onShowOnMap,
        onSaveHere: onSaveHere,
        onNavigateHere: onNavigateHere,
      ),
    ),
  );
}

enum _Mode { mgrs, utm, text }

class _CoordinateSheet extends ConsumerStatefulWidget {
  const _CoordinateSheet({
    required this.crosshair,
    required this.onShowOnMap,
    required this.onSaveHere,
    required this.onNavigateHere,
  });

  final LatLng crosshair;
  final void Function(LatLng p) onShowOnMap;
  final void Function(LatLng p) onSaveHere;
  final void Function(LatLng p) onNavigateHere;

  @override
  ConsumerState<_CoordinateSheet> createState() => _CoordinateSheetState();
}

class _CoordinateSheetState extends ConsumerState<_CoordinateSheet> {
  _Mode _mode = _Mode.mgrs;

  // MGRS alanları (bölge + 100 km kare imleçten önceden dolu).
  late final _gzd = TextEditingController();
  late final _square = TextEditingController();
  final _mE = TextEditingController();
  final _mN = TextEditingController();

  // UTM alanları (bölge imleçten önceden dolu).
  late final _zone = TextEditingController();
  final _uE = TextEditingController();
  final _uN = TextEditingController();

  // Serbest metin (ondalık / DMS / tam MGRS / tam UTM).
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    final parts = CoordFormat.mgrs(widget.crosshair).split(' ');
    if (parts.length == 4) {
      _gzd.text = parts[0];
      _square.text = parts[1];
    }
    final u = CoordFormat.utm(widget.crosshair).split(' ');
    if (u.isNotEmpty) _zone.text = u.first;
  }

  @override
  void dispose() {
    for (final c in [_gzd, _square, _mE, _mN, _zone, _uE, _uN, _text]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Girilen koordinat (geçersiz/eksikse null).
  LatLng? get _entered {
    switch (_mode) {
      case _Mode.mgrs:
        if (_mE.text.isEmpty && _mN.text.isEmpty) return null;
        return CoordParse.mgrsParts(
            gzd: _gzd.text,
            square: _square.text,
            easting: _mE.text,
            northing: _mN.text);
      case _Mode.utm:
        if (_uE.text.isEmpty && _uN.text.isEmpty) return null;
        final m = RegExp(r'^(\d{1,2})\s*([A-Za-z])$').firstMatch(_zone.text.trim());
        final e = double.tryParse(_uE.text.trim());
        final n = double.tryParse(_uN.text.trim());
        if (m == null || e == null || n == null) return null;
        return CoordParse.utmParts(
            zone: int.parse(m.group(1)!), band: m.group(2)!, easting: e, northing: n);
      case _Mode.text:
        return CoordParse.parse(_text.text);
    }
  }

  bool get _hasInput => switch (_mode) {
        _Mode.mgrs => _mE.text.isNotEmpty || _mN.text.isNotEmpty,
        _Mode.utm => _uE.text.isNotEmpty || _uN.text.isNotEmpty,
        _Mode.text => _text.text.trim().isNotEmpty,
      };

  @override
  Widget build(BuildContext context) {
    final self = ref.watch(selfContactProvider);
    final entered = _entered;
    final target = entered ?? widget.crosshair;

    Widget actions() => Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onShowOnMap(target);
                },
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Göster'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSaveHere(target);
                },
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Kaydet'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNavigateHere(target);
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Git'),
              ),
            ),
          ],
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text('Koordinat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(value: _Mode.mgrs, label: Text('MGRS')),
                ButtonSegment(value: _Mode.utm, label: Text('UTM')),
                ButtonSegment(value: _Mode.text, label: Text('Ondalık / DMS')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 10),
            ..._fields(),
            const SizedBox(height: 8),
            _Result(
              hasInput: _hasInput,
              entered: entered,
              self: self?.position,
              fmt: ref.watch(bearingFormatterProvider),
            ),
            const SizedBox(height: 8),
            Text(
              entered != null
                  ? 'Eylemler girilen koordinata uygulanır.'
                  : 'Giriş yoksa eylemler artı imlece uygulanır.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            actions(),
            const Divider(height: 28),
            _Block(
              title: 'Konumum',
              point: self?.position,
              extra: self?.accuracyMeters == null
                  ? null
                  : 'GPS ±${self!.accuracyMeters!.round()} m',
            ),
            const SizedBox(height: 16),
            _Block(title: 'Artı imleç (harita merkezi)', point: widget.crosshair),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    InputDecoration dec(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        );
    const digits = TextInputType.number;
    final onlyDigits = [FilteringTextInputFormatter.digitsOnly];
    void changed(String _) => setState(() {});

    switch (_mode) {
      case _Mode.mgrs:
        return [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _gzd,
                decoration: dec('Bölge (GZD)', hint: '36S'),
                textCapitalization: TextCapitalization.characters,
                onChanged: changed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _square,
                decoration: dec('100 km kare', hint: 'VK'),
                textCapitalization: TextCapitalization.characters,
                onChanged: changed,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _mE,
                decoration: dec('Doğu (1–5 hane)', hint: '88549'),
                keyboardType: digits,
                inputFormatters: [...onlyDigits, LengthLimitingTextInputFormatter(5)],
                onChanged: changed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mN,
                decoration: dec('Kuzey (aynı hane)', hint: '19452'),
                keyboardType: digits,
                inputFormatters: [...onlyDigits, LengthLimitingTextInputFormatter(5)],
                onChanged: changed,
              ),
            ),
          ]),
        ];
      case _Mode.utm:
        return [
          TextField(
            controller: _zone,
            decoration: dec('Bölge + bant', hint: '36S'),
            textCapitalization: TextCapitalization.characters,
            onChanged: changed,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _uE,
                decoration: dec('Doğu (E)', hint: '488549'),
                keyboardType: digits,
                inputFormatters: onlyDigits,
                onChanged: changed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _uN,
                decoration: dec('Kuzey (N)', hint: '4419452'),
                keyboardType: digits,
                inputFormatters: onlyDigits,
                onChanged: changed,
              ),
            ),
          ]),
        ];
      case _Mode.text:
        return [
          TextField(
            controller: _text,
            decoration: dec('Koordinat',
                hint: "39.9251, 32.866  ·  39°55'30\"K 32°51'57\"D"),
            onChanged: changed,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Ondalık, derece-dakika-saniye, tam MGRS ya da UTM yazabilirsiniz. '
              'Yön: N/S/E/W ya da K/G/D/B.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ];
    }
  }
}

/// Girişin çözüm sonucu: geçerliyse diğer biçimler + konumuma göre konum.
class _Result extends StatelessWidget {
  const _Result({
    required this.hasInput,
    required this.entered,
    this.self,
    this.fmt = const BearingFormatter(),
  });

  final bool hasInput;
  final LatLng? entered;
  final LatLng? self;
  final BearingFormatter fmt;

  @override
  Widget build(BuildContext context) {
    if (!hasInput) return const SizedBox.shrink();
    final p = entered;
    if (p == null) {
      return const Row(children: [
        Icon(Icons.error_outline, color: Colors.orangeAccent, size: 18),
        SizedBox(width: 6),
        Text('Koordinat eksik ya da geçersiz',
            style: TextStyle(color: Colors.orangeAccent)),
      ]);
    }
    final rel = self == null
        ? ''
        : ' · konumumdan ${_fmtDist(NavMath.distance(self!, p))} '
            '${fmt.format(NavMath.bearing(self!, p), self!)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${CoordFormat.mgrs(p)}\n${CoordFormat.wgs84(p)}$rel',
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }

  static String _fmtDist(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(2)} km';
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.point, this.extra});

  final String title;
  final LatLng? point;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final p = point;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (extra != null)
              Text(extra!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        if (p == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Konum bekleniyor…'),
          )
        else
          for (final f in CoordFormatType.values) _CopyLine(format: f, point: p),
      ],
    );
  }
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({required this.format, required this.point});
  final CoordFormatType format;
  final LatLng point;

  @override
  Widget build(BuildContext context) {
    final text = CoordFormat.format(point, format);
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        HapticFeedback.selectionClick();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Kopyalandı: $text')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: 58,
                child: Text(format.label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12))),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
            const Icon(Icons.copy, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
