/// Üst araç çubuğuna konabilecek araçlar (ATAK Toolbar Manager, kılavuz
/// s.55–57). Kullanıcı hangilerinin, hangi sırayla çubukta duracağını seçer;
/// hepsi ≡ ızgarasında da vardır (çubuktan çıkan araç kaybolmaz).
///
/// Saf Dart: ayarlarda yalnızca adlarla (enum `.name`) saklanır. İkon ve
/// etiket arayüz katmanında (`features/shell/toolbar_tools.dart`).
enum ToolbarTool {
  dropPoint,
  measure,
  goTo,
  bloodhound,
  resection,
  tacticalCompass,
  maps,
  record,
  routes,
  waypoints,
  tracks,
  graphics,
  offlineRegions,
  overlays,
  savedViews,
  clearMap,
  bullseye,
  nightMode,
  crosshair,
  settings;

  /// Varsayılan çubuk (Aşama D1'deki sıra).
  static const defaults = [dropPoint, measure, goTo, maps, record];

  /// Çubukta en çok araç (≡ hariç). Dikey iPhone'a sığar:
  /// 4 + 48 (≡) + 5 (ayraç) + 6 × 48 + 4 = 349 pt < 375 − 16.
  static const maxOnBar = 6;

  static String encode(List<ToolbarTool> tools) =>
      tools.map((t) => t.name).join(',');

  /// Bilinmeyen adlar (ör. başka sürümden kalma) atlanır; tekrarlar ve
  /// [maxOnBar] üstü kırpılır. Boş metin = çubukta yalnız ≡.
  static List<ToolbarTool> decode(String text) {
    final byName = values.asNameMap();
    final out = <ToolbarTool>[];
    for (final name in text.split(',')) {
      final t = byName[name.trim()];
      if (t == null || out.contains(t)) continue;
      if (out.length >= maxOnBar) break;
      out.add(t);
    }
    return out;
  }
}
