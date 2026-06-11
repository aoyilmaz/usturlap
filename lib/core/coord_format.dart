import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

/// Kullanıcının seçebileceği koordinat gösterim biçimleri.
enum CoordFormatType {
  mgrs('MGRS'),
  utm('UTM'),
  wgs84('WGS84');

  const CoordFormatType(this.label);
  final String label;

  /// Döngüdeki bir sonraki biçim (MGRS → UTM → WGS84 → MGRS).
  CoordFormatType get next =>
      CoordFormatType.values[(index + 1) % CoordFormatType.values.length];
}

/// Koordinat biçimlendirme yardımcıları (MGRS / UTM / WGS84).
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

  /// MGRS dizgisi (boşluklarla gruplanmış), ör. "36S VK 12345 67890".
  /// Kutup bölgeleri/aralık dışı için '—' döner.
  static String mgrs(LatLng p, {int accuracy = 5}) {
    try {
      final raw = Mgrs.forward([p.longitude, p.latitude], accuracy);
      return _group(raw, accuracy);
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
