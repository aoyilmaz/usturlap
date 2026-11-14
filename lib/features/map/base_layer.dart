import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../domain/models/offline_region.dart';

/// Bir taban harita katmanının nereden geldiğini belirtir.
enum BaseLayerSourceType {
  /// Çevrimiçi OSM raster karoları (internet gerekir).
  onlineOsm,

  /// Çevrimiçi Topografik raster karoları.
  onlineTopo,

  /// Mapbox stili (uydu, sokak, topografik): çevrimiçi; Mapbox SDK ile
  /// indirilen bölgede çevrimdışı. Token gerekir.
  mapboxStyle,

  /// Uygulamaya gömülü çevrimdışı MBTiles dosyası.
  offlineMbtiles,

  /// Çevrimdışı PMTiles (vektör ya da raster) — yerel karo sunucusundan.
  vectorPmtiles,

  /// İçe aktarılmış GeoPackage (raster karo, EPSG:3857).
  offlineGpkg,

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

  /// MBTiles dosyasındaki en yüksek karo zoom'u. Bunun üstünde harita motoru
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

  /// mapboxStyle için harita türü (stil adresi ve çevrimdışı indirme).
  final OfflineMapType? mapType;

  /// Listede adın altında gösterilen kısa açıklama.
  final String? hint;

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
    this.mapType,
    this.hint,
  });

  bool get isAvailable {
    if (type == BaseLayerSourceType.missing) return false;
    if (type == BaseLayerSourceType.mapboxStyle) {
      return AppConstants.mapboxAccessToken.isNotEmpty;
    }
    return true;
  }

  /// Dosyası Belgeler'den okunan (cihazda olması gereken) katman mı.
  bool get needsFile =>
      fileName != null &&
      (type == BaseLayerSourceType.vectorPmtiles ||
          type == BaseLayerSourceType.offlineGpkg ||
          assetPath == null && type == BaseLayerSourceType.offlineMbtiles);
}

/// Kullanılabilir taban katmanlar.
///
/// Çevrimdışı katmanlar (`pusula-tiler` ile üretilen `.mbtiles`) `assets/tiles/`
/// altında durur ve burada tanımlanır. Olucak katmanları varsayılan görünümün
/// (Ankara) dışında olduğundan `center` ile seçilince harita oraya taşınır.
/// (`LatLng` const olmadığı için liste `final`.)
final List<BaseLayerDef> kBaseLayers = [
  // --- Mapbox: çevrimiçi; Çevrimdışı haritalar'dan indirilen bölgede
  // internetsiz (id 'online_satellite' kayıtlı görünümler için korunur) ---
  const BaseLayerDef(
    id: 'online_satellite',
    label: 'Uydu',
    icon: Icons.satellite_alt,
    type: BaseLayerSourceType.mapboxStyle,
    mapType: OfflineMapType.satellite,
    maxNativeZoom: 22,
    hint: 'yol ve yer adlarıyla · indirilen bölgede çevrimdışı',
  ),
  const BaseLayerDef(
    id: 'mapbox_streets',
    label: 'Sokak',
    icon: Icons.map,
    type: BaseLayerSourceType.mapboxStyle,
    mapType: OfflineMapType.streets,
    maxNativeZoom: 22,
    hint: 'sokak adları, binalar · indirilen bölgede çevrimdışı',
  ),
  const BaseLayerDef(
    id: 'mapbox_outdoors',
    label: 'Topografik',
    icon: Icons.terrain,
    type: BaseLayerSourceType.mapboxStyle,
    mapType: OfflineMapType.outdoors,
    maxNativeZoom: 22,
    hint: 'eş yükselti eğrileri, patikalar · indirilen bölgede çevrimdışı',
  ),
  // --- yalnız çevrimiçi (kaynakları toplu indirmeyi yasaklıyor) ---
  const BaseLayerDef(
    id: 'online_street',
    label: 'OpenStreetMap',
    icon: Icons.map_outlined,
    type: BaseLayerSourceType.onlineOsm,
    maxNativeZoom: 19,
    hint: 'yalnız çevrimiçi',
  ),
  const BaseLayerDef(
    id: 'online_topo',
    label: 'OpenTopoMap',
    icon: Icons.landscape_outlined,
    type: BaseLayerSourceType.onlineTopo,
    maxNativeZoom: 17,
    hint: 'yalnız çevrimiçi',
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
    hint: 'turkey.pmtiles dosyasıyla (içe aktar)',
  ),
];
