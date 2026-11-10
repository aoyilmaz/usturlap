import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/elevation/dem_tile.dart';
import '../data/elevation/hgt_parser.dart';
import '../domain/usecases/viewshed.dart';
import 'elevation_providers.dart';

/// Görüş alanını arka planda (ayrı isolate) hesaplar: gereken yükseklik
/// kareleri baytlarıyla aktarılır, sonuç ızgara döner. Gözlemcinin yerinde
/// veri yoksa null.
Future<ViewshedGrid?> computeViewshedInBackground(
  ViewshedParams p,
  HgtParser parser,
) async {
  final dLat = p.radius / 111000 + 0.01;
  final dLon = dLat / math.cos(p.observer.latitude * math.pi / 180);
  final tiles = await parser.tilesIn(
    south: p.observer.latitude - dLat,
    north: p.observer.latitude + dLat,
    west: p.observer.longitude - dLon,
    east: p.observer.longitude + dLon,
  );
  if (tiles.isEmpty) return null;
  final raw = [for (final t in tiles) (t.south, t.west, t.bytes)];
  return Isolate.run(() => _compute(p, raw));
}

ViewshedGrid? _compute(ViewshedParams p, List<(int, int, Uint8List)> raw) {
  final tiles = {
    for (final (s, w, b) in raw)
      DemTile.keyFor(s, w): DemTile.parse(b, south: s, west: w),
  };
  double? elevation(double lat, double lon) {
    final t = tiles[DemTile.keyFor(lat.floor(), lon.floor())];
    final v = t?.sample(lat, lon);
    return v == null || v < -500 ? null : v;
  }

  return Viewshed.compute(p, elevation);
}

/// Haritadaki görüş alanı (tek; yenisi eskisinin yerini alır).
class ViewshedState {
  const ViewshedState({
    required this.params,
    this.observerName,
    this.grid,
    this.busy = false,
    this.error,
  });

  final ViewshedParams params;
  final String? observerName;
  final ViewshedGrid? grid;
  final bool busy;
  final String? error;
}

class ViewshedNotifier extends Notifier<ViewshedState?> {
  int _gen = 0;

  @override
  ViewshedState? build() => null;

  Future<void> run(ViewshedParams p, {String? observerName}) async {
    final gen = ++_gen;
    state = ViewshedState(params: p, observerName: observerName, busy: true);
    try {
      final grid = await computeViewshedInBackground(
        p,
        ref.read(hgtParserProvider),
      );
      if (gen != _gen || !ref.mounted) return; // daha yenisi başladı
      state = ViewshedState(
        params: p,
        observerName: observerName,
        grid: grid,
        error: grid == null
            ? 'Gözlemcinin yerinde arazi verisi yok (≡ → Harita → '
                  'Yükseklik verisi).'
            : null,
      );
    } catch (e) {
      if (gen != _gen || !ref.mounted) return;
      state = ViewshedState(
        params: p,
        observerName: observerName,
        error: 'Hesaplanamadı: $e',
      );
    }
  }

  void clear() {
    _gen++;
    state = null;
  }

  /// "Haritayı temizle" → Geri al.
  void restore(ViewshedState? s) {
    _gen++;
    state = s;
  }
}

final viewshedProvider = NotifierProvider<ViewshedNotifier, ViewshedState?>(
  ViewshedNotifier.new,
);
