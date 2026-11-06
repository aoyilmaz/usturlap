import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import 'wmm.dart';

/// Kerterizin hangi kuzeye göre gösterileceği (ATAK: True / Magnetic / Grid).
enum NorthRef {
  /// Coğrafi (gerçek) kuzey. Uygulamanın bütün hesapları bu kuzeye göredir.
  trueNorth('Coğrafi', ''),

  /// Manyetik kuzey — el pusulasıyla aynı değer (WMM2025 sapması uygulanır).
  magnetic('Manyetik', 'M'),

  /// Grid kuzeyi — UTM/MGRS paftasındaki dik çizgiler (yakınsama uygulanır).
  grid('Grid', 'G');

  const NorthRef(this.label, this.suffix);
  final String label;

  /// Gösterimde değerin sonuna eklenen harf (coğrafi için boş).
  final String suffix;

  static NorthRef fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => trueNorth);
}

/// Açı birimi. NATO mili: tam daire 6400 mil.
enum AngleUnit {
  degrees('Derece'),
  mils('Mil');

  const AngleUnit(this.label);
  final String label;

  static AngleUnit fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => degrees);
}

/// Kuzey referansı dönüşümleri (saf Dart, test edilir).
class NorthMath {
  NorthMath._();

  /// [p] noktasındaki UTM grid yakınsaması (derece). Grid kuzeyi coğrafi
  /// kuzeyin doğusundaysa (+). Grid kerterizi = coğrafi − yakınsama.
  static double gridConvergence(LatLng p) {
    int zone;
    try {
      // mgrs_dart Norveç/Svalbard bölge istisnalarını da uygular.
      zone = Mgrs.LLtoUTM(p.latitude, p.longitude).zoneNumber;
    } catch (_) {
      zone = ((p.longitude + 180) / 6).floor() % 60 + 1;
    }
    final centralMeridian = zone * 6 - 183;
    final dLon = (p.longitude - centralMeridian) * math.pi / 180;
    final lat = p.latitude * math.pi / 180;
    return math.atan(math.tan(dLon) * math.sin(lat)) * 180 / math.pi;
  }

  /// Coğrafi kerterizi [ref] kuzeyine çevirir (0–360).
  static double fromTrue(
    double trueDeg,
    LatLng at,
    NorthRef ref, {
    DateTime? date,
  }) {
    final double v;
    switch (ref) {
      case NorthRef.trueNorth:
        v = trueDeg;
      case NorthRef.magnetic:
        v = trueDeg - Wmm.declination(at.latitude, at.longitude, date: date);
      case NorthRef.grid:
        v = trueDeg - gridConvergence(at);
    }
    return _norm(v);
  }

  static double _norm(double d) => ((d % 360) + 360) % 360;
}

/// Kerteriz gösterimi: kullanıcının seçtiği kuzey ve birim.
///
/// Örnekler: coğrafi+derece "045°", manyetik+derece "039°M",
/// grid+mil "0782 mil G".
class BearingFormatter {
  const BearingFormatter({
    this.ref = NorthRef.trueNorth,
    this.unit = AngleUnit.degrees,
  });

  final NorthRef ref;
  final AngleUnit unit;

  /// Coğrafi kerteriz [trueDeg]'i, [at] noktasında seçili kuzeye çevirip
  /// biçimlendirir. [at]: kerterizin ölçüldüğü nokta (gözlemci).
  String format(double trueDeg, LatLng at, {DateTime? date}) {
    final v = NorthMath.fromTrue(trueDeg, at, ref, date: date);
    final s = ref.suffix;
    switch (unit) {
      case AngleUnit.degrees:
        // 359.6 → 360 değil 000 olsun.
        final d = v.round() % 360;
        return '${d.toString().padLeft(3, '0')}°$s';
      case AngleUnit.mils:
        final m = (v * 6400 / 360).round() % 6400;
        return '${m.toString().padLeft(4, '0')} mil${s.isEmpty ? '' : ' $s'}';
    }
  }
}
