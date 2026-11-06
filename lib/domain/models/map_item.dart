/// Haritadaki her kalıcı nesnenin ortak yüzü — ATAK'taki CoT olayının özü.
///
/// Nokta, grafik ve rota bunu uygular. Paylaşım (veri paketi, mesh), dışa
/// aktarma ve radyal menü nesneleri bu ortak kimlik üzerinden tanır.
abstract interface class MapItem {
  /// Kalıcı, cihazlar arası benzersiz kimlik (UUID v4) — CoT `uid`.
  /// Veritabanı `id`'si yalnızca bu cihazda geçerlidir; `uid` her yerde.
  String get uid;

  /// CoT tip kodu (bkz. `CotType`), ör. `a-f-G-U-C-I`, `b-m-r`, `u-d-f`.
  String get cotType;

  /// Görünen ad — CoT `<contact callsign>`.
  String get title;

  DateTime get createdAt;
}
