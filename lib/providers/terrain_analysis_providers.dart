import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/elevation/dem_tile.dart';
import '../domain/usecases/terrain_grid.dart';
import 'elevation_providers.dart';

/// Renkli arazi katmanının türü.
enum TerrainColorMode {
  slope('Eğim'),
  elevation('Yükseklik');

  const TerrainColorMode(this.label);
  final String label;
}

/// Haritaya gerilecek renkli katman (ön-çarpılmış RGBA, satırlar kuzeyden).
class TerrainLayerImage {
  const TerrainLayerImage({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.width,
    required this.height,
    required this.pixels,
  });

  final double north, south, east, west;
  final int width, height;
  final Uint8List pixels;
}

/// Eğri aralığı: yükseklik farkı en çok ~20 eğri verecek en küçük düzgün
/// aralık (5, 10, 20, 25, 50, 100, 200 m).
double autoContourInterval(double low, double high) {
  final span = high - low;
  for (final i in const <double>[5, 10, 20, 25, 50, 100, 200]) {
    if (span / i <= 20) return i;
  }
  return 500;
}

/// Haritadaki arazi analizi: eş yükselti eğrileri ve / veya renkli katman.
class TerrainAnalysisState {
  const TerrainAnalysisState({
    this.contours = const [],
    this.interval,
    this.colorMode,
    this.image,
    this.range,
    this.busy = false,
    this.error,
  });

  final List<ContourLine> contours;

  /// Eğri aralığı (m); eğri yoksa null.
  final double? interval;
  final TerrainColorMode? colorMode;
  final TerrainLayerImage? image;

  /// Alandaki en alçak / en yüksek (m).
  final (double, double)? range;
  final bool busy;
  final String? error;

  bool get isEmpty => contours.isEmpty && image == null;

  TerrainAnalysisState copyWith({
    List<ContourLine>? contours,
    double? interval,
    TerrainColorMode? colorMode,
    TerrainLayerImage? image,
    (double, double)? range,
    bool? busy,
    String? error,
    bool clearContours = false,
    bool clearImage = false,
    bool clearError = false,
  }) => TerrainAnalysisState(
    contours: clearContours ? const [] : contours ?? this.contours,
    interval: clearContours ? null : interval ?? this.interval,
    colorMode: clearImage ? null : colorMode ?? this.colorMode,
    image: clearImage ? null : image ?? this.image,
    range: range ?? this.range,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

/// Arka plan işinin sonucu.
typedef _Result = ({
  List<ContourLine>? contours,
  double? interval,
  TerrainLayerImage? image,
  (double, double)? range,
});

_Result? _analyze(
  LatLng center,
  double halfSize,
  List<(int, int, Uint8List)> raw, {
  required bool contours,
  double? interval,
  TerrainColorMode? color,
}) {
  final tiles = {
    for (final (s, w, b) in raw)
      DemTile.keyFor(s, w): DemTile.parse(b, south: s, west: w),
  };
  double? elevation(double lat, double lon) {
    final v = tiles[DemTile.keyFor(lat.floor(), lon.floor())]?.sample(lat, lon);
    return v == null || v < -500 ? null : v;
  }

  final g = TerrainGrid.sample(center, halfSize, elevation);
  final range = g.range;
  if (range == null) return null;
  final step = interval ?? autoContourInterval(range.$1, range.$2);
  return (
    contours: contours ? g.contours(step) : null,
    interval: contours ? step : null,
    image: color == null
        ? null
        : TerrainLayerImage(
            north: g.north,
            south: g.south,
            east: g.east,
            west: g.west,
            width: g.cols,
            height: g.rows,
            pixels: color == TerrainColorMode.slope
                ? g.slopeRgba()
                : g.elevationRgba(),
          ),
    range: range,
  );
}

class TerrainAnalysisNotifier extends Notifier<TerrainAnalysisState?> {
  int _gen = 0;

  @override
  TerrainAnalysisState? build() => null;

  /// Eş yükselti eğrileri; [interval] null ise otomatik.
  Future<void> drawContours(
    LatLng center,
    double halfSize, {
    double? interval,
  }) => _run(center, halfSize, contours: true, interval: interval);

  Future<void> drawColor(
    LatLng center,
    double halfSize,
    TerrainColorMode mode,
  ) => _run(center, halfSize, contours: false, color: mode);

  Future<void> _run(
    LatLng center,
    double halfSize, {
    required bool contours,
    double? interval,
    TerrainColorMode? color,
  }) async {
    final gen = ++_gen;
    state = (state ?? const TerrainAnalysisState()).copyWith(
      busy: true,
      clearError: true,
    );
    try {
      final dLat = halfSize / 111000 + 0.01;
      final dLon = dLat / math.cos(center.latitude * math.pi / 180);
      final tiles = await ref
          .read(hgtParserProvider)
          .tilesIn(
            south: center.latitude - dLat,
            north: center.latitude + dLat,
            west: center.longitude - dLon,
            east: center.longitude + dLon,
          );
      final raw = [for (final t in tiles) (t.south, t.west, t.bytes)];
      final r = raw.isEmpty
          ? null
          : await Isolate.run(
              () => _analyze(
                center,
                halfSize,
                raw,
                contours: contours,
                interval: interval,
                color: color,
              ),
            );
      if (gen != _gen || !ref.mounted) return;
      final s = state ?? const TerrainAnalysisState();
      if (r == null) {
        state = s.copyWith(
          busy: false,
          error: 'Bu alanda arazi verisi yok (≡ → Harita → Yükseklik verisi).',
        );
        return;
      }
      state = contours
          ? s.copyWith(
              busy: false,
              contours: r.contours,
              interval: r.interval,
              range: r.range,
            )
          : s.copyWith(
              busy: false,
              colorMode: color,
              image: r.image,
              range: r.range,
            );
    } catch (e) {
      if (gen != _gen || !ref.mounted) return;
      state = (state ?? const TerrainAnalysisState()).copyWith(
        busy: false,
        error: 'Hesaplanamadı: $e',
      );
    }
  }

  void clearContours() => _set(state?.copyWith(clearContours: true));
  void clearColor() => _set(state?.copyWith(clearImage: true));

  void clear() {
    _gen++;
    state = null;
  }

  /// "Haritayı temizle" → Geri al.
  void restore(TerrainAnalysisState? s) {
    _gen++;
    state = s;
  }

  void _set(TerrainAnalysisState? s) =>
      state = s == null || (s.isEmpty && !s.busy) ? null : s;
}

final terrainAnalysisProvider =
    NotifierProvider<TerrainAnalysisNotifier, TerrainAnalysisState?>(
      TerrainAnalysisNotifier.new,
    );
