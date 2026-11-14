import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/track.dart';
import 'package:usturlap/domain/usecases/track_search.dart';

/// G6: iz arama.
void main() {
  final now = DateTime(2026, 11, 10, 15);
  Track t(String name, DateTime at) =>
      Track(uid: name, name: name, startedAt: at, endedAt: at);
  final tracks = [
    t('Sabah devriyesi', DateTime(2026, 11, 10, 6)),
    t('İLERİ KEŞİF', DateTime(2026, 11, 7, 9)),
    t('Eski yürüyüş', DateTime(2026, 9, 1, 8)),
  ];

  test('ad: Türkçe büyük/küçük harf duyarsız', () {
    expect(searchTracks(tracks, query: 'ileri', now: now).map((t) => t.name), [
      'İLERİ KEŞİF',
    ]);
    expect(searchTracks(tracks, query: 'DEVRİYE', now: now), hasLength(1));
  });

  test('tarih parçası eşleşir; en yeni üstte', () {
    expect(
      searchTracks(tracks, query: '07.11', now: now).single.name,
      'İLERİ KEŞİF',
    );
    expect(searchTracks(tracks, now: now).map((t) => t.name), [
      'Sabah devriyesi',
      'İLERİ KEŞİF',
      'Eski yürüyüş',
    ]);
  });

  test('zaman süzgeci', () {
    expect(
      searchTracks(tracks, period: TrackPeriod.today, now: now),
      hasLength(1),
    );
    expect(
      searchTracks(tracks, period: TrackPeriod.week, now: now),
      hasLength(2),
    );
    expect(
      searchTracks(tracks, period: TrackPeriod.month, now: now),
      hasLength(2),
    );
    expect(searchTracks(tracks, now: now), hasLength(3));
    expect(trackDate(DateTime(2026, 1, 5)), '05.01.2026');
  });
}
