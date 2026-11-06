import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

/// Kullanıcının seçebileceği koordinat gösterim biçimleri.
enum CoordFormatType {
  mgrs('MGRS'),
  utm('UTM'),
  wgs84('WGS84'),
  dm('DM'),
  dms('DMS');

  const CoordFormatType(this.label);
  final String label;

  /// Döngüdeki bir sonraki biçim (MGRS → UTM → WGS84 → DM → DMS → MGRS).
  CoordFormatType get next =>
      CoordFormatType.values[(index + 1) % CoordFormatType.values.length];
}

/// Koordinat biçimlendirme yardımcıları (MGRS / UTM / WGS84 / DM / DMS).
class CoordFormat {
  CoordFormat._();

  /// Seçilen biçime göre tek satırlık koordinat metni üretir.
  static String format(LatLng p, CoordFormatType type) {
    switch (type) {
      case CoordFormatType.mgrs:
        return mgrs(p);
      case CoordFormatType.utm:
        return utm(p);
      case CoordFormatType.wgs84:
        return wgs84(p);
      case CoordFormatType.dm:
        return dm(p);
      case CoordFormatType.dms:
        return dms(p);
    }
  }

  /// UTM, ör. "37S 350123E 4302456N" (zone numarası + band harfi).
  static String utm(LatLng p) {
    try {
      final u = Mgrs.LLtoUTM(p.latitude, p.longitude);
      final e = u.easting.round();
      final n = u.northing.round();
      return '${u.zoneNumber}${u.zoneLetter} ${e}E ${n}N';
    } catch (_) {
      return '—';
    }
  }

  /// WGS84 ondalık derece: "39.92510°N, 32.86600°E".
  static String wgs84(LatLng p) {
    final ns = p.latitude >= 0 ? 'N' : 'S';
    final ew = p.longitude >= 0 ? 'E' : 'W';
    return '${p.latitude.abs().toStringAsFixed(5)}°$ns, '
        '${p.longitude.abs().toStringAsFixed(5)}°$ew';
  }

  /// Derece + ondalık dakika: 39°55.506'N 32°51.960'E.
  /// 0.001' ≈ 1.9 m.
  static String dm(LatLng p) =>
      '${_dmAxis(p.latitude, 'N', 'S')} ${_dmAxis(p.longitude, 'E', 'W')}';

  /// Derece-dakika-saniye: 39°55'30.4"N 32°51'57.6"E. 0.1 saniye ≈ 3 m.
  static String dms(LatLng p) =>
      '${_dmsAxis(p.latitude, 'N', 'S')} ${_dmsAxis(p.longitude, 'E', 'W')}';

  // Yuvarlama tam sayı birimde yapılır: 59.96 saniye "60.0" olmaz, dakikaya taşar.
  static String _dmAxis(double v, String pos, String neg) {
    final units = (v.abs() * 60000).round(); // 0.001 dakika
    final d = units ~/ 60000;
    final m = (units % 60000) / 1000;
    return "$d°${m.toStringAsFixed(3).padLeft(6, '0')}'${v >= 0 ? pos : neg}";
  }

  static String _dmsAxis(double v, String pos, String neg) {
    final tenths = (v.abs() * 36000).round(); // 0.1 saniye
    final d = tenths ~/ 36000;
    final m = (tenths % 36000) ~/ 600;
    final s = (tenths % 600) / 10;
    return "$d°${m.toString().padLeft(2, '0')}'"
        '${s.toStringAsFixed(1).padLeft(4, '0')}"${v >= 0 ? pos : neg}';
  }

  /// MGRS dizgisi (boşluklarla gruplanmış), ör. "36S VK 12345 67890".
  /// Kutup bölgeleri/aralık dışı için '—' döner.
  static String mgrs(LatLng p, {int accuracy = 5}) {
    try {
      // mgrs_dart'ın forward()'u hassasiyet < 5'te hanelerin SONUNU tutuyor
      // (yanlış; doğrusu baştakiler — kesme). Bu yüzden hep 5 haneyle kodlayıp
      // doğu/kuzeyin ilk [accuracy] hanesini kendimiz alıyoruz.
      final full = Mgrs.forward([p.longitude, p.latitude], 5);
      final a = accuracy.clamp(0, 5);
      final head = full.substring(0, full.length - 10);
      final e = full.substring(full.length - 10, full.length - 5);
      final n = full.substring(full.length - 5);
      final raw = '$head${e.substring(0, a)}${n.substring(0, a)}';
      return _group(raw, a);
    } catch (_) {
      return '—';
    }
  }

  /// "36SVK1234567890" → "36S VK 12345 67890".
  static String _group(String raw, int accuracy) {
    // Zone: baştaki rakamlar (1-2) + band harfi.
    var i = 0;
    while (i < raw.length && _isDigit(raw[i])) {
      i++;
    }
    final gzd = raw.substring(0, i + 1); // rakamlar + band harfi
    var rest = raw.substring(i + 1);
    if (rest.length < 2) return raw;
    final square = rest.substring(0, 2);
    final digits = rest.substring(2);
    if (digits.length == 2 * accuracy && accuracy > 0) {
      final easting = digits.substring(0, accuracy);
      final northing = digits.substring(accuracy);
      return '$gzd $square $easting $northing';
    }
    return '$gzd $square $digits';
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }
}
