import 'dart:math' as math;
import 'dart:typed_data';

/// Yükseklik dosyası biçimi.
enum DemFormat {
  /// SRTM `.hgt`: başlıksız, kuzeyden güneye satırlar, 16 bit büyük-uçlu.
  hgt,

  /// DTED (MIL-PRF-89020B) `.dt0/.dt1/.dt2`: başlıklar + batıdan doğuya
  /// sütun kayıtları, sütun içinde güneyden kuzeye; işaret-büyüklük 16 bit.
  dted,
}

/// 1°×1° yükseklik karesi (HGT ya da DTED). Saf Dart; dosya okuma ayrı.
class DemTile {
  DemTile._({
    required this.format,
    required this.south,
    required this.west,
    required this.rows,
    required this.cols,
    required ByteData data,
    required int dataOffset,
  }) : _bytes = data,
       _offset = dataOffset;

  final DemFormat format;

  /// Güneybatı köşe (tam derece).
  final int south;
  final int west;

  /// Enlem yönünde nokta sayısı (kuzey-güney) ve boylam yönünde (doğu-batı).
  final int rows;
  final int cols;

  // Ham veri ve verinin başladığı konum (DTED'de başlıklardan sonra).
  final ByteData _bytes;
  final int _offset;

  /// Ham dosya baytları (arka plan hesabına aktarmak için; bkz.
  /// [DemTile.parse]).
  Uint8List get bytes =>
      _bytes.buffer.asUint8List(_bytes.offsetInBytes, _bytes.lengthInBytes);

  /// Çözünürlük (yay saniyesi, enlem yönünde).
  double get resolutionArcSec => 3600 / (rows - 1);

  // DTED başlık uzunlukları (UHL + DSI + ACC) ve kayıt çerçevesi.
  static const _dtedHeader = 80 + 648 + 2700;
  static const _dtedRecordHead = 8;
  static const _dtedRecordTail = 4;

  /// Baytlardan kare. HGT'de köşe dosya adından gelir ([south], [west]);
  /// DTED'de başlıktan okunur. Biçim / boyut tutmazsa [FormatException].
  factory DemTile.parse(Uint8List bytes, {int? south, int? west}) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length >= 4 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'UHL1') {
      return _parseDted(bytes, data);
    }
    if (south == null || west == null) {
      throw const FormatException('HGT dosya adında konum yok (ör. N37E037)');
    }
    final n = math.sqrt(bytes.length / 2).round();
    if (n < 2 || n * n * 2 != bytes.length) {
      throw FormatException(
        'HGT boyutu kare değil (${bytes.length} bayt); 1201² ya da 3601² '
        'nokta beklenir',
      );
    }
    return DemTile._(
      format: DemFormat.hgt,
      south: south,
      west: west,
      rows: n,
      cols: n,
      data: data,
      dataOffset: 0,
    );
  }

  static DemTile _parseDted(Uint8List bytes, ByteData data) {
    String field(int from, int len) =>
        String.fromCharCodes(bytes.sublist(from, from + len));
    int? number(int from, int len) => int.tryParse(field(from, len).trim());
    if (bytes.length < _dtedHeader) {
      throw const FormatException('DTED başlığı eksik');
    }
    // Köşe: DDDMMSSH (yarım küre harfi).
    int corner(int from) {
      final deg = number(from, 3);
      final hemi = field(from + 7, 1);
      if (deg == null) throw const FormatException('DTED köşe bozuk');
      return hemi == 'S' || hemi == 'W' ? -deg : deg;
    }

    final west = corner(4);
    final south = corner(12);
    final cols = number(47, 4); // boylam çizgisi sayısı
    final rows = number(51, 4); // her çizgide enlem noktası
    if (cols == null || rows == null || cols < 2 || rows < 2) {
      throw const FormatException('DTED nokta sayıları bozuk');
    }
    final record = _dtedRecordHead + rows * 2 + _dtedRecordTail;
    if (bytes.length < _dtedHeader + cols * record) {
      throw const FormatException('DTED veri kayıtları eksik');
    }
    return DemTile._(
      format: DemFormat.dted,
      south: south,
      west: west,
      rows: rows,
      cols: cols,
      data: data,
      dataOffset: _dtedHeader,
    );
  }

  /// Izgara noktası değeri: [r] güneyden kuzeye (0 = güney kenar), [c]
  /// batıdan doğuya. Veri boşluğunda null.
  int? valueAt(int r, int c) {
    switch (format) {
      case DemFormat.hgt:
        // HGT satırları kuzeyden güneye.
        final pos = _offset + ((rows - 1 - r) * cols + c) * 2;
        final v = _bytes.getInt16(pos, Endian.big);
        return v <= -32768 ? null : v;
      case DemFormat.dted:
        final record = _dtedRecordHead + rows * 2 + _dtedRecordTail;
        final pos = _offset + c * record + _dtedRecordHead + r * 2;
        final raw = _bytes.getUint16(pos, Endian.big);
        // İşaret-büyüklük: en üst bit işaret.
        final v = raw & 0x8000 != 0 ? -(raw & 0x7FFF) : raw;
        return v <= -32767 ? null : v;
    }
  }

  /// Kare içindeki konumun ızgara koordinatı (kesirli).
  (double, double) _grid(double lat, double lon) => (
    (lat - south).clamp(0.0, 1.0) * (rows - 1),
    (lon - west).clamp(0.0, 1.0) * (cols - 1),
  );

  /// En yakın ızgara noktası (eski davranış).
  int? nearest(double lat, double lon) {
    final (r, c) = _grid(lat, lon);
    return valueAt(r.round(), c.round());
  }

  /// Çevredeki 4 noktadan çift doğrusal ara değer (m). Birinde veri yoksa
  /// en yakın nokta; o da yoksa null.
  double? sample(double lat, double lon) {
    final (r, c) = _grid(lat, lon);
    final r0 = r.floor().clamp(0, rows - 1), c0 = c.floor().clamp(0, cols - 1);
    final r1 = math.min(r0 + 1, rows - 1), c1 = math.min(c0 + 1, cols - 1);
    final v00 = valueAt(r0, c0), v01 = valueAt(r0, c1);
    final v10 = valueAt(r1, c0), v11 = valueAt(r1, c1);
    if (v00 == null || v01 == null || v10 == null || v11 == null) {
      return nearest(lat, lon)?.toDouble();
    }
    final fr = r - r0, fc = c - c0;
    final lower = v00 + (v01 - v00) * fc; // güneydeki iki nokta arası
    final upper = v10 + (v11 - v10) * fc; // kuzeydeki
    return lower + (upper - lower) * fr;
  }

  /// Konumun düştüğü karenin anahtarı: "N37E037", "S12W045".
  static String keyFor(int south, int west) {
    final ns = south >= 0 ? 'N' : 'S';
    final ew = west >= 0 ? 'E' : 'W';
    return '$ns${south.abs().toString().padLeft(2, '0')}'
        '$ew${west.abs().toString().padLeft(3, '0')}';
  }

  /// Dosya adındaki kare anahtarı ("N37E037.SRTMGL1.hgt" → (37, 37)).
  static (int south, int west)? parseKey(String fileName) {
    final m = RegExp(
      r'([NS])(\d{1,2})([EW])(\d{1,3})',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (m == null) return null;
    final lat = int.parse(m.group(2)!);
    final lon = int.parse(m.group(4)!);
    if (lat > 89 || lon > 179) return null;
    return (
      m.group(1)!.toUpperCase() == 'S' ? -lat : lat,
      m.group(3)!.toUpperCase() == 'W' ? -lon : lon,
    );
  }
}
