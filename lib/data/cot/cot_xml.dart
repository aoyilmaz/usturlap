import 'package:xml/xml.dart';

import 'cot_event.dart';

/// CoT XML okuma/yazma (saf Dart).
///
/// Güvenlik: girdi boyutu sınırlı; `package:xml` DTD varlıklarını açmaz
/// (XML bombası/dış varlık yok). Bozuk girdi hep [FormatException] verir.
class CotXml {
  CotXml._();

  /// Tek bir CoT olayı için üst sınır. Gerçek olaylar birkaç KB'dir.
  static const maxInputLength = 1 << 20; // 1 MB

  /// Olayı XML metnine çevirir (ATAK'ın yazdığı başlıkla).
  static String encode(CotEvent e) {
    final event = XmlElement(
      XmlName('event'),
      [
        XmlAttribute(XmlName('version'), '2.0'),
        XmlAttribute(XmlName('uid'), e.uid),
        XmlAttribute(XmlName('type'), e.type),
        XmlAttribute(XmlName('time'), formatTime(e.time)),
        XmlAttribute(XmlName('start'), formatTime(e.start)),
        XmlAttribute(XmlName('stale'), formatTime(e.stale)),
        XmlAttribute(XmlName('how'), e.how),
      ],
      [
        XmlElement(XmlName('point'), [
          XmlAttribute(XmlName('lat'), _num(e.lat)),
          XmlAttribute(XmlName('lon'), _num(e.lon)),
          XmlAttribute(XmlName('hae'), _num(e.hae)),
          XmlAttribute(XmlName('ce'), _num(e.ce)),
          XmlAttribute(XmlName('le'), _num(e.le)),
        ]),
        e.detail.copy(),
      ],
    );
    return "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n"
        '${event.toXmlString(pretty: true, indent: '  ')}\n';
  }

  /// XML metninden olay. Biçim bozuksa [FormatException].
  static CotEvent decode(String text) {
    if (text.length > maxInputLength) {
      throw const FormatException('CoT olayı çok büyük');
    }
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(text);
    } on XmlException catch (e) {
      throw FormatException('Geçersiz XML: ${e.message}');
    }
    final event = doc.rootElement;
    if (event.name.local != 'event') {
      throw const FormatException('Kök öğe <event> değil');
    }
    final point = event.getElement('point');
    if (point == null) throw const FormatException('<point> yok');

    String attr(XmlElement el, String name) {
      final v = el.getAttribute(name);
      if (v == null || v.isEmpty) {
        throw FormatException('<${el.name.local}> içinde "$name" yok');
      }
      return v;
    }

    double coord(String name, double limit) {
      final v = double.tryParse(attr(point, name));
      if (v == null || !v.isFinite || v.abs() > limit) {
        throw FormatException('Geçersiz $name');
      }
      return v;
    }

    double optional(String name) {
      final v = double.tryParse(point.getAttribute(name) ?? '');
      return (v == null || !v.isFinite) ? CotEvent.unknown : v;
    }

    final time = parseTime(attr(event, 'time'));
    return CotEvent(
      uid: attr(event, 'uid'),
      type: attr(event, 'type'),
      how: event.getAttribute('how') ?? 'h-e',
      time: time,
      start: _optTime(event.getAttribute('start')) ?? time,
      stale: _optTime(event.getAttribute('stale')) ?? time,
      lat: coord('lat', 90),
      lon: coord('lon', 180),
      hae: optional('hae'),
      ce: optional('ce'),
      le: optional('le'),
      detail: event.getElement('detail')?.copy(),
    );
  }

  /// UTC, milisaniye hassasiyetinde: `2020-12-16T19:59:34.913Z`.
  static String formatTime(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}'
        '.${u.millisecond.toString().padLeft(3, '0')}Z';
  }

  static DateTime parseTime(String s) {
    final t = DateTime.tryParse(s);
    if (t == null) throw FormatException('Geçersiz zaman: $s');
    return t.toUtc();
  }

  static DateTime? _optTime(String? s) =>
      s == null ? null : DateTime.tryParse(s)?.toUtc();

  /// Tam sayıları ATAK gibi ".0" ile yazar (9999999.0), diğerlerini tam
  /// hassasiyetle.
  static String _num(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toStringAsFixed(1);
    return v.toString();
  }
}
