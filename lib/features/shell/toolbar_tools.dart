import 'package:flutter/material.dart';

import '../../core/toolbar_tool.dart';

export '../../core/toolbar_tool.dart';

/// Araçların ikon ve etiketi (araç çubuğu, ≡ ızgarası ve Araç çubuğu paneli
/// aynı görünümü kullanır). Duruma göre değişenler (kayıt sürerken "durdur",
/// gece modu açıkken dolu ay) harita ekranında üretilir.
extension ToolbarToolView on ToolbarTool {
  IconData get icon => switch (this) {
    ToolbarTool.dropPoint => Icons.add_location_alt_outlined,
    ToolbarTool.measure => Icons.straighten,
    ToolbarTool.goTo => Icons.travel_explore,
    ToolbarTool.bloodhound => Icons.pets,
    ToolbarTool.resection => Icons.change_history,
    ToolbarTool.tacticalCompass => Icons.explore,
    ToolbarTool.maps => Icons.map_outlined,
    ToolbarTool.record => Icons.radio_button_checked,
    ToolbarTool.routes => Icons.alt_route,
    ToolbarTool.waypoints => Icons.place_outlined,
    ToolbarTool.tracks => Icons.timeline,
    ToolbarTool.graphics => Icons.draw_outlined,
    ToolbarTool.draw => Icons.brush_outlined,
    ToolbarTool.lasso => Icons.highlight_alt,
    ToolbarTool.quickPic => Icons.add_a_photo_outlined,
    ToolbarTool.gallery => Icons.photo_library_outlined,
    ToolbarTool.geofence => Icons.fence,
    ToolbarTool.reports => Icons.assignment_outlined,
    ToolbarTool.weather => Icons.cloud_outlined,
    ToolbarTool.sunMoon => Icons.wb_twilight,
    ToolbarTool.offlineRegions => Icons.download_for_offline_outlined,
    ToolbarTool.overlays => Icons.layers_outlined,
    ToolbarTool.savedViews => Icons.bookmarks_outlined,
    ToolbarTool.clearMap => Icons.cleaning_services_outlined,
    ToolbarTool.elevationData => Icons.terrain,
    ToolbarTool.bullseye => Icons.track_changes,
    ToolbarTool.viewshed => Icons.visibility,
    ToolbarTool.terrainAnalysis => Icons.landscape,
    ToolbarTool.nightMode => Icons.nightlight_outlined,
    ToolbarTool.crosshair => Icons.center_focus_strong,
    ToolbarTool.settings => Icons.settings,
  };

  String get label => switch (this) {
    ToolbarTool.dropPoint => 'Nokta bırak',
    ToolbarTool.measure => 'Ölçüm (R&B)',
    ToolbarTool.goTo => 'Koordinat / Git',
    ToolbarTool.bloodhound => 'Takip (Bloodhound)',
    ToolbarTool.resection => 'Geriden kestirme',
    ToolbarTool.tacticalCompass => 'Taktik pusula',
    ToolbarTool.maps => 'Haritalar',
    ToolbarTool.record => 'İz kaydı',
    ToolbarTool.routes => 'Rotalar',
    ToolbarTool.waypoints => 'Noktalar',
    ToolbarTool.tracks => 'İzler',
    ToolbarTool.graphics => 'Çizimler',
    ToolbarTool.draw => 'Çizim araçları',
    ToolbarTool.lasso => 'Seç (lasso)',
    ToolbarTool.quickPic => 'Hızlı fotoğraf',
    ToolbarTool.gallery => 'Galeri',
    ToolbarTool.geofence => 'Geofence',
    ToolbarTool.reports => 'Raporlar',
    ToolbarTool.weather => 'Hava durumu',
    ToolbarTool.sunMoon => 'Güneş ve ay',
    ToolbarTool.offlineRegions => 'Çevrimdışı bölgeler',
    ToolbarTool.overlays => 'Overlay yöneticisi',
    ToolbarTool.savedViews => 'Kayıtlı görünümler',
    ToolbarTool.clearMap => 'Haritayı temizle',
    ToolbarTool.elevationData => 'Yükseklik verisi',
    ToolbarTool.bullseye => 'Bullseye',
    ToolbarTool.viewshed => 'Görüş alanı',
    ToolbarTool.terrainAnalysis => 'Arazi analizi',
    ToolbarTool.nightMode => 'Gece modu',
    ToolbarTool.crosshair => 'Artı imleç',
    ToolbarTool.settings => 'Ayarlar',
  };
}
