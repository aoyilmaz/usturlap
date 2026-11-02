import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';

/// Bir taban harita katmanının nereden geldiğini belirtir.
enum BaseLayerSourceType {
  /// Çevrimiçi OSM raster karoları (internet gerekir).
  onlineOsm,

  /// Çevrimiçi Topografik raster karoları.
  onlineTopo,

  /// Çevrimiçi Mapbox uydu (+ yol/yer adları) raster karoları. Token gerekir.
  onlineSatellite,

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

  /// Büyük katmanlar (ör. tüm-Türkiye) gömülü asset olamaz. Verilirse karo
  /// dosyası cihazın **Documents** dizininden bu ada göre okunur (Dosyalar/Finder
  /// ile kopyalanır); assetPath yerine geçer. null → gömülü asset.
  final String? fileName;

  const BaseLayerDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    this.assetPath,
    this.maxNativeZoom,
    this.center,
    this.stylePath,
    this.fileName,
  });

  bool get isAvailable {
    if (type == BaseLayerSourceType.missing) return false;
    if (type == BaseLayerSourceType.onlineSatellite) {
      return AppConstants.mapboxAccessToken.isNotEmpty;
    }
    return true;
  }
}

/// Kullanılabilir taban katmanlar.
///
/// Çevrimdışı katmanlar (`pusula-tiler` ile üretilen `.mbtiles`) `assets/tiles/`
/// altında durur ve burada tanımlanır. Olucak katmanları varsayılan görünümün
/// (Ankara) dışında olduğundan `center` ile seçilince harita oraya taşınır.
/// (`LatLng` const olmadığı için liste `final`.)
final List<BaseLayerDef> kBaseLayers = [
  const BaseLayerDef(
    id: 'online_satellite',
    label: 'Uydu — çevrimiçi',
    icon: Icons.satellite_alt,
    type: BaseLayerSourceType.onlineSatellite,
    maxNativeZoom: 22,
  ),
  const BaseLayerDef(
    id: 'online_street',
    label: 'Sokak — çevrimiçi',
    icon: Icons.map,
    type: BaseLayerSourceType.onlineOsm,
    maxNativeZoom: 19,
  ),
  const BaseLayerDef(
    id: 'online_topo',
    label: 'Topografik — çevrimiçi',
    icon: Icons.terrain,
    type: BaseLayerSourceType.onlineTopo,
    maxNativeZoom: 17,
  ),
  // --- vektör (PMTiles / Protomaps) ---
  // Tüm Türkiye (~0.8 GB, z0-14): gömülemez → cihaz Documents'ından okunur.
  // turkey.pmtiles'ı Dosyalar/Finder ile Kerteriz'e kopyalayın.
  BaseLayerDef(
    id: 'vec_turkiye',
    label: 'Vektör — Türkiye',
    icon: Icons.public,
    type: BaseLayerSourceType.vectorPmtiles,
    fileName: 'turkey.pmtiles', // Documents/turkey.pmtiles
    stylePath: 'assets/style/protomaps_light.json',
  ),
];
