import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/track_filter.dart';
import '../data/db/track_repository.dart';
import '../domain/models/contact.dart';
import '../domain/models/track.dart';
import 'location_providers.dart';
import 'field_providers.dart';
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

  /// Otomatik durma anı (ayarlarda süre seçiliyse).
  final DateTime? stopAt;

  /// Son kayıt süre dolduğu için mi durdu.
  final bool autoStopped;

  const RecordingState({
    this.isRecording = false,
    this.trackId,
    this.stopAt,
    this.autoStopped = false,
  });
}

/// Aktif iz kaydı. Kayıttayken konum akışını dinler ve noktaları drift'e ekler
/// (durağanken şişmesin diye küçük mesafe filtresiyle).
class RecordingNotifier extends Notifier<RecordingState> {
  static const _distance = Distance();
  static const double _minMeters = 4.0; // bu kadar hareket olmadan nokta ekleme

  LatLng? _lastPoint;
  Timer? _autoStop;

  /// Başlatma sürerken (veritabanı beklenirken) ikinci dokunuş yeni iz açmasın.
  bool _starting = false;

  /// Açılışta bir kez: önceki oturumdan yarım kalan izleri kapat.
  Future<void>? _recovered;

  @override
  RecordingState build() {
    ref.onDispose(() => _autoStop?.cancel());
    _recovered ??= ref
        .read(trackRepositoryProvider)
        .closeUnfinished()
        .then<void>((_) {}, onError: (Object _) {});
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
    // Arka planda zamanlayıcı gecikebilir: konum gelince de denetle.
    if (checkAutoStop(DateTime.now())) return;
    // Doğruluk filtresi: gürültülü (düşük doğruluk) noktaları ele.
    if (!TrackFilter.accuracyOk(
        c.accuracyMeters, ref.read(accuracyFilterProvider))) {
      return;
    }
    if (_lastPoint != null && _distance(_lastPoint!, c.position) < _minMeters) {
      return;
    }
    _lastPoint = c.position;
    final id = s.trackId!;
    ref
        .read(trackRepositoryProvider)
        .addPoint(
          id,
          c.position,
          timestamp: c.timestamp,
          altitude: c.altitudeMsl,
          speed: c.speedMps,
        )
        .catchError((Object e) {
          // İz artık yok (silindi / geri yükleme değiştirdi): "kaydediliyor"
          // görünüp nokta kaybetmek yerine kaydı durdur.
          if (ref.mounted && state.trackId == id) stop();
        });
  }

  Future<void> start() async {
    if (state.isRecording || _starting) return;
    _starting = true;
    try {
      await _start();
    } finally {
      _starting = false;
    }
  }

  Future<void> _start() async {
    await _recovered;
    // Sayıyı doğrudan veritabanından al. `tracksProvider` kimse dinlemezken
    // yüklenmez (Riverpod 3 dinlenmeyen sağlayıcıyı duraklatır) → eskiden
    // her iz "İZ-1" oluyordu.
    final repo = ref.read(trackRepositoryProvider);
    final n = await repo.trackCount() + 1;
    // Ayar yüklenmeden okunursa varsayılan (kapalı) gelir: açılıştan sonraki
    // ilk kayıtta otomatik durma kurulmuyordu.
    final minutes = await ref.read(trackAutoStopProvider.notifier).loaded();
    final id = await repo.startTrack('${ref.read(callsignProvider)} İZ-$n');
    _lastPoint = null;
    final stopAt = minutes > 0
        ? DateTime.now().add(Duration(minutes: minutes))
        : null;
    _autoStop?.cancel();
    if (stopAt != null) {
      _autoStop = Timer(
        Duration(minutes: minutes),
        () => checkAutoStop(DateTime.now()),
      );
    }
    // Ekran kapalıyken de iz sürsün: arka plan konumunu harita ekranı
    // açar (backgroundLocationNeededProvider; geofence de kullanır).
    state = RecordingState(isRecording: true, trackId: id, stopAt: stopAt);
    // İlk noktayı hemen ekle (varsa).
    _onPosition(ref.read(gpsSelfContactProvider));
  }

  /// Süre dolduysa kaydı durdurur (true döner).
  bool checkAutoStop(DateTime now) {
    final at = state.stopAt;
    if (!state.isRecording || at == null || now.isBefore(at)) return false;
    stop(auto: true);
    return true;
  }

  /// [auto]: süre dolduğu için (harita ekranı uyarır).
  Future<void> stop({bool auto = false}) async {
    final id = state.trackId;
    _autoStop?.cancel();
    _autoStop = null;
    state = RecordingState(autoStopped: auto);
    _lastPoint = null;
    // Arka plan konumu: backgroundLocationNeededProvider (geofence yoksa
    // kapanır, batarya tasarrufu).
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
