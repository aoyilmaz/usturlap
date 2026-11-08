import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Aktif ölçüm/çizim aracı.
enum ToolMode {
  none,
  distance, // çoklu nokta — mesafe ölçümü
  polygon, // alan
  sector, // merkez + yarıçap + iki kerteriz
  lineOfSight, // Görüş hattı analizi
  rangeRings, // merkez + yarıçap → R, 2R, 3R menzil halkaları (ATAK R&B Circle)
}

class ToolState {
  final ToolMode mode;
  final List<LatLng> points;

  /// [points] ile aynı sırada: nokta bir nesneye dokunularak konduysa o
  /// nesnenin bağı (`RbEnd.selfRef` / `RbEnd.waypointRef`), yoksa null.
  /// Kalıcı R&B çizgisi uçlarını buna bağlar.
  final List<String?> refs;
  final bool visible;

  const ToolState({
    this.mode = ToolMode.none,
    this.points = const [],
    this.refs = const [],
    this.visible = true,
  });

  bool get active => mode != ToolMode.none;

  /// [i]. noktanın bağı (eski çağrılarda liste kısa olabilir).
  String? refAt(int i) => i < refs.length ? refs[i] : null;

  ToolState copyWith({
    ToolMode? mode,
    List<LatLng>? points,
    List<String?>? refs,
    bool? visible,
  }) => ToolState(
    mode: mode ?? this.mode,
    points: points ?? this.points,
    refs: refs ?? this.refs,
    visible: visible ?? this.visible,
  );
}

class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() => const ToolState();

  /// Bir araç seç (noktaları sıfırlar, görünür yapar).
  void setMode(ToolMode mode) =>
      state = ToolState(mode: mode, points: const [], visible: true);

  /// Haritaya (ya da bir nesneye: [ref]) dokununca çağrılır. Sektör en
  /// fazla 3 nokta alır.
  void addPoint(LatLng p, {String? ref}) {
    if (state.mode == ToolMode.none) return;
    if (state.mode == ToolMode.sector && state.points.length >= 3) return;
    final refs = [
      for (var i = 0; i < state.points.length; i++) state.refAt(i),
    ];
    // Menzil halkası: merkez sabit, sonraki dokunuşlar yarıçapı değiştirir.
    if (state.mode == ToolMode.rangeRings && state.points.length >= 2) {
      state = state.copyWith(
        points: [state.points.first, p],
        refs: [refs.first, ref],
      );
      return;
    }
    state = state.copyWith(
      points: [...state.points, p],
      refs: [...refs, ref],
    );
  }

  void undo() {
    if (state.points.isEmpty) return;
    final n = state.points.length - 1;
    state = state.copyWith(
      points: state.points.sublist(0, n),
      refs: [for (var i = 0; i < n; i++) state.refAt(i)],
    );
  }

  /// Noktaları temizle (araç modu kalır).
  void clearPoints() =>
      state = state.copyWith(points: const [], refs: const []);

  /// Aracı tamamen kapat.
  void reset() => state = const ToolState();

  void toggleVisible() => state = state.copyWith(visible: !state.visible);
}

final toolProvider = NotifierProvider<ToolNotifier, ToolState>(ToolNotifier.new);
