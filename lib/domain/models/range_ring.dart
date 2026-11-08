import 'range_line.dart';

/// Kalıcı menzil / tehdit halkaları (ATAK R&B Circle ve Threat Rings,
/// kılavuz s.8, 13): bir merkez çevresinde eş merkezli halkalar.
///
/// Merkez [RbEnd]: sabit ya da bir noktaya / kendi konumuma bağlı (nesne
/// hareket edince halkalar da gider). Halka mesafeleri eşit aralıklı
/// (R, 2R, 3R) ya da tek tek girilmiş olabilir (ör. silah menzilleri).
///
/// ATAK'ta CoT tipi `u-r-b-c-c` (TAK CoT kataloğu "Bearing circle");
/// paylaşımı sonraki aşamada.
class RangeRing {
  const RangeRing({
    required this.uid,
    required this.name,
    required this.center,
    required this.radii,
    required this.colorValue,
    required this.createdAt,
    this.id,
  });

  static const cotType = 'u-r-b-c-c';

  /// En çok halka sayısı (haritada okunur kalsın).
  static const maxRings = 6;

  /// Mesafe sınırları (m).
  static const minRadius = 1.0;
  static const maxRadius = 200000.0;

  /// Düşman / şüpheli merkezli halkalar kırmızı, diğerleri R&B pembesi.
  static const threatColor = 0xFFE03131;

  final int? id;
  final String uid;
  final String name;
  final RbEnd center;

  /// Küçükten büyüğe, tekrarsız (m).
  final List<double> radii;
  final int colorValue;
  final DateTime createdAt;

  /// Merkezden [meters] uzaktaki bir yer kaçıncı halkanın içinde (0 = en
  /// içteki); bütün halkaların dışındaysa null.
  int? ringIndexAt(double meters) {
    for (var i = 0; i < radii.length; i++) {
      if (meters <= radii[i]) return i;
    }
    return null;
  }

  /// Eşit aralıklı halkalar: R, 2R, … [count]·R.
  static List<double> evenRadii(double r, [int count = 3]) => [
    for (var k = 1; k <= count; k++) r * k,
  ];

  /// "500 1000 1,5km" → [500, 1000, 1500]. Ayraç boşluk ya da noktalı
  /// virgül (sondaki virgül de: "500, 1000"); ondalık virgül ya da nokta
  /// ("1,5" = "1.5"); `m` / `km` eki isteğe bağlı (yoksa metre). Boşsa,
  /// geçersiz bir değer varsa ya da [maxRings]'ten fazlaysa null.
  static List<double>? parseRadii(String text) {
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[;\s]+'))
        .map((t) => t.replaceAll(RegExp(r'[,.]+$'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    final out = <double>{};
    for (final t in tokens) {
      final m = RegExp(r'^(\d+(?:[.,]\d+)?)(km|m)?$').firstMatch(t);
      if (m == null) return null;
      var v = double.parse(m.group(1)!.replaceAll(',', '.'));
      if (m.group(2) == 'km') v *= 1000;
      if (v < minRadius || v > maxRadius) return null;
      out.add(v);
    }
    if (out.length > maxRings) return null;
    return out.toList()..sort();
  }

  /// [parseRadii]'nin tersi: düzenleme alanına yazılan metin.
  static String formatRadii(List<double> radii) => radii
      .map((r) => r == r.roundToDouble() ? '${r.round()}' : '$r')
      .join(' ');
}
