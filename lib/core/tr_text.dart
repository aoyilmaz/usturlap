/// Türkçe büyük harf: Dart'ın `toUpperCase()` yerel ayarı bilmez
/// ("Veri" → "VERI" olur). i → İ, ı → I önce çevrilir.
String upperTr(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Türkçe küçük harf: I → ı, İ → i önce çevrilir ("KUYU" → "kuyu",
/// "İZ" → "iz").
String lowerTr(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
