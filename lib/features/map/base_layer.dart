import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Bir taban harita katmanının nereden geldiğini belirtir.
enum BaseLayerSourceType {
  /// Çevrimiçi OSM raster karoları (internet gerekir).
  onlineOsm,

  /// Uygulamaya gömülü çevrimdışı MBTiles dosyası.
  offlineMbtiles,

  /// Gömülü çevrimdışı PMTiles (VEKTÖR / mvt) — vector_map_tiles ile çizilir.
  vectorPmtiles,

  /// Henüz bir MBTiles dosyası eklenmemiş katman (placeholder).
  missing,
}

/// Katman değiştiricide listelenen tek bir taban harita seçeneği.
class BaseLayerDef {
  final String id;
  final String label;
  final IconData icon;
  final BaseLayerSourceType type;

  /// offlineMbtiles için asset yolu (ör. 'assets/tiles/ankara_osm.mbtiles').
  final String? assetPath;

  /// MBTiles dosyasındaki en yüksek karo zoom'u. Bunun üstünde flutter_map
  /// mevcut en yakın karoyu büyüterek gösterir (bulanık ama görünür).
  final int? maxNativeZoom;

  /// Katman seçildiğinde haritanın taşınacağı merkez. AOI varsayılan görünümün
  /// (Ankara) dışındaysa (ör. Olucak) verilir; null ise harita yerinde kalır.
  final LatLng? center;

  /// vectorPmtiles için MapLibre stil JSON asset yolu (yol/su/bina renkleri).
  final String? stylePath;

  const BaseLayerDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    this.assetPath,
    this.maxNativeZoom,
    this.center,
    this.stylePath,
  });

  bool get isAvailable => type != BaseLayerSourceType.missing;
}

/// Kullanılabilir taban katmanlar.
///
/// Çevrimdışı katmanlar (`pusula-tiler` ile üretilen `.mbtiles`) `assets/tiles/`
/// altında durur ve burada tanımlanır. Olucak katmanları varsayılan görünümün
/// (Ankara) dışında olduğundan `center` ile seçilince harita oraya taşınır.
/// (`LatLng` const olmadığı için liste `final`.)
final List<BaseLayerDef> kBaseLayers = [
  const BaseLayerDef(
    id: 'offline_street',
    label: 'Sokak — çevrimdışı',
    icon: Icons.map_outlined,
    type: BaseLayerSourceType.offlineMbtiles,
    assetPath: 'assets/tiles/ankara_osm.mbtiles',
    maxNativeZoom: 14,
  ),
  const BaseLayerDef(
    id: 'online_street',
    label: 'Sokak — çevrimiçi (OSM)',
    icon: Icons.public,
    type: BaseLayerSourceType.onlineOsm,
  ),
  // --- pusula-tiler çıktıları ---
  const BaseLayerDef(
    id: 'sat_ankara',
    label: 'Uydu — Ankara',
    icon: Icons.satellite_alt,
    type: BaseLayerSourceType.offlineMbtiles,
    assetPath: 'assets/tiles/ankara_sat_z10-14.mbtiles',
    maxNativeZoom: 14,
  ),
  const BaseLayerDef(
    id: 'topo_ankara',
    label: 'Topografik — Ankara',
    icon: Icons.terrain,
    type: BaseLayerSourceType.offlineMbtiles,
    assetPath: 'assets/tiles/ankara_topo_z10-16.mbtiles',
    maxNativeZoom: 16,
  ),
  BaseLayerDef(
    id: 'sat_olucak',
    label: 'Uydu — Olucak',
    icon: Icons.satellite_alt,
    type: BaseLayerSourceType.offlineMbtiles,
    assetPath: 'assets/tiles/olucak_sat_z10-14.mbtiles',
    maxNativeZoom: 14,
    center: LatLng(37.1815, 36.696),
  ),
  BaseLayerDef(
    id: 'topo_olucak',
    label: 'Topografik — Olucak',
    icon: Icons.terrain,
    type: BaseLayerSourceType.offlineMbtiles,
    assetPath: 'assets/tiles/olucak_topo_z10-16.mbtiles',
    maxNativeZoom: 16,
    center: LatLng(37.1815, 36.696),
  ),
  // --- vektör (PMTiles / Protomaps) ---
  BaseLayerDef(
    id: 'vec_gaziantep',
    label: 'Vektör — Gaziantep',
    icon: Icons.account_tree_outlined,
    type: BaseLayerSourceType.vectorPmtiles,
    assetPath: 'assets/tiles/gaziantep.pmtiles',
    stylePath: 'assets/style/protomaps_light.json',
    center: LatLng(37.066, 37.378), // Gaziantep; PMTiles kapsamı içinde
  ),
];
