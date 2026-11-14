import 'dart:math' as math;

/// Web Mercator (EPSG:3857) dünya yarı genişliği (m).
const webMercatorHalf = 20037508.342789244;

/// Bir GeoPackage zoom düzeyinin XYZ karşılığı.
class GpkgZoom {
  const GpkgZoom({
    required this.zoomLevel,
    required this.xyzZoom,
    required this.colOffset,
    required this.rowOffset,
    required this.width,
    required this.height,
  });

  /// GeoPackage `zoom_level`.
  final int zoomLevel;

  /// Harita (XYZ) zoom'u.
  final int xyzZoom;

  /// XYZ x = sütun + [colOffset]; y = satır + [rowOffset].
  final int colOffset;
  final int rowOffset;
  final int width;
  final int height;
}

/// GeoPackage karo matrisi → harita karoları (z/x/y). Saf Dart.
///
/// Yalnız Web Mercator ve küresel XYZ ızgarasına hizalı matrisler: her
/// düzeyde karo açıklığı dünya genişliği / 2^z olmalı, matris sol üst köşesi
/// tam karo sınırına düşmeli (gdal `TILING_SCHEME=GoogleMapsCompatible`
/// böyle üretir). GeoPackage satırları üstten sayar (MBTiles gibi ters değil).
class GpkgTileGrid {
  GpkgTileGrid._(this._byXyz, this.boundsMercator);

  final Map<int, GpkgZoom> _byXyz;

  /// Kapsam (Web Mercator m): [minX, minY, maxX, maxY].
  final List<double> boundsMercator;

  Iterable<GpkgZoom> get levels => _byXyz.values;
  int get minZoom => _byXyz.keys.reduce(math.min);
  int get maxZoom => _byXyz.keys.reduce(math.max);

  /// [matrixSet]: `gpkg_tile_matrix_set` sınırları (m). [contents]: varsa
  /// `gpkg_contents` sınırları (gerçek veri kapsamı; yoksa matris seti).
  static GpkgTileGrid build({
    required List<double> matrixSet,
    required List<({int zoomLevel, int matrixWidth, int matrixHeight})>
    matrices,
    List<double>? contents,
  }) {
    final minX = matrixSet[0], minY = matrixSet[1];
    final maxX = matrixSet[2], maxY = matrixSet[3];
    if (!(maxX > minX && maxY > minY) || matrices.isEmpty) {
      throw const FormatException('GeoPackage karo matrisi boş ya da bozuk.');
    }
    const world = 2 * webMercatorHalf;
    bool near(double v) => (v - v.roundToDouble()).abs() < 1e-3;
    final out = <int, GpkgZoom>{};
    for (final m in matrices) {
      if (m.matrixWidth <= 0 || m.matrixHeight <= 0) continue;
      final spanX = (maxX - minX) / m.matrixWidth;
      final spanY = (maxY - minY) / m.matrixHeight;
      final zf = math.log(world / spanX) / math.ln2;
      final cols = (minX + webMercatorHalf) / spanX;
      final rows = (webMercatorHalf - maxY) / spanY;
      if (!near(zf) ||
          (spanX - spanY).abs() > spanX * 1e-6 ||
          !near(cols) ||
          !near(rows)) {
        throw const FormatException(
          'GeoPackage karoları Web Mercator ızgarasına hizalı değil.',
        );
      }
      final z = zf.round();
      if (z < 0 || z > 24) continue;
      out[z] = GpkgZoom(
        zoomLevel: m.zoomLevel,
        xyzZoom: z,
        colOffset: cols.round(),
        rowOffset: rows.round(),
        width: m.matrixWidth,
        height: m.matrixHeight,
      );
    }
    if (out.isEmpty) {
      throw const FormatException('GeoPackage\'da kullanılabilir zoom yok.');
    }
    return GpkgTileGrid._(out, contents ?? matrixSet);
  }

  /// Harita karosunun GeoPackage karşılığı (kapsam dışıysa null).
  ({int zoomLevel, int col, int row})? locate(int z, int x, int y) {
    final l = _byXyz[z];
    if (l == null) return null;
    final col = x - l.colOffset, row = y - l.rowOffset;
    if (col < 0 || row < 0 || col >= l.width || row >= l.height) return null;
    return (zoomLevel: l.zoomLevel, col: col, row: row);
  }

  /// Kapsam WGS84 derece: [batı, güney, doğu, kuzey].
  List<double> get boundsWgs84 {
    double lon(double x) => x / webMercatorHalf * 180;
    double lat(double y) =>
        math.atan(_sinh(y / webMercatorHalf * math.pi)) * 180 / math.pi;
    return [
      lon(boundsMercator[0]),
      lat(boundsMercator[1]),
      lon(boundsMercator[2]),
      lat(boundsMercator[3]),
    ];
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
}
