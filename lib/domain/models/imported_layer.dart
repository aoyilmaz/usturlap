/// Uygulama içinden içe-aktarılmış bir harita paketi (Documents'taki dosya).
/// Saf Dart modeli — data katmanı drift satırını buna çevirir.
class ImportedLayer {
  final String id;
  final String label;

  /// Documents dizinindeki dosya adı (ör. 'turkey.pmtiles').
  final String fileName;

  /// 'pmtiles' (vektör) | 'mbtiles' (raster).
  final String sourceType;

  /// Vektör için MapLibre stil asset yolu; raster'da null.
  final String? stylePath;

  final int? minZoom;
  final int? maxZoom;
  final double? centerLat;
  final double? centerLon;

  const ImportedLayer({
    required this.id,
    required this.label,
    required this.fileName,
    required this.sourceType,
    this.stylePath,
    this.minZoom,
    this.maxZoom,
    this.centerLat,
    this.centerLon,
  });

  bool get isVector => sourceType == 'pmtiles';
}
