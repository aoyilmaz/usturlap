import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/hashtags.dart';
import 'package:usturlap/core/tr_text.dart';

void main() {
  test('etiketler # olmadan, Türkçe küçük harfle', () {
    expect(extractHashtags('Kuyu #Su #KEŞİF, #ıslak_alan. #İZ-2'), {
      'su',
      'keşif',
      'ıslak_alan',
      'iz-2',
    });
  });

  test('etiket yoksa boş; tek # etiket değil', () {
    expect(extractHashtags(null), isEmpty);
    expect(extractHashtags('Not # yok'), isEmpty);
  });

  test('lowerTr: I → ı, İ → i', () {
    expect(lowerTr('IŞIK İZİ'), 'ışık izi');
  });
}
