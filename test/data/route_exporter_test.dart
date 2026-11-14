import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/export/route_exporter.dart';
import 'package:usturlap/domain/models/route_plan.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// E8: rota GPX / KML dışa aktarma.
void main() {
  final route = RoutePlan(
    uid: 'r1',
    name: 'Devriye <A&B>',
    points: const [LatLng(37.06, 37.38), LatLng(37.07, 37.39)],
    pointNames: const [null, 'KÖPRÜ'],
    createdAt: DateTime.utc(2026),
  );

  test('GPX: rtept sırası, adlar, kaçış', () {
    final doc = XmlDocument.parse(RouteExporter.toGpx(route));
    final rte = doc.rootElement.getElement('rte')!;
    expect(rte.getElement('name')!.innerText, 'Devriye <A&B>');
    final pts = rte.findElements('rtept').toList();
    expect(pts, hasLength(2));
    expect(pts[0].getAttribute('lat'), '37.06');
    expect(pts[0].getAttribute('lon'), '37.38');
    expect(pts[0].getElement('name')!.innerText, 'BAŞLANGIÇ');
    expect(pts[1].getElement('name')!.innerText, 'KÖPRÜ');
  });

  test('KML: çizgi + adlı yer işaretleri (boylam, enlem sırası)', () {
    final doc = XmlDocument.parse(RouteExporter.toKml(route));
    final marks = doc.findAllElements('Placemark').toList();
    expect(marks, hasLength(3)); // çizgi + 2 nokta
    final line = marks.first.findAllElements('coordinates').single.innerText;
    expect(line.trim().split(RegExp(r'\s+')), [
      '37.38,37.06,0',
      '37.39,37.07,0',
    ]);
    expect(marks[2].getElement('name')!.innerText, 'KÖPRÜ');
  });
}
