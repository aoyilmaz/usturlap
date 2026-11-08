import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/sequential_name.dart';

void main() {
  test('ilk ad 1 ile başlar', () {
    expect(nextSequentialName('OP', const []), 'OP-1');
  });

  test('en büyük numaranın bir fazlası; aradaki boşluk doldurulmaz', () {
    expect(nextSequentialName('OP', const ['OP-1', 'OP-4', 'OP-2']), 'OP-5');
  });

  test('başka önek ve benzer adlar sayılmaz', () {
    expect(
      nextSequentialName('DÜŞMAN', const [
        'DÜŞMAN-2',
        'DÜŞMAN-X',
        'ESKİ DÜŞMAN-9',
        'DÜŞMAN-3 tepe',
        'DOST-7',
      ]),
      'DÜŞMAN-3',
    );
  });

  test('önekteki özel karakterler kaçırılır', () {
    expect(nextSequentialName('A.B', const ['AXB-5', 'A.B-1']), 'A.B-2');
  });
}
