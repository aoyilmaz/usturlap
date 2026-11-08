import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/domain/models/saved_view.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final v = SavedView(
    id: 'a',
    name: 'Kale',
    center: const LatLng(39.94, 32.86),
    zoom: 15.5,
    bearing: 30,
    layerId: 'sat',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );

  test('JSON gidiş-dönüş', () {
    final back = SavedView.fromJson(v.toJson())!;
    expect(back.id, 'a');
    expect(back.name, 'Kale');
    expect(back.center, v.center);
    expect(back.zoom, 15.5);
    expect(back.bearing, 30);
    expect(back.layerId, 'sat');
    expect(back.createdAt, v.createdAt);
  });

  test('eksik ya da bozuk kayıt null', () {
    expect(SavedView.fromJson('x'), isNull);
    expect(SavedView.fromJson({'id': 'a', 'name': 'b'}), isNull);
    expect(
      SavedView.fromJson({
        'id': 'a',
        'name': 'b',
        'lat': 120,
        'lon': 0,
        'zoom': 3,
      }),
      isNull,
    );
    // Katman ve yön isteğe bağlı.
    final min = SavedView.fromJson({
      'id': 'a',
      'name': 'b',
      'lat': 1,
      'lon': 2,
      'zoom': 3,
    })!;
    expect(min.bearing, 0);
    expect(min.layerId, isNull);
  });

  test('yeniden adlandırma diğer alanları korur', () {
    final r = v.renamed('Kale 2');
    expect(r.name, 'Kale 2');
    expect(r.id, v.id);
    expect(r.center, v.center);
  });
}
