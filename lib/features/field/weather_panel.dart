import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/weather/open_meteo.dart';
import '../../providers/location_providers.dart';
import '../../providers/weather_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Hava durumu paneli (METOC; Open-Meteo, internet ister). Son kayıt
/// önbellekte: internetsiz alanda da en son tahmin görünür.
Future<void> showWeatherPanel(
  BuildContext context, {
  required LatLng Function() fallback,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'weather',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => WeatherPanel(fallback: fallback),
  );
}

class WeatherPanel extends ConsumerWidget {
  const WeatherPanel({super.key, required this.fallback});

  final LatLng Function() fallback;

  static String hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 48) return '${d.inHours} sa önce';
    return '${d.inDays} gün önce';
  }

  static String _vis(double m) => m >= 10000
      ? '${(m / 1000).round()} km'
      : m >= 1000
      ? '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
      : '${m.round()} m';

  static String _wind(double kmh, double from) =>
      '${OpenMeteo.compass(from)} (${from.round()}°) ${kmh.round()} km/sa';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherProvider);
    final self = ref.watch(selfContactProvider)?.position;
    final r = state.report;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hava durumu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              onPressed: state.loading
                  ? null
                  : () => ref
                        .read(weatherProvider.notifier)
                        .refresh(self ?? fallback()),
              icon: state.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Güncelle'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Open-Meteo · internet ister · ${self == null ? 'harita ortası' : 'konumum'} '
          '~11 km yuvarlanarak gönderilir',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (r == null)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Henüz hava durumu yok. İnternet varken Güncelle\'ye bas; '
              'son kayıt sonra internetsiz de görünür.',
            ),
          )
        else ...[
          const SizedBox(height: 10),
          Text(
            '${OpenMeteo.describe(r.now.code)} · '
            '${r.now.temperature.round()}°C',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'Güncelleme ${hm(r.fetchedAt)} (${_ago(r.fetchedAt)})',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 6),
          row('Hissedilen', '${r.now.apparent.round()}°C'),
          row('Rüzgâr', _wind(r.now.windSpeed, r.now.windFrom)),
          row('Hamle', '${r.now.windGusts.round()} km/sa'),
          row('Görüş', _vis(r.now.visibility)),
          row('Bulut', '%${r.now.cloudCover}'),
          row('Nem', '%${r.now.humidity}'),
          row('Basınç', '${r.now.pressure.round()} hPa'),
          if (r.now.precipitation > 0)
            row('Yağış', '${r.now.precipitation} mm'),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              'Önümüzdeki 24 saat',
              style: TextStyle(fontWeight: FontWeight.bold, color: muted),
            ),
          ),
          for (final h in r.hours)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(hm(h.time))),
                  Expanded(child: Text(OpenMeteo.describe(h.code))),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${h.temperature.round()}°',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '%${h.precipitationChance}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: muted),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      '${OpenMeteo.compass(h.windFrom)} ${h.windSpeed.round()}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
