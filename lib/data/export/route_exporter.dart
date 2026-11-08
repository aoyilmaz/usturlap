import '../../domain/models/route_plan.dart';

/// Rotaları GPX / KML metnine çeviren saf yardımcılar (paylaşım katmanı
/// ayrı). Nokta adları Pusula'daki gibi (verilmemişse BAŞLANGIÇ, KN1…).
class RouteExporter {
  RouteExporter._();

  /// GPX 1.1 `<rte>`: el GPS'leri ve çoğu harita uygulaması açar.
  static String toGpx(RoutePlan r) {
    final pts = StringBuffer();
    for (var i = 0; i < r.points.length; i++) {
      final p = r.points[i];
      pts.writeln(
        '    <rtept lat="${p.latitude}" lon="${p.longitude}">'
        '<name>${_xml(r.nameOf(i))}</name></rtept>',
      );
    }
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Pusula" xmlns="http://www.topografix.com/GPX/1/1">
  <rte>
    <name>${_xml(r.name)}</name>
${pts.toString().trimRight()}
  </rte>
</gpx>
''';
  }

  /// KML: rota çizgisi + her nokta için adlı yer işareti (Google Earth vb.).
  static String toKml(RoutePlan r) {
    final coords = r.points
        .map((p) => '${p.longitude},${p.latitude},0')
        .join('\n          ');
    final marks = StringBuffer();
    for (var i = 0; i < r.points.length; i++) {
      final p = r.points[i];
      marks.writeln('''
    <Placemark>
      <name>${_xml(r.nameOf(i))}</name>
      <Point><coordinates>${p.longitude},${p.latitude},0</coordinates></Point>
    </Placemark>''');
    }
    final name = _xml(r.name);
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$name</name>
    <Placemark>
      <name>$name</name>
      <LineString>
        <tessellate>1</tessellate>
        <coordinates>
          $coords
        </coordinates>
      </LineString>
    </Placemark>
${marks.toString().trimRight()}
  </Document>
</kml>
''';
  }

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
