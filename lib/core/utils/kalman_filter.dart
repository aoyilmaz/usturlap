/// 1 Boyutlu (1D) basit Kalman Filtresi.
/// Özellikle pusula (kerteriz) verisindeki gürültüyü sönümlemek (pürüzsüzleştirmek)
/// ve ani sapmaları engellemek için kullanılır. Açısal değerler (0-360) için uyarlanmıştır.
class KalmanFilter {
  /// Sistem (süreç) gürültüsü. Değer büyüdükçe filtre giriş verisine daha hızlı tepki verir (daha az pürüzsüzleşir).
  final double q;

  /// Ölçüm gürültüsü. Değer büyüdükçe sensörden gelen verilere daha az güvenilir (daha çok pürüzsüzleşir).
  final double r;

  double _x = double.nan; // Tahmin edilen mevcut değer
  final double _p0; // Başlangıç tahmin hatası (reset bununla döner)
  double _p; // Tahmin hata kovaryansı
  double _k = 0; // Kalman kazancı

  /// [q]: Süreç gürültüsü (Process noise)
  /// [r]: Ölçüm gürültüsü (Measurement noise)
  /// [p]: Başlangıç tahmin hatası (Initial estimation error covariance)
  KalmanFilter({this.q = 0.05, this.r = 0.5, double p = 1.0})
      : _p0 = p,
        _p = p;

  /// Yeni bir sensör ölçümünü (0-360 derece arası) filtreye besler ve pürüzsüzleştirilmiş yeni tahmini döner.
  double update(double measurement) {
    if (_x.isNaN) {
      _x = measurement;
      return _x;
    }

    // Açısal değerler için (0-360) dairesel sarmalama (wrap-around) hesabı.
    // En kısa açısal mesafeyi bulmamız gerekiyor ki 359'dan 1'e geçerken
    // geriye doğru koca bir tur atıyormuş gibi davranmasın.
    double diff = measurement - _x;
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // 1. Tahmin Güncellemesi (Prediction Update)
    _p = _p + q;

    // 2. Ölçüm Güncellemesi (Measurement Update)
    _k = _p / (_p + r);
    _x = _x + _k * diff;
    _p = (1 - _k) * _p;

    // Sonucu tekrar 0-360 aralığına normalize et
    if (_x < 0) {
      _x += 360;
    } else if (_x >= 360) {
      _x -= 360;
    }

    return _x;
  }

  /// Filtreyi sıfırlar. Sensör verisi uzun süre kesildiğinde veya çok ani bir durum değiştiğinde kullanılabilir.
  void reset() {
    _x = double.nan;
    _p = _p0; // kurucudaki başlangıç değeri (eskiden hep 1.0'dı)
  }
}
