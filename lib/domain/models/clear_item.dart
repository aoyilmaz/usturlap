/// "Haritayı temizle" (D4b) listesindeki türler. Yalnız haritada görünenler
/// temizlenir (Overlay yöneticisinde gizlenmiş nokta / çizime dokunulmaz);
/// kayıtlı rotalar haritada durmadığı için listede yok.
///
/// [permanent]: kalıcı veri (varsayılan işaretsiz, ayrıca uyarı).
/// [canHide]: "Yalnız gizle" seçilince silinmek yerine Overlay
/// yöneticisinde gizlenebilir (diğerleri geçicidir, her durumda temizlenir).
enum ClearItem {
  measurement('Ölçüm çizimi', permanent: false, canHide: false),
  rangeLines('R&B çizgileri', permanent: false, canHide: true),
  rangeRings('Menzil halkaları', permanent: false, canHide: true),
  bullseye('Bullseye', permanent: false, canHide: false),
  bloodhounds('Takipler', permanent: false, canHide: false),
  navTarget('"Git" hedefi', permanent: false, canHide: false),
  activeRoute('Rota takibi', permanent: false, canHide: false),
  displayedTrack('Gösterilen iz', permanent: false, canHide: false),
  viewshed('Görüş alanı', permanent: false, canHide: false),
  terrain('Arazi katmanları', permanent: false, canHide: false),
  waypoints('Noktalar', permanent: true, canHide: true),
  graphics('Çizimler', permanent: true, canHide: true);

  const ClearItem(this.label, {required this.permanent, required this.canHide});

  final String label;
  final bool permanent;
  final bool canHide;

  /// Varsayılan seçim: geçiciler işaretli, kalıcı veri işaretsiz.
  bool get selectedByDefault => !permanent;
}
