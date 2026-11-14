import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/usecases/battery_alarm.dart';

/// Düşük pil eşikleri.
void main() {
  test('her eşikte bir kez; şarjda ve yükselince sıfırlanır', () {
    final a = BatteryAlarm();
    expect(a.update(50, charging: false), isNull);
    expect(a.update(20, charging: false), 20);
    expect(a.update(19, charging: false), isNull); // aynı eşik
    expect(a.update(9, charging: false), 10);
    expect(a.update(4, charging: false), 5);
    expect(a.update(3, charging: false), isNull);
    // Şarja takıldı: sıfırlanır, çıkınca yeniden uyarır.
    expect(a.update(3, charging: true), isNull);
    expect(a.update(3, charging: false), 5);
    // %25'in üstüne çıkınca sıfırlanır; ara düzey (22) yeterli değil.
    expect(a.update(22, charging: false), isNull);
    expect(a.update(30, charging: false), isNull);
    expect(a.update(18, charging: false), 20);
    // Doğrudan %8'e düşerse 10 eşiği.
    final b = BatteryAlarm();
    expect(b.update(8, charging: false), 10);
  });
}
