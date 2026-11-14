import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/coord_format.dart';
import '../../core/coord_parse.dart';
import '../../core/sequential_name.dart';
import '../../domain/models/field_report.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Saha raporları paneli (ATAK 9-Line, SPOTREP): form → metin; paylaş,
/// kopyala ya da haritaya not olarak ekle. Ağdan gönderme Faz 2'de.
Future<void> showReportsPanel(
  BuildContext context, {
  required LatLng Function() fallback,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'reports',
    toggle: true,
    isScrollControlled: true,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Raporlar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.medical_services_outlined, size: 32),
          title: const Text('CASEVAC 9 satır'),
          subtitle: const Text('Yaralı tahliye isteği'),
          onTap: () => _open(ctx, ReportKind.nineLine, fallback),
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined, size: 32),
          title: const Text('SPOTREP (SALUTE)'),
          subtitle: const Text('Düşman gözlem raporu'),
          onTap: () => _open(ctx, ReportKind.salute, fallback),
        ),
      ],
    ),
  );
}

void _open(BuildContext context, ReportKind kind, LatLng Function() fallback) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReportFormPage(kind: kind, fallback: fallback),
    ),
  );
}

enum ReportKind { nineLine, salute }

class ReportFormPage extends ConsumerStatefulWidget {
  const ReportFormPage({
    super.key,
    required this.kind,
    required this.fallback,
    this.clock,
  });

  final ReportKind kind;
  final LatLng Function() fallback;

  /// Test için sabit zaman.
  final DateTime Function()? clock;

