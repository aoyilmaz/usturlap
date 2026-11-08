/// Sıra numaralı ad (ATAK Point Dropper: OP-1, OP-2…): [existing] içinde
/// `PREFIX-n` biçimindeki en büyük n'nin bir fazlası. Silinmiş aradaki
/// numaralar yeniden kullanılmaz (aynı ad iki farklı noktayı göstermesin).
String nextSequentialName(String prefix, Iterable<String> existing) {
  final re = RegExp('^${RegExp.escape(prefix)}-(\\d+)\$');
  var max = 0;
  for (final name in existing) {
    final m = re.firstMatch(name.trim());
    if (m == null) continue;
    final n = int.parse(m.group(1)!);
    if (n > max) max = n;
  }
  return '$prefix-${max + 1}';
}
