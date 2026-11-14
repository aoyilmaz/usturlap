import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/cot_type.dart';
import 'package:usturlap/domain/models/waypoint.dart';
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

    test('yeni sadakatler, tehlikeler ve görev noktaları', () {
      expect(
        CotType.forSymbol(Affiliation.suspect, SymbolRole.infantry),
        'a-s-G-U-C-I',
      );
      expect(
        CotType.forSymbol(Affiliation.assumedFriend, SymbolRole.none),
        'a-a-G',
      );
      expect(
        CotType.forSymbol(Affiliation.hostile, SymbolRole.mine),
        'a-h-G-E-X-M',
      );
      expect(
        CotType.forSymbol(Affiliation.hostile, SymbolRole.cbrn),
        'a-h-G-E-X-N',
      );
      expect(
        CotType.forSymbol(Affiliation.unknown, SymbolRole.barrier),
        'a-u-G-I-c-bar',
      );
      for (final a in Affiliation.values.where((a) => a.isMission)) {
        expect(CotType.forSymbol(a, SymbolRole.none), CotType.spotMarker);
      }
    });
  });

  group('CotType.parse', () {
    test('forSymbol ile gidiş-dönüş', () {
      for (final a in Affiliation.values) {
        for (final r in SymbolRole.values) {
          final t = CotType.forSymbol(a, r);
          final back = CotType.parse(t);
          if (!a.isNato) {
            // Sade nokta ve görev noktaları ATAK'a sade işaretçi olarak gider.
            expect(t, CotType.spotMarker, reason: a.name);
            expect(back.affiliation, Affiliation.waypoint);
          } else {
            expect(back, (affiliation: a, role: r), reason: t);
          }
        }
      }
    });

    test('varsayılan dost / şüpheli kendi türüne, diğer ekler en yakına', () {
      expect(CotType.parse('a-a-G').affiliation, Affiliation.assumedFriend);
      expect(CotType.parse('a-s-G').affiliation, Affiliation.suspect);
      expect(CotType.parse('a-j-G').affiliation, Affiliation.hostile);
      expect(CotType.parse('a-k-G').affiliation, Affiliation.hostile);
      expect(CotType.parse('a-p-G').affiliation, Affiliation.unknown);
    });

    test('tehlike ikonları: katalog kodları ve takma adları', () {
      expect(CotType.parse('a-h-G-E-X-M').role, SymbolRole.mine);
      expect(CotType.parse('a-u-G-E-X-N').role, SymbolRole.cbrn);
      // KBRN tesisi ve alt tipleri (kimyasal / biyolojik) de KBRN.
      expect(CotType.parse('a-h-G-I-R-N').role, SymbolRole.cbrn);
      expect(CotType.parse('a-h-G-I-R-N-C').role, SymbolRole.cbrn);
      expect(CotType.parse('a-h-G-I-R-N-B').role, SymbolRole.cbrn);
      expect(CotType.parse('a-n-G-I-c-bar').role, SymbolRole.barrier);
      // "Maden ocağı" yapısı kara mayını değil.
      expect(CotType.parse('a-n-G-I-R-M').role, SymbolRole.none);
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
