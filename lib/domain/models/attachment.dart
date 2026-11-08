/// Bir nesneye (nokta; ileride iz, çizim) eklenmiş dosya — şimdilik
/// fotoğraf (ATAK Details, kılavuz s.11). Saf Dart.
class Attachment {
  const Attachment({
    required this.id,
    required this.itemUid,
    required this.path,
    required this.filePath,
    required this.createdAt,
  });

  final int id;

  /// Bağlı olduğu nesnenin uid'i.
  final String itemUid;

  /// Saklanan göreli yol (Belgeler klasörüne göre).
  final String path;

  /// Bu çalıştırmadaki tam dosya yolu (görüntülemek için).
  final String filePath;

  final DateTime createdAt;
}
