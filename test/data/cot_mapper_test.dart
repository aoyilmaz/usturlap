import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/cot/cot_event.dart';
import 'package:kerteriz/data/cot/cot_mapper.dart';
import 'package:kerteriz/data/cot/cot_xml.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/models/map_item.dart';
import 'package:kerteriz/domain/models/route_plan.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 12);
  final mapper = CotMapper(
    creatorUid: 'PUSULA-test',
    creatorCallsign: 'KURT-1',
    clock: () => now,
  );

  /// Nesne → XML → olay → nesne.
  MapItem roundTrip(MapItem item) =>
      mapper.toItem(CotXml.decode(CotXml.encode(mapper.toEvent(item))))!;

  group('nokta', () {
    final spot = Waypoint(
      uid: '11111111-1111-4111-8111-111111111111',
      name: 'Kuyu',
      position: const LatLng(37.0662, 37.3832),
      createdAt: DateTime.utc(2026),
      note: 'Temiz su',
    );

    test('sade nokta → kırmızı spot marker', () {
      final e = mapper.fromWaypoint(spot);
      expect(e.type, 'b-m-p-s-m');
      expect(e.how, 'h-g-i-g-o');
      expect(e.stale, now.add(const Duration(days: 365)));
      expect(e.child('color')!.getAttribute('argb'), '-65536');
      expect(e.child('contact')!.getAttribute('callsign'), 'Kuyu');
      expect(e.child('remarks')!.innerText, 'Temiz su');
      expect(e.child('archive'), isNotNull);
      final link = e.children('link').single;
      expect(link.getAttribute('relation'), 'p-p');
      expect(link.getAttribute('uid'), 'PUSULA-test');
      expect(link.getAttribute('parent_callsign'), 'KURT-1');
    });

    test('gidiş-dönüş: ad, konum, not, uid korunur', () {
      final back = roundTrip(spot) as Waypoint;
      expect(back.uid, spot.uid);
      expect(back.name, 'Kuyu');
      expect(back.position, spot.position);
      expect(back.note, 'Temiz su');
      expect(back.affiliation, Affiliation.waypoint);
      expect(back.typeCode, isNull);
      expect(back.hae, isNull);
    });

    test('NATO sembolü: tip, kademe ve yükseklik korunur', () {
      final unit = Waypoint(
        uid: '22222222-2222-4222-8222-222222222222',
        name: '1. Manga',
        position: const LatLng(37.07, 37.39),
        createdAt: DateTime.utc(2026),
        affiliation: Affiliation.friend,
        echelon: Echelon.squad,
        role: SymbolRole.infantry,
        hae: 884.2,
      );
      final e = mapper.fromWaypoint(unit);
      expect(e.type, 'a-f-G-U-C-I');
      expect(e.hae, 884.2);
      expect(
        e.child('usericon')!.getAttribute('iconsetpath'),
        'COT_MAPPING_2525B/a-f/a-f-G-U-C-I',
      );
      expect(e.child('__milsym')!.getAttribute('id'), 'SFGPUCI----B---');
      final back = roundTrip(unit) as Waypoint;
      expect(back.affiliation, Affiliation.friend);
      expect(back.role, SymbolRole.infantry);
      expect(back.echelon, Echelon.squad);
      expect(back.hae, 884.2);
      expect(back.typeCode, isNull);
    });

    test('ATAK\'tan gelen ayrıntılı tip korunur, sembol en yakını', () {
      final atak = Waypoint(
        uid: 'x',
        name: 'Zırhlı tekerlekli',
        position: const LatLng(37, 37),
        createdAt: DateTime.utc(2026),
        affiliation: Affiliation.hostile,
        role: SymbolRole.armor,
        typeCode: 'a-h-G-U-C-A-W',
      );
      final back = roundTrip(atak) as Waypoint;
      expect(back.cotType, 'a-h-G-U-C-A-W');
      expect(back.typeCode, 'a-h-G-U-C-A-W');
      expect(back.role, SymbolRole.armor);
    });

    test('görev noktası: mor spot marker, Pusula\'ya türüyle döner', () {
      for (final a in Affiliation.values.where((a) => a.isMission)) {
        final gn = Waypoint(
          uid: 'gn-${a.name}',
          name: 'GN-1',
          position: const LatLng(37, 37),
          createdAt: DateTime.utc(2026),
          affiliation: a,
        );
        final e = mapper.fromWaypoint(gn);
        expect(e.type, 'b-m-p-s-m', reason: a.name);
        final purple = '${CotMapper.toSigned(CotMapper.missionColor)}';
        expect(e.child('color')!.getAttribute('argb'), purple);
        expect(
          e.child('usericon')!.getAttribute('iconsetpath'),
          'COT_MAPPING_SPOTMAP/b-m-p-s-m/$purple',
        );
        expect(e.child('__pusula')!.getAttribute('kind'), a.name);
        final back = roundTrip(gn) as Waypoint;
        expect(back.affiliation, a);
        expect(back.typeCode, isNull);
        expect(back.name, 'GN-1');
      }
      // Sade noktada Pusula ayrıntısı yok.
      expect(mapper.fromWaypoint(spot).child('__pusula'), isNull);
    });

    test('tür ayrıntısı yalnız spot marker\'da geçerli', () {
      // Biri NATO sembolüne yanlışlıkla eklese de sembol bozulmaz.
      final e = mapper.fromWaypoint(
        Waypoint(
          uid: 'h',
          name: 'D',
          position: const LatLng(37, 37),
          createdAt: DateTime.utc(2026),
          affiliation: Affiliation.hostile,
        ),
      );
      e.detail.children.add(
        XmlElement(XmlName('__pusula'), [
          XmlAttribute(XmlName('kind'), 'sensor'),
        ]),
      );
      expect((mapper.toItem(e) as Waypoint).affiliation, Affiliation.hostile);
    });

    test('şüpheli / varsayılan dost ve tehlike ikonları gidip döner', () {
      for (final (a, r, type) in [
        (Affiliation.suspect, SymbolRole.infantry, 'a-s-G-U-C-I'),
        (Affiliation.assumedFriend, SymbolRole.none, 'a-a-G'),
        (Affiliation.hostile, SymbolRole.mine, 'a-h-G-E-X-M'),
        (Affiliation.unknown, SymbolRole.cbrn, 'a-u-G-E-X-N'),
        (Affiliation.neutral, SymbolRole.barrier, 'a-n-G-I-c-bar'),
      ]) {
        final w = Waypoint(
          uid: type,
          name: 'T',
          position: const LatLng(37, 37),
          createdAt: DateTime.utc(2026),
          affiliation: a,
          role: r,
        );
        final e = mapper.fromWaypoint(w);
        expect(e.type, type);
        expect(
          e.child('usericon')!.getAttribute('iconsetpath'),
          'COT_MAPPING_2525B/${type.substring(0, 3)}/$type',
        );
        final back = roundTrip(w) as Waypoint;
        expect((back.affiliation, back.role, back.typeCode), (a, r, null));
      }
    });
  });

  group('grafik', () {
    const tri = [
      LatLng(37.06, 37.38),
      LatLng(37.07, 37.38),
      LatLng(37.07, 37.39),
    ];

    test('alan: kapalı serbest çizim, ilk nokta sonda tekrar, dolgulu', () {
      final area = MapGraphic(
        uid: 'g1',
        name: 'Bölge A',
        type: GraphicType.area,
        points: tri,
        colorValue: 0xFFE03131,
        createdAt: DateTime.utc(2026),
      );
      final e = mapper.fromGraphic(area);
      expect(e.type, 'u-d-f');
      final links = e
          .children('link')
          .where((l) => l.getAttribute('point') != null)
          .toList();
      expect(links, hasLength(4));
      expect(
        links.first.getAttribute('point'),
        links.last.getAttribute('point'),
      );
      expect(
        e.child('strokeColor')!.getAttribute('value'),
        '${CotMapper.toSigned(0xFFE03131)}',
      );
      expect(e.child('fillColor')!.getAttribute('value'), isNot('0'));

      final back = roundTrip(area) as MapGraphic;
      expect(back.type, GraphicType.area);
      expect(back.points, tri);
      expect(back.colorValue, 0xFFE03131);
      expect(back.uid, 'g1');
    });

    test('çizgi: açık kalır', () {
      final line = MapGraphic(
        uid: 'g2',
        name: 'Sınır',
        type: GraphicType.line,
        points: const [LatLng(37.06, 37.38), LatLng(37.07, 37.39)],
        colorValue: 0xFF1971C2,
        createdAt: DateTime.utc(2026),
      );
      final back = roundTrip(line) as MapGraphic;
      expect(back.type, GraphicType.line);
      expect(back.points, hasLength(2));
    });
  });

  group('rota', () {
    final route = RoutePlan(
      uid: 'r1',
      name: 'Devriye',
      points: const [
        LatLng(37.06, 37.38),
        LatLng(37.065, 37.385),
        LatLng(37.07, 37.39),
      ],
      createdAt: DateTime.utc(2026),
    );

    test('b-m-r + sıralı kontrol noktaları', () {
      final e = mapper.fromRoute(route);
      expect(e.type, 'b-m-r');
      final cps = e
          .children('link')
          .where((l) => l.getAttribute('relation') == 'c')
          .toList();
      expect(cps.map((l) => l.getAttribute('callsign')), [
        'Devriye SP',
        'CP1',
        'CP2',
      ]);
      expect(cps.map((l) => l.getAttribute('uid')), ['r1.0', 'r1.1', 'r1.2']);
      expect(cps.every((l) => l.getAttribute('type') == 'b-m-p-w'), isTrue);
      expect(e.child('link_attr')!.getAttribute('method'), 'Walking');
    });

    test('nokta adları gidip döner; varsayılan adlar ad sayılmaz', () {
      final named = RoutePlan(
        uid: 'r2',
        name: 'Devriye',
        points: route.points,
        pointNames: const [null, 'KÖPRÜ', null],
        createdAt: DateTime.utc(2026),
      );
      final cps = mapper
          .fromRoute(named)
          .children('link')
          .where((l) => l.getAttribute('relation') == 'c')
          .map((l) => l.getAttribute('callsign'));
      expect(cps, ['Devriye SP', 'KÖPRÜ', 'CP2']);
      final back = roundTrip(named) as RoutePlan;
      expect(back.pointNames, [null, 'KÖPRÜ', null]);
      expect(back.nameOf(0), 'BAŞLANGIÇ');
      expect(back.nameOf(1), 'KÖPRÜ');
      // Adsız rota adsız döner.
      expect((roundTrip(route) as RoutePlan).pointNames, isEmpty);
    });

    test('gidiş-dönüş: sıra ve ad korunur', () {
      final back = roundTrip(route) as RoutePlan;
      expect(back.uid, 'r1');
      expect(back.name, 'Devriye');
      expect(back.points, route.points);
    });
  });

  group('okuma', () {
    test('desteklenmeyen tip (konum yayını, sohbet) → null', () {
      for (final type in ['b-t-f', 't-x-d-d', 'u-r-b-c-c']) {
        final xml =
            "<event uid='x' type='$type' time='2026-01-01T00:00:00Z'>"
            "<point lat='1' lon='1'/><detail/></event>";
        expect(mapper.toItem(CotXml.decode(xml)), isNull, reason: type);
      }
    });

    test('adı olmayan nesne uid ile adlandırılır, uzun ad kısaltılır', () {
      var e = CotXml.decode(
        "<event uid='adsiz-1' type='a-u-G' "
        "time='2026-01-01T00:00:00Z'><point lat='1' lon='1'/></event>",
      );
      expect((mapper.toItem(e)! as Waypoint).name, 'adsiz-1');
      final long = 'A' * 200;
      e = CotXml.decode(
        "<event uid='u' type='a-u-G' time='2026-01-01T00:00:00Z'>"
        "<point lat='1' lon='1'/><detail><contact callsign='$long'/></detail></event>",
      );
      expect((mapper.toItem(e)! as Waypoint).name, hasLength(80));
    });

    test('bozuk noktalı çizim/rota atlanır', () {
      final e = CotXml.decode(
        "<event uid='u' type='u-d-f' time='2026-01-01T00:00:00Z'>"
        "<point lat='1' lon='1'/><detail><link point='çöp'/>"
        "<link point='1,1'/></detail></event>",
      );
      expect(mapper.toItem(e), isNull); // tek geçerli nokta → çizim olmaz
    });
  });

  group('ATAK örnekleriyle aynı yapı (takcot/examples, 2026-11-06)', () {
    // ATAK'ın örnek dosyalarındaki <detail> öğe sırası (tekrarlar tek).
    List<String> tags(CotEvent e) {
      final out = <String>[];
      for (final c in e.detail.childElements) {
        final t = c.name.local;
        if (out.isEmpty || out.last != t) out.add(t);
      }
      return out;
    }

    test('işaretçi (spot)', () {
      final e = mapper.fromWaypoint(
        Waypoint(
          uid: 'a',
          name: 'n',
          position: const LatLng(1, 1),
          createdAt: DateTime.utc(2026),
        ),
      );
      expect(tags(e), [
        'status', 'archive', 'link', 'contact', 'remarks', 'color',
        'precisionlocation', 'usericon', //
      ]);
    });

    test('serbest çizim (alan)', () {
      final e = mapper.fromGraphic(
        MapGraphic(
          uid: 'g',
          name: 'n',
          type: GraphicType.area,
          points: const [LatLng(1, 1), LatLng(1, 2), LatLng(2, 2)],
          colorValue: 0xFFFF0000,
          createdAt: DateTime.utc(2026),
        ),
      );
      expect(tags(e), [
        'link', 'strokeColor', 'strokeWeight', 'fillColor', 'contact',
        'remarks', 'archive', 'labels_on', 'color', 'precisionlocation', //
      ]);
    });

    test('rota', () {
      final e = mapper.fromRoute(
        RoutePlan(
          uid: 'r',
          name: 'n',
          points: const [LatLng(1, 1), LatLng(1, 2)],
          createdAt: DateTime.utc(2026),
        ),
      );
      expect(tags(e), [
        'link', 'link_attr', 'strokeColor', 'strokeWeight', '__routeinfo',
        'contact', 'remarks', 'archive', 'labels_on', 'color', //
      ]);
    });

    test('olay zamanı ile oluşturucu bağlantısı aynı an', () {
      final e = mapper.fromWaypoint(
        Waypoint(
          uid: 'a',
          name: 'n',
          position: const LatLng(1, 1),
          createdAt: DateTime.utc(2026),
        ),
      );
      expect(
        e.children('link').single.getAttribute('production_time'),
        CotXml.formatTime(e.time),
      );
    });
  });

  test('SIDC: kademe 12. karakterde, 15 karakter', () {
    Waypoint w(Affiliation a, Echelon e, SymbolRole r) => Waypoint(
      uid: 'x',
      name: 'x',
      position: const LatLng(0, 0),
      createdAt: DateTime.utc(2026),
      affiliation: a,
      echelon: e,
      role: r,
    );
    expect(
      CotMapper.sidc(w(Affiliation.hostile, Echelon.company, SymbolRole.armor)),
      'SHGPUCA----E---',
    );
    expect(
      CotMapper.sidc(w(Affiliation.neutral, Echelon.team, SymbolRole.none)),
      'SNGPU------A---',
    );
    // Kademe yoksa ya da sade noktada SIDC üretilmez.
    expect(
      CotMapper.sidc(w(Affiliation.friend, Echelon.none, SymbolRole.infantry)),
      isNull,
    );
    expect(
      CotMapper.sidc(w(Affiliation.waypoint, Echelon.squad, SymbolRole.none)),
      isNull,
    );
    // Yeni kimlikler (2525C: A varsayılan dost, S şüpheli).
    expect(
      CotMapper.sidc(
        w(Affiliation.suspect, Echelon.squad, SymbolRole.infantry),
      ),
      'SSGPUCI----B---',
    );
    expect(
      CotMapper.sidc(
        w(Affiliation.assumedFriend, Echelon.team, SymbolRole.none),
      ),
      'SAGPU------A---',
    );
    // Tehlike ikonunda kademe anlamsız → SIDC yok; görev noktasında da.
    expect(
      CotMapper.sidc(w(Affiliation.hostile, Echelon.squad, SymbolRole.mine)),
      isNull,
    );
    expect(
      CotMapper.sidc(w(Affiliation.sensor, Echelon.squad, SymbolRole.none)),
      isNull,
    );
    for (final e in Echelon.values) {
      final id = CotMapper.sidc(w(Affiliation.friend, e, SymbolRole.recon));
      if (id == null) continue;
      expect(id, hasLength(15));
      expect(CotMapper.echelonFromSidc(id), e);
    }
    expect(CotMapper.echelonFromSidc('kısa'), Echelon.none);
    expect(CotMapper.echelonFromSidc(null), Echelon.none);
  });

  test('renk dönüşümü (Java işaretli int ↔ ARGB)', () {
    expect(CotMapper.toSigned(0xFFFF0000), -65536);
    expect(CotMapper.toSigned(0xFFFFFFFF), -1);
    expect(CotMapper.toSigned(0x00FF0000), 16711680);
    expect(CotMapper.toUnsigned(-65536), 0xFFFF0000);
    expect(CotMapper.toUnsigned(CotMapper.toSigned(0x60123456)), 0x60123456);
  });
}
