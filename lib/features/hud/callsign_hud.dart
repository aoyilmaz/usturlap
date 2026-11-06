import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bearing_format.dart';
import '../../core/coord_format.dart';
import '../../core/wmm.dart';
import '../../domain/models/contact.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';

/// Ekranın üstünde kalıcı taktik bilgi şeridi (HUD).
///
/// Gösterir: callsign, koordinat (seçili biçim), kerteriz, hız, yükseklik.
/// - HUD'a **dokun** → genişlet/daralt (diğer biçimler + GPS doğruluğu).
/// - HUD'a **çift dokun** → koordinat biçimi (MGRS/UTM/WGS84).
/// - **Callsign'a dokun** → düzenle (kalıcı).
/// - Gece modunda kırmızı tonlama.
class CallsignHud extends ConsumerStatefulWidget {
  const CallsignHud({super.key});

  @override
  ConsumerState<CallsignHud> createState() => _CallsignHudState();
}

class _CallsignHudState extends ConsumerState<CallsignHud> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contactsProvider);
    final self = ref.watch(selfContactProvider);
    final format = ref.watch(coordFormatProvider);
    final callsign = ref.watch(callsignProvider);
    final night = ref.watch(nightModeProvider);
    final fmt = ref.watch(bearingFormatterProvider);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onDoubleTap: () => ref.read(coordFormatProvider.notifier).cycle(),
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: night
                    ? Colors.red.withValues(alpha: 0.55)
                    : Colors.white24),
          ),
          child: async.when(
            data: (_) => self == null
                ? _statusLine('Konum bekleniyor…', night: night)
                : _HudContent(
                    contact: self,
                    callsign: callsign,
                    format: format,
                    fmt: fmt,
                    night: night,
                    expanded: _expanded,
                    onTapCallsign: () => _editCallsign(context, ref, callsign),
                  ),
            loading: () => _statusLine('Konum bekleniyor…', night: night),
            error: (e, _) => _statusLine(
              e is StateError ? e.message : 'Konum alınamadı',
              warn: true,
              night: night,
            ),
          ),
        ),
      ),
    );
  }

  void _editCallsign(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Callsign'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Callsign'),
          onSubmitted: (_) {
            ref.read(callsignProvider.notifier).set(ctrl.text);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(callsignProvider.notifier).set(ctrl.text);
              Navigator.of(context).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(String text, {bool warn = false, bool night = false}) {
    return Row(
      children: [
        Icon(warn ? Icons.gps_off : Icons.gps_not_fixed,
            size: 20,
            color: warn
                ? Colors.orangeAccent
                : (night ? Colors.redAccent : Colors.white70)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      ],
    );
  }
}

class _HudContent extends StatelessWidget {
  const _HudContent({
    required this.contact,
    required this.callsign,
    required this.format,
    required this.fmt,
    required this.night,
    required this.expanded,
    required this.onTapCallsign,
  });

  final Contact contact;
  final String callsign;
  final CoordFormatType format;
  final BearingFormatter fmt;
  final bool night;
  final bool expanded;
  final VoidCallback onTapCallsign;

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.lightGreenAccent;
    return Column(
      // İçeriği kadar yer kapla; aksi halde (max) tüm ekranı kaplayıp
      // yarı saydam arka planıyla haritayı karartır ve dokunuşları yutar.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Callsign (dokun → düzenle) + biçim etiketi
        Row(
          children: [
            Icon(Icons.gps_fixed, size: 20, color: accent),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTapCallsign,
              child: Row(
                children: [
                  Text(
                    callsign,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 13, color: Colors.white38),
                ],
              ),
            ),
            const Spacer(),
            _formatTag(format.label),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          CoordFormat.format(contact.position, format),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat(
                'KRT',
                contact.headingDeg == null
                    ? '—'
                    : fmt.format(contact.headingDeg!, contact.position)),
            _stat('HIZ', _speed(contact.speedMps)),
            _stat('İRT', _altitude(contact.altitudeMsl)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white38, size: 20),
          ],
        ),
        if (expanded) ...[
          const Divider(color: Colors.white24, height: 14),
          for (final f in CoordFormatType.values)
            if (f != format)
              _line(f.label, CoordFormat.format(contact.position, f)),
          _line(
            'GPS',
            contact.accuracyMeters == null
                ? '—'
                : '±${contact.accuracyMeters!.round()} m',
          ),
          // Manyetik sapma (WMM2025) ve grid yakınsaması — bu noktada.
          _line('SAPMA', _eastWest(Wmm.declination(
              contact.position.latitude, contact.position.longitude))),
          _line('GRİD', '${_eastWest(NorthMath.gridConvergence(contact.position))} yakınsama'),
        ],
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ),
          ],
        ),
      );

  Widget _formatTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
      ],
    );
  }

  /// 5.93 → "5.9° D", −1.2 → "1.2° B" (doğu/batı).
  static String _eastWest(double deg) =>
      '${deg.abs().toStringAsFixed(1)}° ${deg >= 0 ? 'D' : 'B'}';

  static String _speed(double? mps) =>
      mps == null ? '—' : '${(mps * 3.6).toStringAsFixed(1)} km/h';

  static String _altitude(double? m) => m == null ? '—' : '${m.round()} m';
}
