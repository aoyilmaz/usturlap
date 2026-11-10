import 'dart:typed_data';

/// Testler için sentetik yükseklik dosyaları (gerçek biçim düzeniyle).

/// HGT: [n]×[n] nokta, kuzeyden güneye satırlar. [value] (r: güneyden
/// kuzeye, c: batıdan doğuya) → metre; null = boşluk (-32768).
Uint8List makeHgt(int n, int? Function(int r, int c) value) {
  final b = ByteData(n * n * 2);
  for (var row = 0; row < n; row++) {
    final r = n - 1 - row; // dosyada ilk satır kuzey kenar
    for (var c = 0; c < n; c++) {
      b.setInt16((row * n + c) * 2, value(r, c) ?? -32768, Endian.big);
    }
  }
  return b.buffer.asUint8List();
}

/// DTED: UHL + DSI + ACC başlıkları, [cols] sütun kaydı (batıdan doğuya),
/// her biri [rows] nokta (güneyden kuzeye), işaret-büyüklük 16 bit,
/// sağlama toplamıyla. [south]/[west] köşe.
Uint8List makeDted({
  required int south,
  required int west,
  required int rows,
  required int cols,
  required int? Function(int r, int c) value,
}) {
  String deg(int v, String pos, String neg) =>
      '${v.abs().toString().padLeft(3, '0')}0000${v < 0 ? neg : pos}';
  final uhl = StringBuffer()
    ..write('UHL1')
    ..write(deg(west, 'E', 'W'))
    ..write(deg(south, 'N', 'S'))
    ..write('0300') // boylam aralığı (onda bir yay saniyesi)
    ..write('0300') // enlem aralığı
    ..write('0020')
    ..write('U  ')
    ..write(' ' * 12)
    ..write(cols.toString().padLeft(4, '0'))
    ..write(rows.toString().padLeft(4, '0'))
    ..write('0')
    ..write(' ' * 24);
  final head = uhl.toString().codeUnits;
  assert(head.length == 80);
  const header = 80 + 648 + 2700;
  final record = 8 + rows * 2 + 4;
  final out = Uint8List(header + cols * record);
  out.setAll(0, head);
  out.fillRange(80, header, 0x20);
  final b = ByteData.sublistView(out);
  for (var c = 0; c < cols; c++) {
    final start = header + c * record;
    out[start] = 0xAA;
    b.setUint16(start + 4, c, Endian.big);
    for (var r = 0; r < rows; r++) {
      final v = value(r, c) ?? -32767;
      final raw = v < 0 ? (0x8000 | (-v)) : v;
      b.setUint16(start + 8 + r * 2, raw, Endian.big);
    }
    var sum = 0;
    for (var i = start; i < start + record - 4; i++) {
      sum += out[i];
    }
    b.setUint32(start + record - 4, sum, Endian.big);
  }
  return out;
}
