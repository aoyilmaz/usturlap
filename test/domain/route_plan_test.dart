import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/route_plan.dart';
import 'package:latlong2/latlong.dart';

/// E8: rota nokta adları ve ters çevirme.
void main() {
  final r = RoutePlan(
    uid: 'r',
    name: 'R',
    points: const [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2)],
    pointNames: const ['KAMP', ' ', null],
    createdAt: DateTime(2026),
  );

  test('ad: verilen ya da varsayılan; boşluk ad sayılmaz', () {
    expect(r.nameOf(0), 'KAMP');
    expect(r.nameOf(1), 'KN1');
    expect(r.nameOf(2), 'KN2');
    // Ad listesi kısa olabilir (eski kayıt).
    final old = RoutePlan(
      uid: 'o',
      name: 'O',
      points: r.points,
      createdAt: DateTime(2026),
    );
    expect(old.nameOf(0), 'BAŞLANGIÇ');
  });

  test('ters çevir: noktalar ve adlar ters, uzunluk aynı', () {
    final rev = r.reversed();
    expect(rev.points, r.points.reversed.toList());
    expect(rev.nameOf(0), 'BAŞLANGIÇ'); // eski KN2 adsızdı
    expect(rev.nameOf(2), 'KAMP');
    expect(rev.length, closeTo(r.length, 1e-6));
    expect(rev.uid, r.uid);
  });
}
