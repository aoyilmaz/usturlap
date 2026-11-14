/// Düşük pil uyarısı (saha konforu): pil eşiklerin altına inince her eşikte
/// bir kez uyarır; şarja takılınca ya da pil yeniden yükselince sıfırlanır.
class BatteryAlarm {
  BatteryAlarm({this.thresholds = const [20, 10, 5]});

  /// Büyükten küçüğe uyarı eşikleri (%).
  final List<int> thresholds;

  /// En son uyarılan eşik (yoksa null).
  int? warned;

  /// Yeni pil durumu; uyarılacak eşik varsa döner.
  int? update(int level, {required bool charging}) {
    if (charging || level > thresholds.first + 5) {
      warned = null;
      return null;
    }
    int? hit;
    for (final t in thresholds) {
      if (level <= t) hit = t;
    }
    if (hit == null) return null;
    if (warned != null && hit >= warned!) return null;
    warned = hit;
    return hit;
  }
}
