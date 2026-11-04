/// Gece (ışık disiplini) modu için Mapbox stil düzenlemeleri — saf Dart.
///
/// Mapbox haritası iOS'ta native görünüm olduğundan Flutter renk filtresi
/// uygulanamaz; bu yüzden stilin kendisi değiştirilir:
/// - uydu/raster: siyah-beyaz + karartılmış (göz kamaştırmaz),
/// - yazılar: koyu kırmızı, siyah hale,
/// - yollar/sınırlar: sönük koyu kırmızı,
/// - zemin: siyah.
/// Uygulamanın kendi çizimleri (iz, waypoint, ölçüm) DEĞİŞTİRİLMEZ.
library;

/// Tek bir stil özelliği değişikliği.
typedef StyleEdit = ({String layerId, String property, Object value});

/// [layers]: stildeki (id, type) çiftleri. [keep]: dokunulmayacak katmanlar.
List<StyleEdit> nightStyleEdits(
  Iterable<({String id, String type})> layers, {
  Set<String> keep = const {},
}) {
  final out = <StyleEdit>[];
  void e(String id, String p, Object v) =>
      out.add((layerId: id, property: p, value: v));

  for (final l in layers) {
    if (keep.contains(l.id)) continue;
    switch (l.type) {
      case 'background':
        e(l.id, 'background-color', '#000000');
      case 'raster':
        e(l.id, 'raster-saturation', -1.0);
        e(l.id, 'raster-brightness-max', 0.4);
        e(l.id, 'raster-contrast', 0.15);
      case 'symbol':
        e(l.id, 'text-color', nightTextColor);
        e(l.id, 'text-halo-color', '#000000');
        e(l.id, 'text-halo-width', 1.2);
        e(l.id, 'icon-opacity', 0.5);
      case 'line':
        e(l.id, 'line-color', nightLineColor);
        e(l.id, 'line-opacity', 0.7);
      case 'fill':
        e(l.id, 'fill-color', '#1a0505');
      case 'sky':
        e(l.id, 'sky-opacity', 0.0);
      default:
        break; // fill-extrusion, hillshade vb. olduğu gibi
    }
  }
  return out;
}

const nightTextColor = '#b91c1c';
const nightLineColor = '#7f1d1d';
