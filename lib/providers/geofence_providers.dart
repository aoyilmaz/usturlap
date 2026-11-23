import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/contact.dart';
import '../domain/models/map_graphic.dart';
import '../domain/usecases/geofence_monitor.dart';
import 'graphic_providers.dart';
import 'location_providers.dart';

/// Geofence durumu: son konumdaki yeni uyarılar ([latest]; harita ekranı
/// titreşim + ekran uyarısı verir), geçmiş (en çok [maxHistory], en yeni
/// sonda) ve şekillerin içinde / dışında durumu.
class GeofenceState {
  const GeofenceState({
    this.latest = const [],
    this.history = const [],
    this.inside = const {},
  });

  final List<GeofenceEvent> latest;
  final List<GeofenceEvent> history;
  final Map<String, bool> inside;

  static const maxHistory = 30;
}

/// Konum ve çizimler değiştikçe geofence'leri denetler. Uygulama arka
/// plandayken (iz kaydı sürerken) gelen konumlar da işlenir; o anki uyarı
/// görünmez ama geçmişe yazılır.
class GeofenceNotifier extends Notifier<GeofenceState> {
  final _monitor = GeofenceMonitor();

  /// Bundan kötü doğruluklu konumlar yok sayılır (sınırda GPS titremesi
  /// boşuna uyarı üretmesin).
  static const maxAccuracyMeters = 50.0;

  @override
  GeofenceState build() {
    ref.listen<Contact?>(selfContactProvider, (_, c) => _check(c));
    ref.listen<AsyncValue<List<MapGraphic>>>(
      mapGraphicsProvider,
      (_, _) => _check(ref.read(selfContactProvider)),
    );
    return const GeofenceState();
  }

  void _check(Contact? c) {
    if (c == null) return;
    final acc = c.accuracyMeters;
    if (acc != null && acc > maxAccuracyMeters) return;
    final graphics = ref.read(mapGraphicsProvider).value;
    if (graphics == null) return;
    final events = _monitor.update(
      c.position,
      graphics,
      c.timestamp,
      accuracy: acc,
    );
    final history = [...state.history, ...events];
    state = GeofenceState(
      latest: events,
      history: history.length > GeofenceState.maxHistory
          ? history.sublist(history.length - GeofenceState.maxHistory)
          : history,
      inside: _monitor.snapshot,
    );
  }

  void clearHistory() => state = GeofenceState(inside: state.inside);
}

final geofenceProvider = NotifierProvider<GeofenceNotifier, GeofenceState>(
  GeofenceNotifier.new,
);
