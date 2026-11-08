import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

import '../../domain/models/cot_type.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/map_item.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/waypoint.dart';
import 'cot_event.dart';
import 'cot_xml.dart';

/// Pusula nesneleri ↔ CoT olayları.
///
/// Biçim ATAK-CIV'in `takcot/examples` örneklerine göre (yalnızca protokol
/// bilgisi; kod alınmadı): işaretçi `b-m-p-s-m` / 2525 `a-…`, serbest çizim
/// `u-d-f` (+ `<link point>`), rota `b-m-r` (+ `<link … relation='c'>`).
class CotMapper {
  CotMapper({this.creatorUid, this.creatorCallsign, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Nesneyi oluşturan cihazın CoT uid'i ve callsign'ı (`<link relation='p-p'>`).
  final String? creatorUid;
  final String? creatorCallsign;
  final DateTime Function() _clock;

  /// Paylaşılan kalıcı nesnelerin geçerlilik süresi (`<archive/>` ile birlikte).
  static const staleAfter = Duration(days: 365);

  /// Sade işaretçi rengi (Pusula'daki kırmızı iğne).
  static const spotColor = 0xFFFF0000;

  /// Görev noktası işaretçi rengi (Pusula'daki mor rozet, `missionColor`
  /// `features/symbols/nato_symbol.dart`).
  static const missionColor = 0xFFB04CFF;

  /// Pusula'ya özgü ayrıntı: görev noktasının türü (`<__pusula kind=…/>`).
  /// ATAK tanımadığı ayrıntıyı yok sayar; Pusula'dan Pusula'ya paylaşımda
  /// gözetleme / kontrol / toplanma / sensör türü kaybolmaz.
  static const pusulaTag = '__pusula';

  // ------------------------------------------------------------- yazma

  CotEvent toEvent(MapItem item) => switch (item) {
    Waypoint w => fromWaypoint(w),
    MapGraphic g => fromGraphic(g),
    RoutePlan r => fromRoute(r),
    _ => throw ArgumentError('Desteklenmeyen nesne: ${item.runtimeType}'),
  };

  CotEvent fromWaypoint(Waypoint w) {
    final now = _now();
    final type = w.cotType;
    final spot = type == CotType.spotMarker;
    final mission = w.affiliation.isMission;
    final color = mission ? missionColor : spotColor;
    final d = _detail([
      _el('status', {'readiness': 'true'}),
      _el('archive'),
      ?_creatorLink(now),
      _el('contact', {'callsign': w.name}),
      _text('remarks', w.note ?? ''),
      _el('color', {'argb': '${toSigned(spot ? color : 0xFFFFFFFF)}'}),
      _el('precisionlocation', {'altsrc': '???'}),
      _el('usericon', {
        'iconsetpath': spot
            ? 'COT_MAPPING_SPOTMAP/$type/${toSigned(color)}'
            : 'COT_MAPPING_2525B/${_prefix2(type)}/$type',
      }),
      // Birlik büyüklüğü CoT tipinde yok → TAK'ın 2525 sembol kimliği (SIDC).
      if (sidc(w) case final id?) _el('__milsym', {'id': id}),
      if (mission) _el(pusulaTag, {'kind': w.affiliation.name}),
    ]);
    return _event(
      now: now,
      uid: w.uid,
      type: type,
      how: 'h-g-i-g-o',
      at: w.position,
      hae: w.hae ?? CotEvent.unknown,
      detail: d,
    );
  }

  CotEvent fromGraphic(MapGraphic g) {
    final closed = g.type == GraphicType.area;
    final pts = [
      ...g.points,
      if (closed && g.points.isNotEmpty) g.points.first,
    ];
    final d = _detail([
      for (final p in pts)
        _el('link', {'point': '${p.latitude},${p.longitude}'}),
      _el('strokeColor', {'value': '${toSigned(g.colorValue)}'}),
      _el('strokeWeight', {'value': '3.0'}),
      // Alan yarı saydam dolgulu (Pusula çiziminde de öyle), çizgi dolgusuz.
      _el('fillColor', {
        'value':
            '${toSigned(closed ? (g.colorValue & 0x00FFFFFF) | 0x60000000 : 0)}',
      }),
      _el('contact', {'callsign': g.name}),
      _text('remarks', ''),
      _el('archive'),
      _el('labels_on', {'value': 'false'}),
      _el('color', {'value': '${toSigned(g.colorValue)}'}),
      _el('precisionlocation', {'altsrc': '???'}),
    ]);
    return _event(
      now: _now(),
      uid: g.uid,
      type: CotType.freeform,
      how: 'h-e',
      at: _centroid(g.points),
      detail: d,
    );
  }

  CotEvent fromRoute(RoutePlan r) {
    String cpName(int i) => i == 0 ? '${r.name} SP' : 'CP$i';
    final d = _detail([
      for (var i = 0; i < r.points.length; i++)
        _el('link', {
          // Nokta uid'leri rota uid'inden türetilir: aynı rota tekrar
          // paylaşılınca noktaları da aynı kimliği taşır.
          'uid': '${r.uid}.$i',
          'callsign': cpName(i),
          'type': CotType.routeWaypoint,
          'point': '${r.points[i].latitude},${r.points[i].longitude}',
          'remarks': '',
          'relation': 'c',
        }),
      _el('link_attr', {
        'planningmethod': 'Infil',
        'color': '${toSigned(0xFFFFFFFF)}',
        'method': 'Walking',
        'prefix': 'CP',
        'type': 'On Foot',
        'stroke': '3',
        'direction': 'Infil',
        'routetype': 'Primary',
        'order': 'Ascending Check Points',
      }),
      _el('strokeColor', {'value': '${toSigned(0xFFFFFFFF)}'}),
      _el('strokeWeight', {'value': '3.0'}),
      XmlElement(XmlName('__routeinfo'), [], [
        XmlElement(XmlName('__navcues')),
      ]),
      _el('contact', {'callsign': r.name}),
      _text('remarks', ''),
      _el('archive'),
      _el('labels_on', {'value': 'false'}),
      _el('color', {'value': '${toSigned(0xFFFFFFFF)}'}),
    ]);
    return _event(
      now: _now(),
      uid: r.uid,
      type: CotType.route,
      how: 'h-e',
      at: r.points.isEmpty ? const LatLng(0, 0) : r.points.first,
      detail: d,
    );
  }

  // ------------------------------------------------------------- okuma

  /// Gelen olay → Pusula nesnesi. Desteklenmeyen tipte (sohbet, konum
  /// yayını, video…) null. Veritabanı id'si yoktur; [MapItem.uid] korunur.
  MapItem? toItem(CotEvent e) {
    final name = _callsign(e);
    if (e.type == CotType.route) {
      final pts = [
        for (final l in e.children('link'))
          if (l.getAttribute('relation') == 'c') ?_parsePoint(l),
      ];
      if (pts.length < 2) return null;
      return RoutePlan(uid: e.uid, name: name, points: pts, createdAt: e.time);
    }
    if (e.type == CotType.freeform) {
      final pts = [for (final l in e.children('link')) ?_parsePoint(l)];
      if (pts.length < 2) return null;
      final closed = pts.length >= 4 && pts.first == pts.last;
      return MapGraphic(
        uid: e.uid,
        name: name,
        type: closed ? GraphicType.area : GraphicType.line,
        points: closed ? pts.sublist(0, pts.length - 1) : pts,
        colorValue: toUnsigned(
          int.tryParse(e.child('strokeColor')?.getAttribute('value') ?? '') ??
              toSigned(0xFFFFFFFF),
        ),
        createdAt: e.time,
      );
    }
    if (CotType.isAtom(e.type) || e.type.startsWith('b-m-p-')) {
      final sym = CotType.parse(e.type);
      // Pusula'dan gelen görev noktası (sade işaretçi + tür ayrıntısı).
      final kind = Affiliation.fromName(
        e.child(pusulaTag)?.getAttribute('kind'),
      );
      final affiliation = e.type == CotType.spotMarker && kind.isMission
          ? kind
          : sym.affiliation;
      final derived = CotType.forSymbol(affiliation, sym.role);
      final remarks = e.child('remarks')?.innerText.trim() ?? '';
      return Waypoint(
        uid: e.uid,
        name: name,
        position: LatLng(e.lat, e.lon),
        createdAt: e.time,
        note: remarks.isEmpty ? null : remarks,
        affiliation: affiliation,
        role: sym.role,
        echelon: echelonFromSidc(e.child('__milsym')?.getAttribute('id')),
        // Sembolümüze tam oturmayan tip (ör. a-h-G-U-C-A-W, b-m-p-w) korunur.
        typeCode: e.type == derived ? null : e.type,
        hae: e.knownHae,
      );
    }
    return null;
  }

  // ------------------------------------------------------------- 2525C SIDC

  // 2525C kademe kodu (SIDC 12. karakter).
  static const _echelonCode = {
    Echelon.team: 'A',
    Echelon.squad: 'B',
    Echelon.company: 'E',
    Echelon.battalion: 'F',
  };

  // 2525C kimlik kodu (SIDC 2. karakter).
  static const _affiliationCode = {
    Affiliation.friend: 'F',
    Affiliation.assumedFriend: 'A',
    Affiliation.hostile: 'H',
    Affiliation.suspect: 'S',
    Affiliation.neutral: 'N',
    Affiliation.unknown: 'U',
  };

  static const _functionCode = {
    SymbolRole.infantry: 'UCI---',
    SymbolRole.armor: 'UCA---',
    SymbolRole.artillery: 'UCF---',
    SymbolRole.recon: 'UCR---',
  };

  /// Kademeli NATO sembolü için 15 karakterlik 2525C SIDC, ör. dost piyade
  /// manga → `SFGPUCI----B---`. Kademe yoksa ya da sade noktada null.
  static String? sidc(Waypoint w) {
    final e = _echelonCode[w.echelon];
    final a = _affiliationCode[w.affiliation];
    if (e == null || a == null) return null;
    // Kademe yalnız birliklerde anlamlı; tehlike ikonlarında SIDC yazılmaz.
    if (w.role.isHazard) return null;
    final fn = _functionCode[w.role] ?? 'U-----';
    return 'S${a}GP$fn-$e---';
  }

  /// SIDC'nin 12. karakterinden kademe; tanınmazsa yok.
  static Echelon echelonFromSidc(String? id) {
    if (id == null || id.length < 12) return Echelon.none;
    final c = id[11].toUpperCase();
    for (final e in _echelonCode.entries) {
      if (e.value == c) return e.key;
    }
    return Echelon.none;
  }

  // ------------------------------------------------------------- yardımcılar

  /// Java'nın işaretli 32 bit renk değeri (ATAK) ↔ Flutter ARGB.
  static int toSigned(int argb) {
    final v = argb & 0xFFFFFFFF;
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  static int toUnsigned(int signed) => signed & 0xFFFFFFFF;

  DateTime _now() => _clock().toUtc();

  CotEvent _event({
    required DateTime now,
    required String uid,
    required String type,
    required String how,
    required LatLng at,
    double hae = CotEvent.unknown,
    required XmlElement detail,
  }) {
    return CotEvent(
      uid: uid,
      type: type,
      how: how,
      time: now,
      start: now,
      stale: now.add(staleAfter),
      lat: at.latitude,
      lon: at.longitude,
      hae: hae,
      detail: detail,
    );
  }

  /// İşaretçiyi oluşturan cihaz (ATAK örneklerinde yalnızca işaretçilerde).
  XmlElement? _creatorLink(DateTime now) => creatorUid == null
      ? null
      : _el('link', {
          'uid': creatorUid!,
          'production_time': CotXml.formatTime(now),
          'type': 'a-f-G-U-C',
          'parent_callsign': creatorCallsign ?? '',
          'relation': 'p-p',
        });

  static XmlElement _detail(List<XmlElement> children) =>
      XmlElement(XmlName('detail'), [], children);

  static XmlElement _el(String name, [Map<String, String> attrs = const {}]) =>
      XmlElement(XmlName(name), [
        for (final e in attrs.entries) XmlAttribute(XmlName(e.key), e.value),
      ]);

  static XmlElement _text(String name, String text) =>
      XmlElement(XmlName(name), [], [if (text.isNotEmpty) XmlText(text)]);

  /// `a-h-G-U-C` → `a-h` (ATAK 2525 ikon yolu).
  static String _prefix2(String type) => type.split('-').take(2).join('-');

  static String _callsign(CotEvent e) {
    final c = e.child('contact')?.getAttribute('callsign')?.trim();
    if (c == null || c.isEmpty) return e.uid;
    // Veritabanında ad en fazla 80 karakter.
    return c.length > 80 ? c.substring(0, 80) : c;
  }

  static LatLng? _parsePoint(XmlElement link) {
    final raw = link.getAttribute('point');
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return LatLng(lat, lon);
  }

  static LatLng _centroid(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(0, 0);
    var lat = 0.0, lon = 0.0;
    for (final p in pts) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / pts.length, lon / pts.length);
  }
}
