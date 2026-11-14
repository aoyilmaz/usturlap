import 'package:xml/xml.dart';

/// CoT (Cursor on Target) olayı — ATAK'ın temel mesajı.
///
/// `<event uid type how time start stale><point …/><detail>…</detail></event>`.
/// [detail] ham XML olarak tutulur: Usturlap'ın tanımadığı alt öğeler
/// kaybolmaz (ATAK'tan gelip geri giden nesnede bilgi düşmesin).
class CotEvent {
  CotEvent({
    required this.uid,
    required this.type,
    required this.how,
    required this.time,
    required this.start,
    required this.stale,
    required this.lat,
    required this.lon,
    this.hae = unknown,
    this.ce = unknown,
    this.le = unknown,
    XmlElement? detail,
  }) : detail = detail ?? XmlElement(XmlName('detail'));

  /// CoT'de "bilinmiyor" değeri (yükseklik ve hata yarıçapları için).
  static const double unknown = 9999999.0;

  final String uid;
  final String type;

  /// Nasıl üretildi: `h-e` elle girildi, `h-g-i-g-o` haritadan seçildi,
  /// `m-g` GPS ile ölçüldü…
  final String how;

  final DateTime time, start, stale;
  final double lat, lon;

  /// Elipsoit üstü yükseklik (m), dairesel ve doğrusal hata (m).
  final double hae, ce, le;

  final XmlElement detail;

  /// Yükseklik biliniyorsa değeri, değilse null.
  double? get knownHae => hae >= unknown ? null : hae;

  /// `<detail>` içinde [name] adlı ilk öğe.
  XmlElement? child(String name) => detail.getElement(name);

  /// `<detail>` içinde [name] adlı bütün öğeler (sırasıyla).
  Iterable<XmlElement> children(String name) => detail.findElements(name);
}
