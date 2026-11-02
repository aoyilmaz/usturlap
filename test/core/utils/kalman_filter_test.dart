import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/utils/kalman_filter.dart';

void main() {
  group('KalmanFilter Tests', () {
    test('İlk değer doğrudan atanır', () {
      final kf = KalmanFilter();
      double res = kf.update(150.0);
      expect(res, 150.0);
    });

    test('İstikrarlı değerleri korur', () {
      final kf = KalmanFilter(q: 0.1, r: 0.1);
      kf.update(100.0);
      double res = kf.update(100.0);
      expect(res, closeTo(100.0, 0.01));
    });

    test('Gürültüyü sönümler (Ani sıçramalara direnç gösterir)', () {
      final kf = KalmanFilter(q: 0.01, r: 1.0); // r büyük = ölçüme az güven
      kf.update(100.0);
      double res = kf.update(110.0); // 10 derecelik ani gürültü sıçraması
      
      // Sonuç 100 ile 110 arasında olmalı ama 100'e çok daha yakın olmalı
      expect(res, lessThan(105.0));
      expect(res, greaterThan(100.0));
    });

    test('360 derece sınırından geçişi (wrap-around) doğru yönetir', () {
      final kf = KalmanFilter(q: 0.5, r: 0.1); // q yüksek = ölçüme hızlı tepki ver
      kf.update(355.0);
      double res = kf.update(5.0); // Pusula 355'ten 5'e atladı (sağa döndü)
      
      // Geriye doğru 350 derece fark alıp 180'lere düşmek yerine,
      // kısa yolu seçerek 0'a (360'a) doğru ilerlemeli.
      expect(res < 10 || res > 350, isTrue);
    });
  });
}
