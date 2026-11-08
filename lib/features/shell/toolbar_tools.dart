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
    ToolbarTool.maps => Icons.map_outlined,
    ToolbarTool.record => Icons.radio_button_checked,
    ToolbarTool.routes => Icons.alt_route,
    ToolbarTool.waypoints => Icons.place_outlined,
    ToolbarTool.tracks => Icons.timeline,
    ToolbarTool.graphics => Icons.draw_outlined,
    ToolbarTool.offlineRegions => Icons.download_for_offline_outlined,
    ToolbarTool.overlays => Icons.layers_outlined,
    ToolbarTool.savedViews => Icons.bookmarks_outlined,
    ToolbarTool.nightMode => Icons.nightlight_outlined,
    ToolbarTool.crosshair => Icons.center_focus_strong,
    ToolbarTool.settings => Icons.settings,
  };

  String get label => switch (this) {
    ToolbarTool.dropPoint => 'Nokta bırak',
    ToolbarTool.measure => 'Ölçüm (R&B)',
    ToolbarTool.goTo => 'Koordinat / Git',
    ToolbarTool.maps => 'Haritalar',
    ToolbarTool.record => 'İz kaydı',
    ToolbarTool.routes => 'Rotalar',
    ToolbarTool.waypoints => 'Noktalar',
    ToolbarTool.tracks => 'İzler',
    ToolbarTool.graphics => 'Çizimler',
    ToolbarTool.offlineRegions => 'Çevrimdışı bölgeler',
    ToolbarTool.overlays => 'Overlay yöneticisi',
    ToolbarTool.savedViews => 'Kayıtlı görünümler',
    ToolbarTool.nightMode => 'Gece modu',
    ToolbarTool.crosshair => 'Artı imleç',
    ToolbarTool.settings => 'Ayarlar',
  };
}
