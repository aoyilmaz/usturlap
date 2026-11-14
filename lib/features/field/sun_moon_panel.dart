import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/usecases/sun_moon.dart';
import '../../providers/location_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Güneş ve ay paneli (saha konforu; internetsiz hesap): bugün ve yarın
/// için BMNT / EENT, sivil alacakaranlık, gün doğumu / batımı, ay doğuşu /
/// batışı ve evresi; şu anki ışık durumu. Konumum yoksa harita ortası.
Future<void> showSunMoonPanel(
  BuildContext context, {
  required LatLng Function() fallback,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'sun_moon',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => SunMoonPanel(fallback: fallback),
  );
}

class SunMoonPanel extends ConsumerWidget {
  const SunMoonPanel({super.key, required this.fallback, this.now});

  final LatLng Function() fallback;

  /// Test için sabit zaman.
  final DateTime? now;

  static String hm(DateTime? t) {
    if (t == null) return '—';
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static String _duration(Duration? d) => d == null
      ? '—'
      : '${d.inHours} sa ${(d.inMinutes % 60).toString().padLeft(2, '0')} dk';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfContactProvider)?.position;
    final p = self ?? fallback();
    final t = now ?? DateTime.now();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final light = SunMoon.lightAt(t, p.latitude, p.longitude);
    final alt = SunMoon.sunAltitude(t, p.latitude, p.longitude);

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: muted),
      ),
    );
    Widget row(String label, String value, {String? hint}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (hint != null)
                    TextSpan(
                      text: '  $hint',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                ],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    List<Widget> day(String title, DateTime date) {
      final s = SunMoon.sunTimes(date, p.latitude, p.longitude);
      final m = SunMoon.moonInfo(
        DateTime(date.year, date.month, date.day),
        p.latitude,
        p.longitude,
      );
      return [
        caption(title),
        row('BMNT', hm(s.bmnt), hint: 'denizci alacakaranlığı başı'),
        row('BMCT', hm(s.bmct), hint: 'sivil alacakaranlık başı'),
        row('Gün doğumu', hm(s.sunrise)),
        row('Öğle', hm(s.noon)),
        row('Gün batımı', hm(s.sunset)),
        row('EECT', hm(s.eect), hint: 'sivil alacakaranlık sonu'),
        row('EENT', hm(s.eent), hint: 'denizci alacakaranlığı sonu'),
        row('Gün ışığı', _duration(s.daylight)),
        row('Ay doğuşu', hm(m.rise)),
        row('Ay batışı', hm(m.set)),
        row('Ay', '${m.phase.label} · %${(m.illumination * 100).round()}'),
      ];
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Güneş ve ay',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${self == null ? 'Harita ortası' : 'Konumum'} · cihazda hesaplanır '
          '(internet gerekmez) · yerel saat',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        caption('Şimdi'),
        row(light.label, 'güneş ${alt.toStringAsFixed(0)}°'),
        ...day('Bugün', t),
        ...day('Yarın', t.add(const Duration(days: 1))),
      ],
    );
  }
}