  @override
  ConsumerState<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends ConsumerState<ReportFormPage> {
  final _nine = NineLine();
  late final SaluteReport _salute;
  final _location = TextEditingController();
  final _frequency = TextEditingController();
  final _callsign = TextEditingController();
  final _terrain = TextEditingController();
  final _remarks = TextEditingController();
  final _size = TextEditingController();
  final _activity = TextEditingController();
  final _unit = TextEditingController();
  final _equipment = TextEditingController();

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  bool get _isNine => widget.kind == ReportKind.nineLine;

  @override
  void initState() {
    super.initState();
    _salute = SaluteReport(time: _now());
    _callsign.text = ref.read(callsignProvider);
    // 9 satırda alım yeri çoğu zaman bulunduğum yer; SALUTE'ta gözlenen
    // düşman: harita ortası (artı imleç).
    _setLocation(
      _isNine
          ? ref.read(selfContactProvider)?.position ?? widget.fallback()
          : widget.fallback(),
    );
    for (final c in [
      _location,
      _frequency,
      _callsign,
      _terrain,
      _remarks,
      _size,
      _activity,
      _unit,
      _equipment,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _location,
      _frequency,
      _callsign,
      _terrain,
      _remarks,
      _size,
      _activity,
      _unit,
      _equipment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setLocation(LatLng p) => _location.text = CoordFormat.mgrs(p);

  String _text() {
    if (_isNine) {
      _nine
        ..location = _location.text.trim()
        ..frequency = _frequency.text.trim()
        ..callsign = _callsign.text.trim()
        ..terrain = _terrain.text.trim()
        ..remarks = _remarks.text.trim();
      return _nine.toText(_now());
    }
    _salute
      ..size = _size.text
      ..activity = _activity.text
      ..location = _location.text
      ..unit = _unit.text
      ..equipment = _equipment.text
      ..remarks = _remarks.text;
    return _salute.toText(_now());
  }

  Future<void> _addToMap() async {
    final messenger = ScaffoldMessenger.of(context);
    final p = CoordParse.parse(_location.text);
    if (p == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Konum okunamadı (MGRS ya da enlem, boylam).'),
        ),
      );
      return;
    }
    final prefix = _isNine ? 'CASEVAC' : 'SPOT';
    final names = [
      for (final w in ref.read(waypointsProvider).value ?? const <Waypoint>[])
        w.name,
    ];
    final name = nextSequentialName(prefix, names);
    await ref
        .read(waypointRepositoryProvider)
        .add(
          name: name,
          position: p,
          note: _text(),
          affiliation: _isNine ? Affiliation.rallyPoint : Affiliation.hostile,
        );
    messenger.showSnackBar(SnackBar(content: Text('$name haritaya eklendi.')));
  }

  Widget _counter(Code c, Map<String, int> m) {
    final n = m[c.letter] ?? 0;
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            c.letter,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(c.label)),
        IconButton(
          tooltip: '${c.label} azalt',
          iconSize: 30,
          onPressed: n == 0
              ? null
              : () => setState(
                  () => m[c.letter] = ((m[c.letter] ?? 0) - 1).clamp(0, 999),
                ),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$n',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: '${c.label} artır',
          iconSize: 30,
          // Güncel değerden: hızlı art arda basışlar kaybolmasın.
          onPressed: () => setState(() => m[c.letter] = (m[c.letter] ?? 0) + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _choices(List<Code> codes, String selected, ValueChanged<String> on) =>
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final c in codes)
            ChoiceChip(
              label: Text('${c.letter} · ${c.label}'),
              selected: selected == c.letter,
              onSelected: (_) => setState(() => on(c.letter)),
            ),
        ],
      );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  Widget _field(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: c,
          maxLines: lines,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final self = ref.watch(selfContactProvider)?.position;
    final text = _text();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNine ? 'CASEVAC 9 satır' : 'SPOTREP (SALUTE)'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _section(_isNine ? '1) Alım yeri' : 'L) Konum', [
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'MGRS ya da enlem, boylam',
                  border: OutlineInputBorder(),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: self == null ? null : () => _setLocation(self),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Konumum'),
                  ),
                  TextButton.icon(
                    onPressed: () => _setLocation(widget.fallback()),
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Harita ortası'),
                  ),
                ],
              ),
            ]),
            if (_isNine) ...[
              _section('2) Frekans ve çağrı adı', [
                _field(_frequency, 'Frekans'),
                _field(_callsign, 'Çağrı adı / sonek'),
              ]),
              _section('3) Önceliğe göre hasta sayısı', [
                for (final c in NineLine.precedence)
                  _counter(c, _nine.byPrecedence),
              ]),
              _section('4) Özel teçhizat', [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in NineLine.equipmentCodes)
                      FilterChip(
                        label: Text('${c.letter} · ${c.label}'),
                        selected: _nine.equipment.contains(c.letter),
                        onSelected: (on) => setState(() {
                          final s = {..._nine.equipment};
                          if (c.letter == 'A') {
                            s
                              ..clear()
                              ..add('A');
                          } else {
                            s.remove('A');
                            on ? s.add(c.letter) : s.remove(c.letter);
                            if (s.isEmpty) s.add('A');
                          }
                          _nine.equipment = s;
                        }),
                      ),
                  ],
                ),
              ]),
              _section('5) Türe göre hasta sayısı', [
                for (final c in NineLine.types) _counter(c, _nine.byType),
              ]),
              _section('6) Alım yerinde güvenlik', [
                _choices(
                  NineLine.securityCodes,
                  _nine.security,
                  (v) => _nine.security = v,
                ),
              ]),
              _section('7) Alım yeri işaretleme', [
                _choices(
                  NineLine.markingCodes,
                  _nine.marking,
                  (v) => _nine.marking = v,
                ),
              ]),
              _section('8) Uyruk ve statü', [
                for (final c in NineLine.nationality)
                  _counter(c, _nine.byNationality),
              ]),
              _section('9) KBRN kirlilik ve arazi', [
                _choices(
                  [const Code('', 'Yok'), ...NineLine.cbrnCodes],
                  _nine.cbrn,
                  (v) => _nine.cbrn = v,
                ),
                _field(_terrain, 'Arazi / engeller'),
              ]),
            ] else ...[
              _field(_size, 'S) Sayı / büyüklük'),
              _field(_activity, 'A) Faaliyet', lines: 2),
              _field(_unit, 'U) Birlik / kıyafet'),
              _field(_equipment, 'E) Teçhizat', lines: 2),
            ],
            _field(_remarks, 'Not', lines: 2),
            _section('Rapor', [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: text,
                      subject: _isNine ? 'CASEVAC' : 'SPOTREP',
                    ),
                  ),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Paylaş'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rapor kopyalandı.')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopyala'),
                ),
                OutlinedButton.icon(
                  onPressed: _addToMap,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Haritaya ekle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
