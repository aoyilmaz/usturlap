import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/track_filter.dart';
import '../data/db/track_repository.dart';
import '../domain/models/contact.dart';
import '../domain/models/track.dart';
import 'location_providers.dart';
import 'settings_providers.dart';
import 'waypoint_providers.dart';

final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  return TrackRepository(ref.watch(appDatabaseProvider));
});

/// Tüm kayıtlı izler (canlı, nokta sayılı).
final tracksProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(trackRepositoryProvider).watchTracks();
});

/// Kayıt durumu.
class RecordingState {
  final bool isRecording;
  final int? trackId;
  const RecordingState({this.isRecording = false, this.trackId});
}

/// Aktif iz kaydı. Kayıttayken konum akışını dinler ve noktaları drift'e ekler
/// (durağanken şişmesin diye küçük mesafe filtresiyle).
class RecordingNotifier extends Notifier<RecordingState> {
  static const _distance = Distance();
  static const double _minMeters = 4.0; // bu kadar hareket olmadan nokta ekleme

  LatLng? _lastPoint;

  @override
  RecordingState build() {
    // Konum geldikçe, kayıttaysak noktayı ekle.
    // Ham GPS: elle verilen konum ize girmez.
    ref.listen<Contact?>(gpsSelfContactProvider, (prev, next) {
      _onPosition(next);
    });
    return const RecordingState();
  }

  void _onPosition(Contact? c) {
    final s = state;
    if (!s.isRecording || s.trackId == null || c == null) return;
    // Doğruluk filtresi: gürültülü (düşük doğruluk) noktaları ele.
    if (!TrackFilter.accuracyOk(
        c.accuracyMeters, ref.read(accuracyFilterProvider))) {
      return;
    }
    if (_lastPoint != null && _distance(_lastPoint!, c.position) < _minMeters) {
      return;
    }
    _lastPoint = c.position;
    ref.read(trackRepositoryProvider).addPoint(
          s.trackId!,
          c.position,
          timestamp: c.timestamp,
          altitude: c.altitudeMsl,
          speed: c.speedMps,
        );
  }

  Future<void> start() async {
    if (state.isRecording) return;
    // Sayıyı doğrudan veritabanından al. `tracksProvider` kimse dinlemezken
    // yüklenmez (Riverpod 3 dinlenmeyen sağlayıcıyı duraklatır) → eskiden
    // her iz "İZ-1" oluyordu.
    final repo = ref.read(trackRepositoryProvider);
    final n = await repo.trackCount() + 1;
    final id = await repo.startTrack('${ref.read(callsignProvider)} İZ-$n');
    _lastPoint = null;
    state = RecordingState(isRecording: true, trackId: id);
    // Ekran kapalıyken de iz sürsün diye arka plan konumunu aç.
    await ref.read(positionSourceProvider).setBackgroundEnabled(true);
    // İlk noktayı hemen ekle (varsa).
    _onPosition(ref.read(gpsSelfContactProvider));
  }

  Future<void> stop() async {
    final id = state.trackId;
    state = const RecordingState();
    _lastPoint = null;
    // Arka plan konumunu kapat (batarya tasarrufu).
    await ref.read(positionSourceProvider).setBackgroundEnabled(false);
    if (id != null) await ref.read(trackRepositoryProvider).endTrack(id);
  }
}

final recordingProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(RecordingNotifier.new);

/// Kayıttaki izin canlı noktaları (harita polyline'ı için).
final currentTrackPointsProvider = StreamProvider<List<TrackPoint>>((ref) {
  final rec = ref.watch(recordingProvider);
  if (!rec.isRecording || rec.trackId == null) {
    return Stream.value(const <TrackPoint>[]);
  }
  return ref.watch(trackRepositoryProvider).watchPoints(rec.trackId!);
});

/// Haritada görüntülenmek üzere seçili kayıtlı iz (liste → haritada göster).
class DisplayedTrackNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void show(int? id) => state = id;
}

final displayedTrackIdProvider =
    NotifierProvider<DisplayedTrackNotifier, int?>(DisplayedTrackNotifier.new);

final displayedTrackPointsProvider = StreamProvider<List<TrackPoint>>((ref) {
  final id = ref.watch(displayedTrackIdProvider);
  if (id == null) return Stream.value(const <TrackPoint>[]);
  return ref.watch(trackRepositoryProvider).watchPoints(id);
});
