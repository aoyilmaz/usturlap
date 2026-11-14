import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/export/geo_exporter.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// KML dışa aktarma: yapı, açıklama, kaçış, renk (G4 seçimden taşındı).
void main() {
  test('nokta, kapalı çizim, R&B; renk aabbggrr', () {
    final kml = GeoExporter.toKml(
      name: 'Seçim <1>',
      ExportSet(
        waypoints: [
          Waypoint(
            uid: 'w',
            name: 'OP-1',
            position: const LatLng(37.1, 37.2),
            createdAt: DateTime(2026),
            note: 'gözetleme & dinleme',
          ),
        ],
        graphics: [
          MapGraphic(
            uid: 'g',
            name: 'ALAN-1',
            type: GraphicType.area,
            points: const [
              LatLng(37, 37),
              LatLng(37, 37.1),
              LatLng(37.1, 37.1),
            ],
            colorValue: 0xFF2E7DFF,
            createdAt: DateTime(2026),
          ),
        ],
        rangeLines: [
          RangeLine(
            uid: 'r',
            name: 'R&B-1',
            start: const RbEnd(LatLng(37, 37)),
            end: const RbEnd(LatLng(37.1, 37)),
            colorValue: RangeLine.defaultColor,
            createdAt: DateTime(2026),
          ),
        ],
      ),
    );
    final doc = XmlDocument.parse(kml);
    expect(doc.findAllElements('name').first.innerText, 'Seçim <1>');
    final marks = doc.findAllElements('Placemark').toList();
    expect(marks, hasLength(3));
    expect(
      marks[0].getElement('description')!.innerText,
      'gözetleme & dinleme',
    );
    expect(
      marks[0].findAllElements('coordinates').single.innerText,
      '37.2,37.1,0',
    );
    // Alan kapalı halka: 3 köşe + kapanış.
    final ring = marks[1].findAllElements('coordinates').single.innerText;
    expect(ring.trim().split(' '), hasLength(4));
    expect(marks[2].findAllElements('LineString'), hasLength(1));
    expect(GeoExporter.kmlColor(0xFF2E7DFF), 'ffff7d2e');
  });
}
