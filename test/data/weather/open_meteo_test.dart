import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/weather/open_meteo.dart';
import 'package:latlong2/latlong.dart';

/// Open-Meteo yanıtı (2026-11-11'de alınan gerçek yanıtın kısaltması).
const sample =
    '''{"latitude":39.904133,"longitude":32.85855,"utc_offset_seconds":10800,
"timezone":"Europe/Istanbul","elevation":899.0,
"current":{"time":"2026-11-11T23:45","interval":900,"temperature_2m":4.4,
"relative_humidity_2m":94,"apparent_temperature":2.3,"precipitation":0.0,
"weather_code":3,"cloud_cover":100,"pressure_msl":1022.9,"wind_speed_10m":3.5,
"wind_direction_10m":114,"wind_gusts_10m":6.8,"visibility":23800.0},
"hourly":{"time":["2026-11-11T23:00","2026-11-12T00:00"],
"temperature_2m":[4.5,4.3],"precipitation_probability":[0,10],
"precipitation":[0.0,0.1],"weather_code":[3,61],"wind_speed_10m":[3.9,3.5],
"wind_direction_10m":[124,114],"visibility":[24120.0,23700.0]}}''';

void main() {
  test('yanıt okunur; saatler UTC\'ye çevrilir', () {
    final at = DateTime.utc(2026, 11, 11, 21);
    final r = OpenMeteo.parse(sample, at);
    expect(r.fetchedAt, at);
    expect(r.elevation, 899);
    expect(r.now.time, DateTime.utc(2026, 11, 11, 20, 45));
    expect(r.now.code, 3);
    expect(r.now.temperature, 4.4);
    expect(r.now.humidity, 94);
    expect(r.now.windFrom, 114);
    expect(r.now.visibility, 23800);
    expect(r.hours, hasLength(2));
    expect(r.hours[1].time, DateTime.utc(2026, 11, 11, 21));
    expect(r.hours[1].precipitationChance, 10);
    expect(OpenMeteo.describe(r.hours[1].code), 'Hafif yağmur');
  });

  test('bozuk yanıt Türkçe hatayla reddedilir', () {
    expect(
      () => OpenMeteo.parse('{bozuk', DateTime.now()),
      throwsFormatException,
    );
    expect(() => OpenMeteo.parse('{}', DateTime.now()), throwsFormatException);
  });

  test('gizlilik: konum 0,1°ye yuvarlanır; yalnız gerekli alanlar', () {
    final u = OpenMeteo.uri(const LatLng(39.93347, 32.85971));
    expect(u.host, 'api.open-meteo.com');
    expect(u.queryParameters['latitude'], '39.9');
    expect(u.queryParameters['longitude'], '32.9');
    expect(u.queryParameters.keys, isNot(contains('callsign')));
  });

  test('rüzgâr yönü (estiği yer) ve hava kodları', () {
    expect(OpenMeteo.compass(0), 'K');
    expect(OpenMeteo.compass(114), 'GD');
    expect(OpenMeteo.compass(350), 'K');
    expect(OpenMeteo.compass(270), 'B');
    expect(OpenMeteo.describe(95), 'Gök gürültülü fırtına');
    expect(OpenMeteo.describe(1234), 'Bilinmiyor (1234)');
  });
}
