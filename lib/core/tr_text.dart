/// Türkçe büyük harf: Dart'ın `toUpperCase()` yerel ayarı bilmez
/// ("Veri" → "VERI" olur). i → İ, ı → I önce çevrilir.
String upperTr(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
