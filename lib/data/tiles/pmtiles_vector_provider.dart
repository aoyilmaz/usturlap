import 'dart:typed_data';

import 'package:pmtiles/pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// PMTiles arşivinden vektör (MVT) karo okuyan `vector_map_tiles` sağlayıcısı.
///
/// Hazır `vector_map_tiles_pmtiles` paketi flutter_map 8.x ile uyumsuz olduğundan
/// (eski vector_map_tiles 7.x'e bağlı) provider'ı kendimiz yazıyoruz: `pmtiles`
/// paketiyle arşivi açıp z/x/y → tileId ile karoyu okur, gzip'i çözüp ham MVT
/// baytlarını döndürür. Arşiv dosyadan aralık (range) okur — 51 MB belleğe
/// yüklenmez.
class PmtilesVectorTileProvider extends VectorTileProvider {
  PmtilesVectorTileProvider._(this._archive, this._minZoom, this._maxZoom);

  final PmTilesArchive _archive;
  final int _minZoom;
  final int _maxZoom;

  /// Yerel bir .pmtiles dosyasını açar (header'dan zoom aralığını okur).
  static Future<PmtilesVectorTileProvider> open(String path) async {
    final archive = await PmTilesArchive.from(path);
    return PmtilesVectorTileProvider._(
        archive, archive.header.minZoom, archive.header.maxZoom);
  }

  @override
  int get minimumZoom => _minZoom;

  @override
  int get maximumZoom => _maxZoom;

  /// PMTiles header'ındaki varsayılan merkez (içe-aktarmada katman merkezi için).
  double get centerLatitude => _archive.centerPosition.latitude;
  double get centerLongitude => _archive.centerPosition.longitude;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;

  @override
  TileProviderType get type => TileProviderType.vector;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      final id = ZXY(tile.z, tile.x, tile.y).toTileId();
      final t = await _archive.tile(id);
      return Uint8List.fromList(t.bytes());
    } catch (_) {
      // Kapsam dışındaki/eksik karolar → boş MVT (hiçbir şey çizilmez, hata yok).
      return Uint8List(0);
    }
  }

  Future<void> dispose() => _archive.close();
}
