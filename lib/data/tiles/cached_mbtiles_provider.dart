import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mbtiles/mbtiles.dart';

/// MBTiles karo sağlayıcı — flutter_map_mbtiles'in aksine `ImageProvider`'ı
/// `==`/`hashCode` ile tanımlar. Böylece çözülen karolar Flutter'ın global
/// `ImageCache`'ine girer: katmanlar arası geçiş ve geri dönüşlerde karolar
/// sqlite'tan tekrar okunup tekrar çözülmez → çok daha hızlı geçiş.
class CachedMbtilesTileProvider extends TileProvider {
  CachedMbtilesTileProvider.fromPath({
    required this.path,
    this.silenceTileNotFound = true,
  }) : mbtiles = MbTiles(mbtilesPath: path);

  /// Önbellek kimliği için kullanılır (her .mbtiles dosyası benzersiz).
  final String path;
  final MbTiles mbtiles;
  final bool silenceTileNotFound;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _CachedMbtilesImage(
        path: path,
        coordinates: coordinates,
        mbtiles: mbtiles,
        silenceTileNotFound: silenceTileNotFound,
      );

  @override
  void dispose() {
    mbtiles.dispose();
    super.dispose();
  }
}

class _CachedMbtilesImage extends ImageProvider<_CachedMbtilesImage> {
  const _CachedMbtilesImage({
    required this.path,
    required this.coordinates,
    required this.mbtiles,
    required this.silenceTileNotFound,
  });

  final String path;
  final TileCoordinates coordinates;
  final MbTiles mbtiles;
  final bool silenceTileNotFound;

  @override
  Future<_CachedMbtilesImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CachedMbtilesImage>(this);

  @override
  ImageStreamCompleter loadImage(
      _CachedMbtilesImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: '$path ${coordinates.z}/${coordinates.x}/${coordinates.y}',
    );
  }

  Future<Codec> _load(ImageDecoderCallback decode) async {
    // MBTiles TMS şemasında saklar: xyz y → tms y.
    final tmsY = ((1 << coordinates.z) - 1) - coordinates.y;
    final bytes = mbtiles.getTile(z: coordinates.z, x: coordinates.x, y: tmsY);
    if (bytes == null) {
      if (silenceTileNotFound) {
        return decode(
            await ImmutableBuffer.fromUint8List(TileProvider.transparentImage));
      }
      throw StateError(
          'Karo bulunamadı: ${coordinates.z}/${coordinates.x}/${coordinates.y}');
    }
    return decode(await ImmutableBuffer.fromUint8List(bytes));
  }

  // Önbellek anahtarı: dosya yolu + karo koordinatı (mbtiles örneği/silence
  // eşitliğe dahil DEĞİL — aynı karo farklı provider örneklerinde de cache'lensin).
  @override
  bool operator ==(Object other) =>
      other is _CachedMbtilesImage &&
      other.path == path &&
      other.coordinates.z == coordinates.z &&
      other.coordinates.x == coordinates.x &&
      other.coordinates.y == coordinates.y;

  @override
  int get hashCode =>
      Object.hash(path, coordinates.z, coordinates.x, coordinates.y);
}
