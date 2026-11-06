import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/cot/cot_event.dart';
import 'package:kerteriz/data/cot/cot_xml.dart';
import 'package:xml/xml.dart';

/// ATAK'ın yazdığı biçimde (tek tırnaklı, sekmeli) elle yazılmış örnek olay.
const _atakStyle = '''<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<event version='2.0' uid='e2b1c8a0-1111-4222-8333-944455556666' type='a-h-G' time='2026-11-06T10:00:00.123Z' start='2026-11-06T10:00:00.123Z' stale='2026-11-07T10:00:00.123Z' how='h-g-i-g-o'>
\t<point lat='37.0662' lon='37.3832' hae='9999999.0' ce='9999999.0' le='9999999.0' />
\t<detail>
\t\t<contact callsign='Gözetleme &amp; Hedef'/>
\t\t<remarks>Sırt hattında</remarks>
\t\t<bilinmeyen_eklenti deger='1'/>
\t</detail>
</event>''';

void main() {
  group('CotXml.decode', () {
    test('ATAK biçimindeki olayı okur', () {
      final e = CotXml.decode(_atakStyle);
      expect(e.uid, 'e2b1c8a0-1111-4222-8333-944455556666');
      expect(e.type, 'a-h-G');
      expect(e.how, 'h-g-i-g-o');
      expect(e.time, DateTime.utc(2026, 11, 6, 10, 0, 0, 123));
      expect(e.stale, DateTime.utc(2026, 11, 7, 10, 0, 0, 123));
      expect(e.lat, 37.0662);
      expect(e.lon, 37.3832);
      expect(e.knownHae, isNull);
      expect(e.child('contact')!.getAttribute('callsign'), 'Gözetleme & Hedef');
      expect(e.child('remarks')!.innerText, 'Sırt hattında');
    });

    test('tanımadığımız detay öğeleri kaybolmaz (gidiş-dönüş)', () {
      final back = CotXml.decode(CotXml.encode(CotXml.decode(_atakStyle)));
      expect(back.child('bilinmeyen_eklenti')!.getAttribute('deger'), '1');
      expect(back.uid, 'e2b1c8a0-1111-4222-8333-944455556666');
      expect(back.time, DateTime.utc(2026, 11, 6, 10, 0, 0, 123));
    });

    test('bozuk girdiler FormatException verir', () {
      final bad = <String>[
        '',
        'çöp',
        '<event/>', // point yok
        "<foo><point lat='1' lon='1'/></foo>", // kök event değil
        "<event uid='x' type='a-f-G' time='2026-01-01T00:00:00Z'></event>",
        "<event uid='x' type='a-f-G' time='dün'><point lat='1' lon='1'/></event>",
        "<event uid='x' type='a-f-G' time='2026-01-01T00:00:00Z'><point lat='91' lon='1'/></event>",
        "<event uid='x' type='a-f-G' time='2026-01-01T00:00:00Z'><point lat='NaN' lon='1'/></event>",
        "<event type='a-f-G' time='2026-01-01T00:00:00Z'><point lat='1' lon='1'/></event>",
        '<event uid="x"', // yarım
      ];
      for (final b in bad) {
        expect(() => CotXml.decode(b), throwsFormatException, reason: b);
      }
    });

    test('çok büyük girdi reddedilir', () {
      final huge = 'a' * (CotXml.maxInputLength + 1);
      expect(() => CotXml.decode(huge), throwsFormatException);
    });

    test('DTD varlıkları açılmaz (XML bombası etkisiz)', () {
      const bomb = '''<?xml version="1.0"?>
<!DOCTYPE event [<!ENTITY a "AAAAAAAAAA"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]>
<event uid='x' type='a-f-G' time='2026-01-01T00:00:00Z'><point lat='1' lon='1'/><detail><remarks>&b;</remarks></detail></event>''';
      // Ya reddedilir ya da varlık açılmadan okunur; asla büyümez.
      try {
        final e = CotXml.decode(bomb);
        expect(e.child('remarks')!.innerText.length, lessThan(100));
      } on FormatException {
        // kabul
      }
    });
  });

  group('CotXml.encode', () {
    test('ATAK başlığı ve zorunlu alanlar', () {
      final e = CotEvent(
        uid: 'u1',
        type: 'b-m-p-s-m',
        how: 'h-e',
        time: DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 789),
        start: DateTime.utc(2026, 1, 2, 3, 4, 5, 6),
        stale: DateTime.utc(2027, 1, 2),
        lat: 39.925,
        lon: 32.866,
        hae: 912.5,
      );
      final xml = CotXml.encode(e);
      expect(xml, startsWith("<?xml version='1.0' encoding='UTF-8'"));
      final doc = XmlDocument.parse(xml);
      final ev = doc.rootElement;
      expect(ev.getAttribute('version'), '2.0');
      // Mikrosaniye atılır, milisaniye kalır.
      expect(ev.getAttribute('time'), '2026-01-02T03:04:05.006Z');
      expect(ev.getAttribute('stale'), '2027-01-02T00:00:00.000Z');
      final p = ev.getElement('point')!;
      expect(p.getAttribute('hae'), '912.5');
      expect(p.getAttribute('ce'), '9999999.0');
      expect(ev.getElement('detail'), isNotNull);
    });

    test('yerel saat UTC\'ye çevrilir', () {
      final local = DateTime(2026, 6, 1, 12);
      expect(CotXml.formatTime(local), CotXml.formatTime(local.toUtc()));
      expect(CotXml.formatTime(local), endsWith('Z'));
    });
  });
}
