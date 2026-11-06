import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/tr_text.dart';

void main() {
  test('Türkçe büyük harf', () {
    expect(upperTr('Veri'), 'VERİ');
    expect(upperTr('Sistem'), 'SİSTEM');
    expect(upperTr('Işık ölçümü'), 'IŞIK ÖLÇÜMÜ');
    expect(upperTr('çığ'), 'ÇIĞ');
    expect(upperTr('MGRS'), 'MGRS');
  });
}
