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

    test('Gürültüyü sönümler (oturmuş filtre ani sıçramaya direnir)', () {
      final kf = KalmanFilter(q: 0.01, r: 1.0); // r büyük = ölçüme az güven
      // Önce kararlı ölçümlerle otursun. (Tek ölçümden sonra ikinci ölçüm
      // eşit güvenilir sayılır → ~ortalaması alınır; direnç beklenmez.)
      for (var i = 0; i < 20; i++) {
        kf.update(100.0);
      }
      final res = kf.update(110.0); // 10 derecelik ani gürültü sıçraması

      // Oturmuş kazanç ≈ 0.095 → tahmin yalnızca ~1° kayar.
      expect(res, greaterThan(100.0));
      expect(res, lessThan(102.0));
    });

    test('İlk sıçramada iki eşit güvenilir ölçümün ortasına yakın', () {
      // Başlangıç belirsizliği (p=1) ölçüm gürültüsüne (r=1) eşit: ikinci
      // ölçüm yaklaşık yarı ağırlık alır (eski testin yanlış beklentisi).
      final kf = KalmanFilter(q: 0.01, r: 1.0);
      kf.update(100.0);
      expect(kf.update(110.0), closeTo(105.0, 0.1));
    });

    test('reset kurucudaki başlangıç belirsizliğine döner', () {
      // Küçük p: ilk ölçüme güvenilir → sonrakiler yavaş etkiler.
      final kf = KalmanFilter(q: 0.01, r: 1.0, p: 0.01);
      kf.update(100.0);
      final before = kf.update(110.0);
      kf.reset();
      kf.update(100.0);
      expect(kf.update(110.0), closeTo(before, 1e-9));
      expect(before, lessThan(102.0));
    });

    test('360 derece sınırından geçişi (wrap-around) doğru yönetir', () {
      final kf = KalmanFilter(
        q: 0.5,
        r: 0.1,
      ); // q yüksek = ölçüme hızlı tepki ver
      kf.update(355.0);
      double res = kf.update(5.0); // Pusula 355'ten 5'e atladı (sağa döndü)

      // Geriye doğru 350 derece fark alıp 180'lere düşmek yerine,
      // kısa yolu seçerek 0'a (360'a) doğru ilerlemeli.
      expect(res < 10 || res > 350, isTrue);
    });
  });
}
