import '../models/bloodhound.dart';

/// Takip (Bloodhound) "varışa az kaldı" uyarısının kuralı.
///
/// ETA anlık hızla hesaplanır; yürürken hız biraz değişince ETA eşiğin
/// (ör. 5 dk) iki yanında gidip gelir ve uyarı tekrar tekrar çalıyordu
/// (denetim 2026-11-16). Kural: bir takip yakına (kırmızı) girince bir kez
/// uyarır; ancak yeniden uzağa (yeşil) çıkınca bir sonraki uyarı kurulur.
/// Takip oluşturulduğunda zaten yakınsa uyarmaz (kullanıcı zaten biliyor).
class EtaAlarm {
  /// Uyarısı verilmiş (yeniden kurulmamış) takipler.
  final Set<int> _fired = {};

  /// Bilinen takipler (yeni eklenen ilk okumada uyarmaz).
  final Set<int> _known = {};

  /// Okumaları işler; uyarı verilecek takip kimliklerini döndürür.
  /// [estimated] okumalar (duran kişinin yürüyüş hızı tahmini) uyarmaz.
  List<int> update(
    Iterable<({int id, EtaLevel? level, bool estimated})> readings,
  ) {
    final out = <int>[];
    final seen = <int>{};
    for (final r in readings) {
      seen.add(r.id);
      final isNew = _known.add(r.id);
      final close = r.level == EtaLevel.close && !r.estimated;
      if (r.level == EtaLevel.far) _fired.remove(r.id);
      if (!close) continue;
      if (isNew) {
        _fired.add(r.id); // zaten yakındı: sessizce kur
        continue;
      }
      if (_fired.add(r.id)) out.add(r.id);
    }
    // Kaldırılan takipler unutulur.
    _known.removeWhere((id) => !seen.contains(id));
    _fired.removeWhere((id) => !seen.contains(id));
    return out;
  }
}
