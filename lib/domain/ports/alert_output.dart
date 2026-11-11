/// Uyarıyı sesli okuma (TTS). Uygulama öndeyken kullanılır.
abstract class Speaker {
  Future<void> speak(String text);
}

/// Yerel bildirim (uygulama arka plandayken uyarı).
abstract class AlertNotifications {
  /// Bildirim izni ister (iOS yalnız ilk seferde sorar). Verildiyse true.
  Future<bool> requestPermission();

  Future<void> show(int id, String title, String body);
}

/// Konuşmada okunacak ad: tire / alt çizgi boşluk olur ("ALAN-1" →
/// "ALAN 1"; okuyucu "eksi" demesin).
String spokenName(String name) => name.replaceAll(RegExp(r'[-_]+'), ' ').trim();

/// Konuşmada mesafe: "850 metre", "1,2 kilometre".
String spokenDistance(double meters) {
  if (meters < 1000) return '${meters.round()} metre';
  final km = meters / 1000;
  final t = km >= 10 ? km.round().toString() : km.toStringAsFixed(1);
  return '${t.replaceAll('.', ',')} kilometre';
}

/// Konuşmada süre: "45 saniye", "4 dakika", "1 saat 10 dakika".
String spokenDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} saniye';
  if (d.inMinutes < 60) return '${d.inMinutes} dakika';
  final m = d.inMinutes % 60;
  return '${d.inHours} saat${m == 0 ? '' : ' $m dakika'}';
}
