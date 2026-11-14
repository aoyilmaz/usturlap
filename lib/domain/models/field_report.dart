/// Saha raporları (ATAK 9-Line / SPOTREP; NATO standart biçimleri, Türkçe).
/// Saf Dart: metin üretimi test edilebilir; paylaşım katmanı ayrı.
library;

const _months = [
  'OCA',
  'ŞUB',
  'MAR',
  'NİS',
  'MAY',
  'HAZ',
  'TEM',
  'AĞU',
  'EYL',
  'EKİ',
  'KAS',
  'ARA',
];

/// Tarih-saat grubu (DTG), UTC: "111530Z KAS 26".
String dtg(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(u.day)}${two(u.hour)}${two(u.minute)}Z '
      '${_months[u.month - 1]} ${two(u.year % 100)}';
}

/// Seçenekli satır kodu (harf + açıklama).
class Code {
  const Code(this.letter, this.label);
  final String letter;
  final String label;
}

/// CASEVAC / MEDEVAC 9 satır.
class NineLine {
  NineLine({
    this.location = '',
    this.frequency = '',
    this.callsign = '',
    Map<String, int>? byPrecedence,
    this.equipment = const {'A'},
    Map<String, int>? byType,
    this.security = 'N',
    this.marking = 'C',
    Map<String, int>? byNationality,
    this.cbrn = '',
    this.terrain = '',
    this.remarks = '',
  }) : byPrecedence = byPrecedence ?? {},
       byType = byType ?? {},
       byNationality = byNationality ?? {};

  String location;
  String frequency;
  String callsign;

  /// Satır 3: öncelik harfi → hasta sayısı.
  final Map<String, int> byPrecedence;

  /// Satır 4: özel teçhizat (birden çok seçilebilir).
  Set<String> equipment;

  /// Satır 5: L sedyeli / A yürüyebilen → sayı.
  final Map<String, int> byType;
  String security;
  String marking;

  /// Satır 8: uyruk / statü → sayı.
  final Map<String, int> byNationality;

  /// Satır 9: KBRN kirlilik (N / B / C; boş = yok).
  String cbrn;
  String terrain;
  String remarks;

  static const precedence = [
    Code('A', 'Acil (2 sa içinde)'),
    Code('B', 'Acil cerrahi'),
    Code('C', 'Öncelikli (4 sa içinde)'),
    Code('D', 'Rutin (24 sa içinde)'),
    Code('E', 'Uygun olduğunda'),
  ];
  static const equipmentCodes = [
    Code('A', 'Yok'),
    Code('B', 'Vinç'),
    Code('C', 'Kurtarma ekipmanı'),
    Code('D', 'Solunum cihazı'),
  ];
  static const types = [Code('L', 'Sedyeli'), Code('A', 'Yürüyebilen')];
  static const securityCodes = [
    Code('N', 'Düşman yok'),
    Code('P', 'Olası düşman'),
    Code('E', 'Düşman bölgede, dikkat'),
    Code('X', 'Düşman bölgede, silahlı refakat'),
  ];
  static const markingCodes = [
    Code('A', 'Panel'),
    Code('B', 'Piroteknik'),
    Code('C', 'Duman'),
    Code('D', 'Yok'),
    Code('E', 'Diğer'),
  ];
  static const nationality = [
    Code('A', 'Kendi askerî'),
    Code('B', 'Kendi sivil'),
    Code('C', 'Yabancı askerî'),
    Code('D', 'Yabancı sivil'),
    Code('E', 'Düşman esir'),
  ];
  static const cbrnCodes = [
    Code('N', 'Nükleer'),
    Code('B', 'Biyolojik'),
    Code('C', 'Kimyasal'),
  ];

  int get patients => byPrecedence.values.fold(0, (a, b) => a + b);

  static String _counts(Map<String, int> m, List<Code> order) {
    final parts = [
      for (final c in order)
        if ((m[c.letter] ?? 0) > 0) '${c.letter} ${m[c.letter]}',
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  static String _label(List<Code> codes, String letter) =>
      codes.where((c) => c.letter == letter).firstOrNull?.label ?? '';

  String toText(DateTime at) {
    final eq = [
      for (final c in equipmentCodes)
        if (equipment.contains(c.letter)) c.letter,
    ];
    return [
      'CASEVAC 9 SATIR — ${dtg(at)}',
      '1) ALIM YERİ: ${location.isEmpty ? '—' : location}',
      '2) FREKANS / ÇAĞRI: ${frequency.isEmpty ? '—' : frequency} / '
          '${callsign.isEmpty ? '—' : callsign}',
      '3) HASTA (ÖNCELİK): ${_counts(byPrecedence, precedence)}',
      '4) ÖZEL TEÇHİZAT: ${eq.isEmpty ? 'A' : eq.join(', ')} '
          '(${(eq.isEmpty ? ['A'] : eq).map((l) => _label(equipmentCodes, l)).join(', ')})',
      '5) HASTA (TÜR): ${_counts(byType, types)}',
      '6) GÜVENLİK: $security (${_label(securityCodes, security)})',
      '7) İŞARETLEME: $marking (${_label(markingCodes, marking)})',
      '8) UYRUK / STATÜ: ${_counts(byNationality, nationality)}',
      '9) KBRN / ARAZİ: '
          '${cbrn.isEmpty ? 'Yok' : '$cbrn (${_label(cbrnCodes, cbrn)})'}'
          '${terrain.isEmpty ? '' : ' — $terrain'}',
      if (remarks.isNotEmpty) 'NOT: $remarks',
    ].join('\n');
  }
}

/// SPOTREP (SALUTE): Sayı, Faaliyet, Konum, Birlik, Zaman, Teçhizat.
class SaluteReport {
  SaluteReport({
    this.size = '',
    this.activity = '',
    this.location = '',
    this.unit = '',
    DateTime? time,
    this.equipment = '',
    this.remarks = '',
  }) : time = time ?? DateTime.now();

  String size;
  String activity;
  String location;
  String unit;
  DateTime time;
  String equipment;
  String remarks;

  String toText(DateTime at) {
    String v(String s) => s.trim().isEmpty ? '—' : s.trim();
    return [
      'SPOTREP (SALUTE) — ${dtg(at)}',
      'S) SAYI / BÜYÜKLÜK: ${v(size)}',
      'A) FAALİYET: ${v(activity)}',
      'L) KONUM: ${v(location)}',
      'U) BİRLİK / KIYAFET: ${v(unit)}',
      'T) ZAMAN: ${dtg(time)}',
      'E) TEÇHİZAT: ${v(equipment)}',
      if (remarks.trim().isNotEmpty) 'NOT: ${remarks.trim()}',
    ].join('\n');
  }
}
