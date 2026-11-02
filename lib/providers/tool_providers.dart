import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Aktif ölçüm/çizim aracı.
enum ToolMode {
  none,
  distance, // çoklu nokta — mesafe ölçümü
  polygon, // alan
  sector, // merkez + yarıçap + iki kerteriz
  lineOfSight, // Görüş hattı analizi
}

class ToolState {
  final ToolMode mode;
  final List<LatLng> points;
  final bool visible;

  const ToolState({
    this.mode = ToolMode.none,
    this.points = const [],
    this.visible = true,
  });

  bool get active => mode != ToolMode.none;

  ToolState copyWith({ToolMode? mode, List<LatLng>? points, bool? visible}) =>
      ToolState(
        mode: mode ?? this.mode,
        points: points ?? this.points,
        visible: visible ?? this.visible,
      );
}

class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() => const ToolState();

  /// Bir araç seç (noktaları sıfırlar, görünür yapar).
  void setMode(ToolMode mode) =>
      state = ToolState(mode: mode, points: const [], visible: true);

  /// Haritaya dokununca çağrılır. Sektör en fazla 3 nokta alır.
  void addPoint(LatLng p) {
    if (state.mode == ToolMode.none) return;
    if (state.mode == ToolMode.sector && state.points.length >= 3) return;
    state = state.copyWith(points: [...state.points, p]);
  }

  void undo() {
    if (state.points.isEmpty) return;
    state = state.copyWith(points: state.points.sublist(0, state.points.length - 1));
  }

  /// Noktaları temizle (araç modu kalır).
  void clearPoints() => state = state.copyWith(points: const []);

  /// Aracı tamamen kapat.
  void reset() => state = const ToolState();

  void toggleVisible() => state = state.copyWith(visible: !state.visible);
}

final toolProvider = NotifierProvider<ToolNotifier, ToolState>(ToolNotifier.new);
