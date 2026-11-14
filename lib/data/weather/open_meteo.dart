import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Şu anki hava.
class WeatherNow {
  const WeatherNow({
    required this.time,
    required this.code,
    required this.temperature,
    required this.apparent,
    required this.humidity,
    required this.precipitation,
    required this.cloudCover,
    required this.pressure,
    required this.windSpeed,
    required this.windGusts,
    required this.windFrom,
    required this.visibility,
  });

  final DateTime time;
  final int code;
  final double temperature, apparent, precipitation, pressure;
  final int humidity, cloudCover;

  /// km/sa.
  final double windSpeed, windGusts;

  /// Rüzgârın estiği yön (°, coğrafi).
  final double windFrom;

  /// Görüş (m).
  final double visibility;
}

/// Saatlik tahmin.
class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.code,
    required this.temperature,
    required this.precipitationChance,
    required this.precipitation,
    required this.windSpeed,
    required this.windFrom,
    required this.visibility,
  });

  final DateTime time;
  final int code;
  final double temperature, precipitation, windSpeed, windFrom, visibility;
  final int precipitationChance;
}

class WeatherReport {
  const WeatherReport({
    required this.position,
    required this.fetchedAt,
    required this.elevation,
    required this.now,
    required this.hours,
  });

  /// Sorgulanan (yuvarlanmış) konum.
  final LatLng position;
  final DateTime fetchedAt;
  final double? elevation;
  final WeatherNow now;
  final List<WeatherHour> hours;
}

/// Open-Meteo (anahtarsız, ücretsiz) hava tahmini — METOC (yol haritası
/// karar 2). İnternet ister; yalnız kullanıcı isteyince sorulur. Gizlilik:
/// konum 0,1°'ye (~11 km) yuvarlanır, başka veri gönderilmez.
class OpenMeteo {
  OpenMeteo._();

  static double _round(double v) => (v * 10).roundToDouble() / 10;

  static LatLng rounded(LatLng p) =>
      LatLng(_round(p.latitude), _round(p.longitude));

  static Uri uri(LatLng p) {
    final r = rounded(p);
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${r.latitude}',
      'longitude': '${r.longitude}',
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'precipitation,weather_code,cloud_cover,pressure_msl,'
          'wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility',
      'hourly':
          'temperature_2m,precipitation_probability,precipitation,'
          'weather_code,wind_speed_10m,wind_direction_10m,visibility',
      'forecast_hours': '24',
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
    });
  }

  static Future<String> fetchRaw(http.Client client, LatLng p) async {
    final res = await client.get(uri(p)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw FormatException('Hava durumu alınamadı (HTTP ${res.statusCode}).');
    }
    return utf8.decode(res.bodyBytes);
  }

  /// Yanıtı okur. Saatler yanıttaki yerel saat + `utc_offset_seconds`.
  static WeatherReport parse(String body, DateTime fetchedAt) {
    final Object? j;
    try {
      j = jsonDecode(body);
    } on FormatException {
      throw const FormatException('Hava durumu yanıtı bozuk.');
    }
    if (j is! Map<String, dynamic>) {
      throw const FormatException('Hava durumu yanıtı bozuk.');
    }
    final offset = Duration(
      seconds: (j['utc_offset_seconds'] as num?)?.toInt() ?? 0,
    );
    DateTime time(Object? s) {
      final t = DateTime.tryParse('${s ?? ''}Z');
      if (t == null) throw const FormatException('Hava durumu saati bozuk.');
      return t.subtract(offset);
    }

    double d(Object? v) => v is num ? v.toDouble() : 0;
    int i(Object? v) => v is num ? v.round() : 0;
    final c = j['current'];
    if (c is! Map<String, dynamic>) {
      throw const FormatException('Hava durumu yanıtında şu anki değer yok.');
    }
    final now = WeatherNow(
      time: time(c['time']),
      code: i(c['weather_code']),
      temperature: d(c['temperature_2m']),
      apparent: d(c['apparent_temperature']),
      humidity: i(c['relative_humidity_2m']),
      precipitation: d(c['precipitation']),
      cloudCover: i(c['cloud_cover']),
      pressure: d(c['pressure_msl']),
      windSpeed: d(c['wind_speed_10m']),
      windGusts: d(c['wind_gusts_10m']),
      windFrom: d(c['wind_direction_10m']),
      visibility: d(c['visibility']),
    );
    final h = j['hourly'];
    final hours = <WeatherHour>[];
    if (h is Map<String, dynamic> && h['time'] is List) {
      final times = h['time'] as List;
      Object? at(String k, int n) {
        final l = h[k];
        return l is List && n < l.length ? l[n] : null;
      }

      for (var n = 0; n < times.length; n++) {
        hours.add(
          WeatherHour(
            time: time(times[n]),
            code: i(at('weather_code', n)),
            temperature: d(at('temperature_2m', n)),
            precipitationChance: i(at('precipitation_probability', n)),
            precipitation: d(at('precipitation', n)),
            windSpeed: d(at('wind_speed_10m', n)),
            windFrom: d(at('wind_direction_10m', n)),
            visibility: d(at('visibility', n)),
          ),
        );
      }
    }
    return WeatherReport(
      position: LatLng(d(j['latitude']), d(j['longitude'])),
      fetchedAt: fetchedAt,
      elevation: (j['elevation'] as num?)?.toDouble(),
      now: now,
      hours: hours,
    );
  }

  /// WMO hava kodu → Türkçe.
  static String describe(int code) => switch (code) {
    0 => 'Açık',
    1 => 'Çoğunlukla açık',
    2 => 'Parçalı bulutlu',
    3 => 'Kapalı',
    45 => 'Sis',
    48 => 'Kırağılı sis',
    51 => 'Hafif çisenti',
    53 => 'Çisenti',
    55 => 'Yoğun çisenti',
    56 || 57 => 'Donan çisenti',
    61 => 'Hafif yağmur',
    63 => 'Yağmur',
    65 => 'Şiddetli yağmur',
    66 || 67 => 'Donan yağmur',
    71 => 'Hafif kar',
    73 => 'Kar',
    75 => 'Yoğun kar',
    77 => 'Kar taneleri',
    80 => 'Hafif sağanak',
    81 => 'Sağanak',
    82 => 'Şiddetli sağanak',
    85 || 86 => 'Kar sağanağı',
    95 => 'Gök gürültülü fırtına',
    96 || 99 => 'Dolulu fırtına',
    _ => 'Bilinmiyor ($code)',
  };

  /// Rüzgârın estiği yön, Türkçe 8 yön (K, KD, D, GD, G, GB, B, KB).
  static String compass(double deg) {
    const names = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    return names[((deg % 360) / 45).round() % 8];
  }
}
