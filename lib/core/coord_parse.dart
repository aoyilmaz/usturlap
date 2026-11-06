import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

/// Kullanıcının yazdığı koordinatı çözümler (saf Dart, test edilir).
///
/// Desteklenen biçimler:
/// - **MGRS**: `37S DB 12345 67890`, `37SDB1234567890`, düşük hassasiyet
///   (`37S DB 123 678`) → hücrenin merkezi.
/// - **UTM**: `37S 480390 4383718`, `37N 480390E 4383718N`. Harf **bant**
///   harfidir (C–M güney, N–X kuzey yarımküre).
/// - **Ondalık derece**: `39.6029, 26.7715`, `39.6029N 26.7715E`,
///   Türkçe yönlerle `39.6029K 26.7715D` (K/G/D/B).
/// - **Derece-dakika-saniye**: `39°36'10.5"N 26°46'17"E`, `39 36 10.5 K 26 46 17 D`.
class CoordParse {
  CoordParse._();

  /// Biçimi kendisi tanır. Çözülemezse null.
  static LatLng? parse(String input) {
    final s = _normalize(input);
    if (s.isEmpty) return null;
    return mgrs(s) ?? utm(s) ?? decimal(s) ?? dms(s);
  }

  static String _normalize(String s) => s
      .trim()
      .toUpperCase()
      .replaceAll('’', "'")
      .replaceAll('′', "'")
      .replaceAll('″', '"')
      .replaceAll('”', '"')
      .replaceAll(RegExp(r'\s+'), ' ');

  static final _mgrsRe = RegExp(r'^(\d{1,2})([C-HJ-NP-X])([A-HJ-NP-Z]{2})(\d*)$');

  /// MGRS → hücre merkezi. Rakam sayısı çift olmalı (doğu = kuzey uzunluğu).
  static LatLng? mgrs(String input) {
    final compact = _normalize(input).replaceAll(' ', '');
    final m = _mgrsRe.firstMatch(compact);
    if (m == null) return null;
    final digits = m.group(4)!;
    if (digits.length.isOdd || digits.length > 10) return null;
    final zone = int.parse(m.group(1)!);
    if (zone < 1 || zone > 60) return null;
    try {
      // Hücrenin güneybatı köşesi (UTM) + yarım hücre = merkez.
      // (mgrs_dart'ın inverse() fonksiyonu düşük hassasiyette yanlış sonuç
      // veriyor — ~40 km sapma — bu yüzden merkezi kendimiz hesaplıyoruz.)
      final u = Mgrs.decode(compact);
      final half = (u.accuracy ?? 0) / 2;
      final r = Mgrs.UTMtoLL(UTM(
        easting: u.easting + half,
        northing: u.northing + half,
        zoneLetter: u.zoneLetter,
        zoneNumber: u.zoneNumber,
      ));
      if (r is! LonLat) return null;
      final p = LatLng(r.lat, r.lon);
      return _valid(p) ? p : null;
    } catch (_) {
      return null;
    }
  }

  /// MGRS'i parçalardan kurar (Koordinat ekranındaki ayrı alanlar için).
  /// [easting] ve [northing] aynı uzunlukta olmalı (1–5 hane).
  static LatLng? mgrsParts({
    required String gzd,
    required String square,
    required String easting,
    required String northing,
  }) {
    final e = easting.trim(), n = northing.trim();
    if (e.isEmpty || e.length != n.length) return null;
    return mgrs('${gzd.trim()}${square.trim()}$e$n');
  }

  static final _utmRe = RegExp(
      r'^(\d{1,2}) ?([C-HJ-NP-X])[ ,]+(\d{5,7}(?:\.\d+)?) ?E?[ ,]+(\d{6,8}(?:\.\d+)?) ?N?$');

  static LatLng? utm(String input) {
    final m = _utmRe.firstMatch(_normalize(input));
    if (m == null) return null;
    return utmParts(
      zone: int.parse(m.group(1)!),
      band: m.group(2)!,
      easting: double.parse(m.group(3)!),
      northing: double.parse(m.group(4)!),
    );
  }

  static LatLng? utmParts({
    required int zone,
    required String band,
    required double easting,
    required double northing,
  }) {
    if (zone < 1 || zone > 60) return null;
    if (easting < 100000 || easting > 900000) return null;
    if (northing < 0 || northing > 10000000) return null;
    try {
      final r = Mgrs.UTMtoLL(UTM(
        easting: easting,
        northing: northing,
        zoneLetter: band.toUpperCase(),
        zoneNumber: zone,
      ));
      if (r is LonLat) {
        final p = LatLng(r.lat, r.lon);
        return _valid(p) ? p : null;
      }
    } catch (_) {}
    return null;
  }

  // Bir eksen: sayı + isteğe bağlı derece işareti + isteğe bağlı yön harfi.
  static const _num = r'([+-]?\d{1,3}(?:[.,]\d+)?)';
  static final _decRe = RegExp('^$_num ?°? ?([NSKG])?[ ,;/]+$_num ?°? ?([EWDB])?\$');

  static LatLng? decimal(String input) {
    final s = _normalize(input);
    final m = _decRe.firstMatch(s);
    if (m == null) return null;
    var lat = double.parse(m.group(1)!.replaceAll(',', '.'));
    var lon = double.parse(m.group(3)!.replaceAll(',', '.'));
    if (_south(m.group(2))) lat = -lat.abs();
    if (_west(m.group(4))) lon = -lon.abs();
    final p = LatLng(lat, lon);
    return _valid(p) ? p : null;
  }

  // Bir eksen: derece [°/boşluk] dakika ['] [saniye ["]] — dakika ondalıklı
  // olabilir (39°36.175'), saniye isteğe bağlı.
  static const _axis =
      r"""(\d{1,3}) ?[° ] ?(\d{1,2}(?:[.,]\d+)?)'? ?(?:(\d{1,2}(?:[.,]\d+)?) ?"?)? ?""";
  static final _dmsRe = RegExp('^$_axis([NSKG])[ ,;]*$_axis([EWDB])\$');

  /// Derece-dakika-saniye: `39°36'10.5"N 26°46'17"E`, `39 36 10.5 K 26 46 17 D`.
  static LatLng? dms(String input) {
    final m = _dmsRe.firstMatch(_normalize(input));
    if (m == null) return null;
    double axis(int d, int mi, int se) {
      final deg = double.parse(m.group(d)!);
      final min = double.parse(m.group(mi)!.replaceAll(',', '.'));
      final sec = double.parse((m.group(se) ?? '0').replaceAll(',', '.'));
      if (min >= 60 || sec >= 60) return double.nan;
      return deg + min / 60 + sec / 3600;
    }

    var lat = axis(1, 2, 3);
    var lon = axis(5, 6, 7);
    if (lat.isNaN || lon.isNaN) return null;
    if (_south(m.group(4))) lat = -lat;
    if (_west(m.group(8))) lon = -lon;
    final p = LatLng(lat, lon);
    return _valid(p) ? p : null;
  }

  static bool _south(String? h) => h == 'S' || h == 'G';
  static bool _west(String? h) => h == 'W' || h == 'B';

  static bool _valid(LatLng p) =>
      p.latitude.abs() <= 90 && p.longitude.abs() <= 180;
}
