import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/domain/models/cot_type.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('CotType.forSymbol', () {
    test('sade nokta → spot marker', () {
      expect(
        CotType.forSymbol(Affiliation.waypoint, SymbolRole.none),
        'b-m-p-s-m',
      );
      // Sade noktada rol anlamsız.
      expect(
        CotType.forSymbol(Affiliation.waypoint, SymbolRole.infantry),
        'b-m-p-s-m',
      );
    });

    test('sadakat + rol → 2525 kara birliği', () {
      expect(
        CotType.forSymbol(Affiliation.friend, SymbolRole.infantry),
        'a-f-G-U-C-I',
      );
      expect(
        CotType.forSymbol(Affiliation.hostile, SymbolRole.armor),
        'a-h-G-U-C-A',
      );
      expect(
        CotType.forSymbol(Affiliation.neutral, SymbolRole.artillery),
        'a-n-G-U-C-F',
      );
      expect(
        CotType.forSymbol(Affiliation.unknown, SymbolRole.recon),
        'a-u-G-U-C-R',
      );
    });

    test('rolsüz NATO sembolü → genel kara nesnesi', () {
      expect(CotType.forSymbol(Affiliation.unknown, SymbolRole.none), 'a-u-G');
    });
  });

  group('CotType.parse', () {
    test('forSymbol ile gidiş-dönüş', () {
      for (final a in Affiliation.values) {
        for (final r in SymbolRole.values) {
          final t = CotType.forSymbol(a, r);
          final back = CotType.parse(t);
          if (a == Affiliation.waypoint) {
            expect(back.affiliation, Affiliation.waypoint);
          } else {
            expect(back, (affiliation: a, role: r), reason: t);
          }
        }
      }
    });

    test('2525 ek sadakatleri en yakın çerçeveye', () {
      expect(CotType.parse('a-a-G').affiliation, Affiliation.friend);
      expect(CotType.parse('a-s-G').affiliation, Affiliation.hostile);
      expect(CotType.parse('a-j-G').affiliation, Affiliation.hostile);
      expect(CotType.parse('a-p-G').affiliation, Affiliation.unknown);
    });

    test('alt işlevler ana role düşer, benzerleri karışmaz', () {
      // Mekanize piyade → piyade.
      expect(CotType.parse('a-f-G-U-C-I-M').role, SymbolRole.infantry);
      // Zırhlı tekerlekli → zırhlı.
      expect(CotType.parse('a-h-G-U-C-A-W').role, SymbolRole.armor);
      // "U-C-A" ile başlayan ama başka segment: "U-C-AA" (hava savunma) zırhlı değil.
      expect(CotType.parse('a-h-G-U-C-AA').role, SymbolRole.none);
      // Hava (A) boyutunda kara rolü yok.
      expect(CotType.parse('a-f-A-M-F').role, SymbolRole.none);
    });

    test('atom olmayan tipler sade nokta sayılır', () {
      for (final t in ['b-m-p-s-m', 'b-m-p-w', 'u-d-f', 'b-m-r', '', 'a']) {
        expect(CotType.parse(t).affiliation, Affiliation.waypoint, reason: t);
      }
    });
  });

  test('Waypoint.cotType: ham tip varsa onu, yoksa sembolden türetir', () {
    final base = Waypoint(
      uid: 'x',
      name: 'T',
      position: const LatLng(0, 0),
      createdAt: DateTime(2026),
      affiliation: Affiliation.hostile,
      role: SymbolRole.armor,
    );
    expect(base.cotType, 'a-h-G-U-C-A');
    final imported = Waypoint(
      uid: 'y',
      name: 'T',
      position: const LatLng(0, 0),
      createdAt: DateTime(2026),
      affiliation: Affiliation.hostile,
      role: SymbolRole.armor,
      typeCode: 'a-h-G-U-C-A-W',
    );
    expect(imported.cotType, 'a-h-G-U-C-A-W');
  });
}
