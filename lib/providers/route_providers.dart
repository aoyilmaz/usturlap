import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/db/route_repository.dart';
import '../domain/models/contact.dart';
import '../domain/models/route_plan.dart';
import '../domain/usecases/route_navigator.dart';
import 'location_providers.dart';
import 'nav_providers.dart';
import 'waypoint_providers.dart';

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => RouteRepository(ref.watch(appDatabaseProvider)),
);

/// Kayıtlı rotalar (en yeni üstte).
final routesProvider = StreamProvider<List<RoutePlan>>(
  (ref) => ref.watch(routeRepositoryProvider).watchAll(),
);

// ---------------------------------------------------------------- planlama

/// Rota planlama modu: açıkken haritaya dokunma / "+" rotaya nokta ekler,
/// alt çubuk planlama düğmelerine dönüşür.
class RoutePlanningState {
  const RoutePlanningState({this.active = false, this.points = const []});
  final bool active;
  final List<LatLng> points;

  double get length => routeLength(points);
}

class RoutePlanningNotifier extends Notifier<RoutePlanningState> {
  @override
  RoutePlanningState build() => const RoutePlanningState();

  void start() => state = const RoutePlanningState(active: true);
  void addPoint(LatLng p) =>
      state = RoutePlanningState(active: true, points: [...state.points, p]);
  void undo() {
    if (state.points.isEmpty) return;
    state = RoutePlanningState(
      active: true,
      points: state.points.sublist(0, state.points.length - 1),
    );
  }

  void clear() => state = const RoutePlanningState(active: true);
  void cancel() => state = const RoutePlanningState();

  /// Kaydet ve planlamayı kapat. En az 2 nokta gerekir; kaydedilen rota döner.
  Future<RoutePlan?> save(String name) async {
    if (state.points.length < 2 || _saving) return null;
    _saving = true; // çift dokunuş iki rota kaydetmesin
    try {
      final route = await ref
          .read(routeRepositoryProvider)
          .add(name: name, points: state.points);
      state = const RoutePlanningState();
      return route;
    } finally {
      _saving = false;
    }
  }

  bool _saving = false;
}

final routePlanningProvider =
    NotifierProvider<RoutePlanningNotifier, RoutePlanningState>(
      RoutePlanningNotifier.new,
    );

// ------------------------------------------------------------- takip etme

/// Takip edilen rota + anlık ilerleme.
class ActiveRouteState {
  const ActiveRouteState({required this.route, this.progress});
  final RoutePlan route;
  final RouteProgress? progress; // konum gelene kadar null
}

class ActiveRouteNotifier extends Notifier<ActiveRouteState?> {
  RouteNavigator? _nav;

  /// Bundan kötü doğruluklu konumlar rota ilerlemesine katılmaz.
  static const maxAccuracyMeters = 50.0;

  @override
  ActiveRouteState? build() {
    // Konum geldikçe ilerlemeyi güncelle. Kötü doğruluklu konum (ör. vadi
    // dibinde ±200 m) yok sayılır: ilerlemeyi atlatır, boşuna "saptınız"
    // der (geofence'teki sınırla aynı).
    ref.listen<Contact?>(selfContactProvider, (_, self) {
      if (self == null) return;
      final acc = self.accuracyMeters;
      if (acc != null && acc > maxAccuracyMeters) return;
      _update(self.position);
    });
    return null;
  }

  void start(RoutePlan route) {
    if (route.points.length < 2) return;
    // Tek hedefli "Git" ile çakışmasın.
    ref.read(navTargetProvider.notifier).clear();
    _nav = RouteNavigator(route.points);
    state = ActiveRouteState(route: route);
    final self = ref.read(selfContactProvider);
    if (self != null) _update(self.position);
  }

  void stop() {
    _nav = null;
    state = null;
  }

  void skip() => _manual((n) => n.skip());
  void back() => _manual((n) => n.back());

  void _manual(void Function(RouteNavigator n) f) {
    final n = _nav;
    if (n == null) return;
    f(n);
    final self = ref.read(selfContactProvider);
    if (self != null) _update(self.position);
  }

  void _update(LatLng pos) {
    final nav = _nav;
    final s = state;
    if (nav == null || s == null) return;
    state = ActiveRouteState(route: s.route, progress: nav.update(pos));
  }
}

final activeRouteProvider =
    NotifierProvider<ActiveRouteNotifier, ActiveRouteState?>(
      ActiveRouteNotifier.new,
    );
