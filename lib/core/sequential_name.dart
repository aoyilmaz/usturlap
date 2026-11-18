/// Sıra numaralı ad (ATAK Point Dropper: OP-1, OP-2…): [existing] içinde
/// `PREFIX-n` biçimindeki en büyük n'nin bir fazlası. Silinmiş aradaki
/// numaralar yeniden kullanılmaz (aynı ad iki farklı noktayı göstermesin).
String nextSequentialName(String prefix, Iterable<String> existing) {
  final re = RegExp('^${RegExp.escape(prefix)}-(\\d+)\$');
  var max = 0;
  for (final name in existing) {
    final m = re.firstMatch(name.trim());
    if (m == null) continue;
    // Çok uzun sayı (kullanıcı elle yazdı) int'e sığmaz: yok say.
    final n = int.tryParse(m.group(1)!);
    if (n != null && n > max && n < 1000000000) max = n;
  }
  return '$prefix-${max + 1}';
}
