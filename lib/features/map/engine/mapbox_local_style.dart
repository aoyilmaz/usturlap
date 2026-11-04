import 'dart:convert';

import '../../../data/tiles/local_tile_server.dart';

/// Kullanıcının kendi karo dosyaları için Mapbox stil JSON'u üretir (saf Dart).
///
/// Karolar yerel sunucudan ([LocalTileServer]) gelir; stil yalnızca nereden
/// alınacaklarını ve nasıl çizileceklerini söyler.

/// Mapbox font servisi (uydu stiliyle aynı → indirilen bölgelerde önbellekte).
const mapboxGlyphs = 'mapbox://fonts/mapbox/{fontstack}/{range}.pbf';
const defaultTextFont = ['DIN Pro Medium', 'Arial Unicode MS Regular'];

const _background = {
  'id': 'pz-bg',
  'type': 'background',
  'paint': {'background-color': '#1b1f23'},
};

Map<String, Object?> _source(LocalTileSourceInfo info, String type,
    {String? attribution}) {
  return {
    'type': type,
    'tiles': [info.urlTemplate],
    if (type == 'raster') 'tileSize': 256,
    'minzoom': ?info.minZoom,
    'maxzoom': ?info.maxZoom,
    'bounds': ?info.bounds,
    'attribution': ?attribution,
  };
}

/// Raster (png/jpg/webp) MBTiles/PMTiles için stil.
String localRasterStyle(LocalTileSourceInfo info, {String? attribution}) {
  return jsonEncode({
    'version': 8,
    'sources': {
      'pz-base': _source(info, 'raster', attribution: attribution),
    },
    'layers': [
      _background,
      {'id': 'pz-base', 'type': 'raster', 'source': 'pz-base'},
    ],
  });
}

/// Vektör karolar için: kullanıcının MapLibre/Mapbox stil JSON'u alınır,
/// tüm vektör kaynakları yerel sunucuya yönlendirilir, eksik font/glyph
/// tamamlanır (Mapbox yazı çizmek için glyph ister).
String localVectorStyle(
  Map<String, dynamic> style,
  LocalTileSourceInfo info, {
  String? attribution,
}) {
  // Derin kopya: asset'ten okunan orijinal bozulmasın.
  final s = jsonDecode(jsonEncode(style)) as Map<String, dynamic>;
  s['version'] = 8;
  s['glyphs'] ??= mapboxGlyphs;

  final sources = (s['sources'] as Map<String, dynamic>?) ?? {};
  for (final key in sources.keys.toList()) {
    final src = sources[key] as Map<String, dynamic>;
    if (src['type'] == 'vector') {
      sources[key] = _source(info, 'vector', attribution: attribution);
    }
  }
  s['sources'] = sources;

  final layers = (s['layers'] as List?) ?? const [];
  for (final l in layers) {
    final layout = (l as Map<String, dynamic>)['layout'] as Map<String, dynamic>?;
    if (layout != null &&
        layout.containsKey('text-field') &&
        !layout.containsKey('text-font')) {
      layout['text-font'] = defaultTextFont;
    }
  }
  return jsonEncode(s);
}
