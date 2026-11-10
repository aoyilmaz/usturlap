import '../../core/tr_text.dart';
import '../models/track.dart';

/// İz listesinde zaman süzgeci (ATAK Track Search, kılavuz s.46).
enum TrackPeriod {
  all('Tümü'),
  today('Bugün'),
  week('7 gün'),
  month('30 gün');

  const TrackPeriod(this.label);
  final String label;

  /// Bu süzgeçte gösterilecek en eski başlangıç; tümünde null.
  DateTime? since(DateTime now) => switch (this) {
    TrackPeriod.all => null,
    TrackPeriod.today => DateTime(now.year, now.month, now.day),
    TrackPeriod.week => now.subtract(const Duration(days: 7)),
    TrackPeriod.month => now.subtract(const Duration(days: 30)),
  };
}

/// İzin tarihi "12.11.2026" (aramada da eşleşir).
String trackDate(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}

/// Ada ya da tarihe göre arar (Türkçe küçük harf; "12.11" gibi tarih
/// parçası da olur), zaman süzgeci uygular; en yeni üstte.
List<Track> searchTracks(
  List<Track> tracks, {
  String query = '',
  TrackPeriod period = TrackPeriod.all,
  required DateTime now,
}) {
  final q = lowerTr(query.trim());
  final since = period.since(now);
  final out = [
    for (final t in tracks)
      if ((since == null || !t.startedAt.isBefore(since)) &&
          (q.isEmpty ||
              lowerTr(t.name).contains(q) ||
              trackDate(t.startedAt).contains(q)))
        t,
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return out;
}
