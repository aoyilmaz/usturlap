import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/weather/open_meteo.dart';
import 'settings_providers.dart';

/// Hava durumu ağ isteği (testte değiştirilir).
final weatherFetcherProvider = Provider<Future<String> Function(LatLng)>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return (p) => OpenMeteo.fetchRaw(client, p);
});

class WeatherState {
  const WeatherState({this.report, this.loading = false, this.error});

  final WeatherReport? report;
  final bool loading;
  final String? error;
}

/// Son hava durumu (önbellekli: internet yokken son kayıt görünür).
class WeatherNotifier extends Notifier<WeatherState> {
  static const _rawKey = 'weather_raw';
  static const _atKey = 'weather_at';

  @override
  WeatherState build() {
    _load();
    return const WeatherState();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final raw = await repo.get(_rawKey);
    final at = DateTime.tryParse(await repo.get(_atKey) ?? '');
    if (raw == null || at == null || !ref.mounted) return;
    try {
      state = WeatherState(report: OpenMeteo.parse(raw, at));
    } on FormatException {
      // Bozuk önbellek yok sayılır.
    }
  }

  Future<void> refresh(LatLng p) async {
    state = WeatherState(report: state.report, loading: true);
    try {
      final raw = await ref.read(weatherFetcherProvider)(p);
      final now = DateTime.now();
      final report = OpenMeteo.parse(raw, now);
      if (!ref.mounted) return;
      state = WeatherState(report: report);
      final repo = ref.read(settingsRepositoryProvider);
      await repo.set(_rawKey, raw);
      await repo.set(_atKey, now.toIso8601String());
    } catch (e) {
      if (!ref.mounted) return;
      state = WeatherState(
        report: state.report,
        error: e is FormatException
            ? e.message
            : 'İnternete ulaşılamadı; son kayıt gösteriliyor.',
      );
    }
  }
}

final weatherProvider = NotifierProvider<WeatherNotifier, WeatherState>(
  WeatherNotifier.new,
);
