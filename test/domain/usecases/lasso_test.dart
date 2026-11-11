import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/domain/usecases/lasso.dart';
import 'package:latlong2/latlong.dart';

/// G4: lasso seçimi.
void main() {
  // 37.0–37.1 enlem, 37.0–37.1 boylam kare.
  const square = [
    LatLng(37.0, 37.0),
    LatLng(37.0, 37.1),
    LatLng(37.1, 37.1),
    LatLng(37.1, 37.0),
  ];

  test('içeride / dışarıda; içbükey çokgen', () {
    expect(pointInPolygon(const LatLng(37.05, 37.05), square), isTrue);
    expect(pointInPolygon(const LatLng(37.2, 37.05), square), isFalse);
    // U biçimi: ortadaki boşluk dışarıda.
    const u = [
      LatLng(0, 0),
      LatLng(0, 3),
      LatLng(3, 3),
      LatLng(3, 2),
      LatLng(1, 2),
      LatLng(1, 1),
      LatLng(3, 1),
      LatLng(3, 0),
    ];
    expect(pointInPolygon(const LatLng(2, 1.5), u), isFalse);
    expect(pointInPolygon(const LatLng(0.5, 1.5), u), isTrue);
    expect(pointInPolygon(const LatLng(1, 1), const [LatLng(0, 0)]), isFalse);
  });

  test('nesnelerden biri içerdeyse seçilir', () {
    final items = {
      'içeride': [const LatLng(37.05, 37.05)],
      'dışarıda': [const LatLng(37.5, 37.5)],
      'yarı': [const LatLng(37.5, 37.5), const LatLng(37.09, 37.01)],
    };
    expect(lassoSelect(square, items.keys, (k) => items[k]!), [
      'içeride',
      'yarı',
    ]);
  });
}
