import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/field_report.dart';

/// Saha raporları: DTG, 9 satır, SALUTE.
void main() {
  final at = DateTime.utc(2026, 11, 11, 15, 30);

  test('DTG: gün saat dakika Z, Türkçe ay', () {
    expect(dtg(at), '111530Z KAS 26');
    expect(dtg(DateTime.utc(2027, 2, 3, 4, 5)), '030405Z ŞUB 27');
  });

  test('9 satır metni: sayılar, kodlar, açıklamalar', () {
    final r = NineLine(
      location: '36S VK 12345 67890',
      frequency: '45.500',
      callsign: 'KURT-1',
      byPrecedence: {'A': 1, 'C': 2},
      equipment: {'B', 'D'},
      byType: {'L': 1, 'A': 2},
      security: 'P',
      marking: 'C',
      byNationality: {'A': 3},
      cbrn: '',
      terrain: 'güneyde tel örgü',
    );
    expect(r.patients, 3);
    final t = r.toText(at);
    expect(t.split('\n'), [
      'CASEVAC 9 SATIR — 111530Z KAS 26',
      '1) ALIM YERİ: 36S VK 12345 67890',
      '2) FREKANS / ÇAĞRI: 45.500 / KURT-1',
      '3) HASTA (ÖNCELİK): A 1, C 2',
      '4) ÖZEL TEÇHİZAT: B, D (Vinç, Solunum cihazı)',
      '5) HASTA (TÜR): L 1, A 2',
      '6) GÜVENLİK: P (Olası düşman)',
      '7) İŞARETLEME: C (Duman)',
      '8) UYRUK / STATÜ: A 3',
      '9) KBRN / ARAZİ: Yok — güneyde tel örgü',
    ]);
    // Boş form da okunur kalır.
    expect(NineLine().toText(at), contains('3) HASTA (ÖNCELİK): —'));
    expect(NineLine().toText(at), contains('4) ÖZEL TEÇHİZAT: A (Yok)'));
  });

  test('SALUTE metni', () {
    final t = SaluteReport(
      size: '1 manga',
      activity: 'kuzeye ilerliyor',
      location: '36S VK 1 2',
      unit: 'kamuflaj',
      time: DateTime.utc(2026, 11, 11, 15, 10),
      equipment: '',
      remarks: 'araçsız',
    ).toText(at);
    expect(t.split('\n'), [
      'SPOTREP (SALUTE) — 111530Z KAS 26',
      'S) SAYI / BÜYÜKLÜK: 1 manga',
      'A) FAALİYET: kuzeye ilerliyor',
      'L) KONUM: 36S VK 1 2',
      'U) BİRLİK / KIYAFET: kamuflaj',
      'T) ZAMAN: 111510Z KAS 26',
      'E) TEÇHİZAT: —',
      'NOT: araçsız',
    ]);
  });
}
