import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bearing_format.dart';
import '../../core/coord_format.dart';
import '../../core/wmm.dart';
import '../../domain/models/contact.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';

/// Kendi konum kutusu — ATAK "Self Marker Widget" (kılavuz s.5), sağ altta.
///
/// Callsign · koordinat (seçili biçim) · rakım (MSL) + yön · hız + GPS ±m.
/// - **Dokun** → genişlet/daralt (diğer biçimler, manyetik sapma, grid).
/// - **Çift dokun** → koordinat biçimi (MGRS → UTM → WGS84 → DM → DMS).
/// - **Callsign'a dokun** → düzenle (kalıcı).
/// - Gece modunda kırmızı tonlama.
class SelfInfoBox extends ConsumerStatefulWidget {
  const SelfInfoBox({super.key});

  /// Kutunun genişliği (MGRS'in tek satıra sığacağı kadar).
  static const double width = 214;

  @override
  ConsumerState<SelfInfoBox> createState() => _SelfInfoBoxState();
}

class _SelfInfoBoxState extends ConsumerState<SelfInfoBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contactsProvider);
    final self = ref.watch(selfContactProvider);
    final format = ref.watch(coordFormatProvider);
    final callsign = ref.watch(callsignProvider);
    final night = ref.watch(nightModeProvider);
    final fmt = ref.watch(bearingFormatterProvider);
    // Elle verilen konum GPS beklemeden gösterilir.
    final manual = ref.watch(manualPositionProvider) != null;
    Widget content(Contact c) => _Content(
      contact: c,
      callsign: callsign,
      format: format,
      fmt: fmt,
      night: night,
      expanded: _expanded,
      manual: manual,
      onTapCallsign: () => _editCallsign(context, callsign),
    );

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onDoubleTap: () => ref.read(coordFormatProvider.notifier).cycle(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: SelfInfoBox.width,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: night ? Colors.red.withValues(alpha: 0.55) : Colors.white24,
          ),
        ),
        child: manual && self != null
            ? content(self)
            : async.when(
                data: (_) => self == null
                    ? _status('Konum bekleniyor…', night: night)
                    : content(self),
                loading: () => _status('Konum bekleniyor…', night: night),
                error: (e, _) => _status(
                  e is StateError ? e.message : 'Konum alınamadı',
                  warn: true,
                  night: night,
                ),
              ),
      ),
    );
  }

  void _editCallsign(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    void save(BuildContext c) {
      ref.read(callsignProvider.notifier).set(ctrl.text);
      Navigator.of(c).pop();
    }

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Callsign'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Callsign'),
          onSubmitted: (_) => save(c),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(onPressed: () => save(c), child: const Text('Kaydet')),
        ],
      ),
    );
  }

  Widget _status(String text, {bool warn = false, bool night = false}) {
    return Row(
      children: [
        Icon(
          warn ? Icons.gps_off : Icons.gps_not_fixed,
          size: 18,
          color: warn
              ? Colors.orangeAccent
              : (night ? Colors.redAccent : Colors.white70),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.contact,
    required this.callsign,
    required this.format,
    required this.fmt,
    required this.night,
    required this.expanded,
    required this.onTapCallsign,
    this.manual = false,
  });

  final Contact contact;

  /// Elle verilen konum: doğruluk yerine "MANUEL".
  final bool manual;
  final String callsign;
  final CoordFormatType format;
  final BearingFormatter fmt;
  final bool night;
  final bool expanded;
  final VoidCallback onTapCallsign;

  static const _value = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.lightGreenAccent;
    final heading = contact.headingDeg == null
        ? '—'
        : fmt.format(contact.headingDeg!, contact.position);
    return Column(
      // İçeriği kadar yer kapla (aksi halde dokunuşları yutar).
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.navigation, size: 14, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: onTapCallsign,
                child: Text(
                  callsign,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            _tag(format.label),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CoordFormat.format(contact.position, format),
            style: _value.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(height: 2),
        _pair(_altitude(contact.altitudeMsl), heading),
        _pair(
          _speed(contact.speedMps),
          manual ? 'MANUEL' : _accuracy(contact.accuracyMeters),
        ),
        if (expanded) ...[
          const Divider(color: Colors.white24, height: 12),
          for (final f in CoordFormatType.values)
            if (f != format)
              _line(f.label, CoordFormat.format(contact.position, f)),
          // Manyetik sapma (WMM2025) ve grid yakınsaması — bu noktada.
          _line(
            'SAPMA',
            _eastWest(
              Wmm.declination(
                contact.position.latitude,
                contact.position.longitude,
              ),
            ),
          ),
          _line(
            'GRİD',
            '${_eastWest(NorthMath.gridConvergence(contact.position))} yak.',
          ),
        ],
      ],
    );
  }

  Widget _pair(String left, String right) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Row(
      children: [
        Expanded(child: Text(left, style: _value)),
        Text(right, style: _value),
      ],
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// 5.93 → "5.9° D", −1.2 → "1.2° B" (doğu/batı).
  static String _eastWest(double deg) =>
      '${deg.abs().toStringAsFixed(1)}° ${deg >= 0 ? 'D' : 'B'}';

  static String _speed(double? mps) =>
      mps == null ? '— km/h' : '${(mps * 3.6).toStringAsFixed(1)} km/h';

  static String _altitude(double? m) =>
      m == null ? '— MSL' : '${m.round()} m MSL';

  static String _accuracy(double? m) => m == null ? '±—' : '±${m.round()} m';
}
