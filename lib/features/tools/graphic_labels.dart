import 'package:flutter/material.dart';

import '../../core/geo_math.dart';
import '../../domain/models/map_graphic.dart';

/// Çizim türlerinin ortak görünümü: simge, ad öneki, kısa ölçü metni.

IconData graphicIcon(GraphicType t) => switch (t) {
  GraphicType.line => Icons.polyline_outlined,
  GraphicType.area => Icons.pentagon_outlined,
  GraphicType.circle => Icons.circle_outlined,
  GraphicType.rectangle => Icons.crop_square,
};

/// Ad önekleri (sıra numarası eklenir: DAİRE-2).
String graphicPrefix(GraphicType t) => switch (t) {
  GraphicType.line => 'ÇİZGİ',
  GraphicType.area => 'ALAN',
  GraphicType.circle => 'DAİRE',
  GraphicType.rectangle => 'DİKDÖRTGEN',
};

/// Türe göre kısa ölçü: çizgi uzunluk, daire yarıçap + alan, alan /
/// dikdörtgen alan + köşe.
String graphicMeasure(MapGraphic g) {
  switch (g.type) {
    case GraphicType.line:
      return '${GeoMath.fmtDistance(GeoMath.pathLength(g.points))}'
          ' · ${g.points.length} nokta';
    case GraphicType.circle:
      final r = g.radiusMeters;
      return 'r = ${GeoMath.fmtDistance(r)}'
          ' · ${GeoMath.fmtArea(3.141592653589793 * r * r)}';
    case GraphicType.area:
    case GraphicType.rectangle:
      if (g.points.length < 3) return '${g.points.length} köşe';
      return '${GeoMath.fmtArea(GeoMath.polygonArea(g.points))}'
          ' · ${g.points.length} köşe';
  }
}
