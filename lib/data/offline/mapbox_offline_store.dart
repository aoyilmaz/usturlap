import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../domain/models/offline_region.dart';

/// İndirme ilerlemesi (0..1) ve o ana kadar inen bayt.
typedef OfflineProgress = void Function(double fraction, int bytes);

/// Mapbox SDK'nın kendi çevrimdışı özelliği (TileStore + OfflineManager)
/// üzerinden bölge indirme. Mapbox lisansı gereği karolar YALNIZCA bu yolla
/// indirilir (kendi indiricimizle değil) — bkz. CLAUDE.md §2.
///
/// İndirilen: Mapbox uydu + yol/yer adları stili (z0..maxZoom) ve 3B arazi
/// için yükseklik verisi (DEM). Ağ yokken harita bu verilerle otomatik çizilir.
class MapboxOfflineStore {
  MapboxOfflineStore();

  /// İndirilen stil — ana ekrandaki uydu katmanıyla aynı olmalı.
  static const styleUri = MapboxStyles.SATELLITE_STREETS;
  static const _demTileset = 'mapbox://mapbox.mapbox-terrain-dem-v1';
  static const _idPrefix = 'pz-';

  /// Spike ekranının (kaldırıldı) kaydettiği eski bölgeler — listede
  /// "(deneme)" olarak görünür ki kullanıcı silebilsin.
  static const _legacyPrefix = 'bolge-';

  /// Mapbox'ın varsayılan toplam sınırı (tüm bölgeler): 750 karo paketi.
  static const tilePackLimit = 750;

  TileStore? _store;
  OfflineManager? _manager;

  Future<TileStore> _tileStore() async =>
      _store ??= await TileStore.createDefault();
  Future<OfflineManager> _offlineManager() async =>
      _manager ??= await OfflineManager.create();

  TileRegionLoadOptions _options(OfflineRegionSpec s, {DateTime? createdAt}) {
    final ring = [
      Position(s.west, s.south),
      Position(s.east, s.south),
      Position(s.east, s.north),
      Position(s.west, s.north),
      Position(s.west, s.south),
    ];
    return TileRegionLoadOptions(
      geometry: Polygon(coordinates: [ring]).toJson(),
      descriptorsOptions: [
        TilesetDescriptorOptions(
          styleURI: styleUri,
          minZoom: 0,
          maxZoom: s.maxZoom,
          tilesets: const [_demTileset],
        ),
      ],
      metadata: {
        'name': s.name,
        'south': s.south,
        'west': s.west,
        'north': s.north,
        'east': s.east,
        'maxZoom': s.maxZoom,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'style': styleUri,
      },
      acceptExpired: true,
      networkRestriction: NetworkRestriction.NONE,
    );
  }

  /// İndirilmiş bölgeler (en yeni üstte).
  Future<List<OfflineRegion>> list() async {
    final store = await _tileStore();
    final regions = await store.allTileRegions();
    final out = <OfflineRegion>[];
    for (final r in regions) {
      final legacy = r.id.startsWith(_legacyPrefix);
      if (!legacy && !r.id.startsWith(_idPrefix)) continue; // tahmin vb.
      Map<String, Object> m = const {};
      try {
        m = await store.tileRegionMetadata(r.id);
      } catch (_) {/* metadata yoksa varsayılanlar */}
      double d(String k) => (m[k] as num?)?.toDouble() ?? 0;
      final name = (m['name'] as String?) ?? r.id;
      // Kimlikteki zaman damgası (pz-<ms> / bolge-<ms>) yedek tarih olur.
      final idMs = int.tryParse(r.id.substring(r.id.indexOf('-') + 1));
      out.add(OfflineRegion(
        id: r.id,
        name: legacy ? '(deneme) $name' : name,
        south: d('south'),
        west: d('west'),
        north: d('north'),
        east: d('east'),
        maxZoom: (m['maxZoom'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(idMs ?? 0),
        sizeBytes: r.completedResourceSize,
        completedResources: r.completedResourceCount,
        requiredResources: r.requiredResourceCount,
      ));
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// İndirmeden önce diskte kaplayacağı tahmini boyut (bayt).
  Future<int> estimateBytes(OfflineRegionSpec spec) async {
    final store = await _tileStore();
    final r = await store.estimateTileRegion(
        '${_idPrefix}estimate', _options(spec), null, null);
    return r.storageSize;
  }

  /// Bölgeyi indirir. Önce stil paketi (stil, yazı tipleri, ikonlar), sonra
  /// karolar. Hata olursa istisna fırlatır (ör. 750 paket sınırı, ağ yok).
  Future<OfflineRegion> download(OfflineRegionSpec spec,
      {OfflineProgress? onProgress}) async {
    final manager = await _offlineManager();
    await manager.loadStylePack(
      styleUri,
      StylePackLoadOptions(
        glyphsRasterizationMode:
            GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
        acceptExpired: false,
      ),
      (_) {},
    );

    final store = await _tileStore();
    final id = '$_idPrefix${DateTime.now().millisecondsSinceEpoch}';
    final created = DateTime.now();
    final r = await store.loadTileRegion(id, _options(spec, createdAt: created),
        (p) {
      final f = p.requiredResourceCount == 0
          ? 0.0
          : p.completedResourceCount / p.requiredResourceCount;
      onProgress?.call(f, p.completedResourceSize);
    });
    return OfflineRegion(
      id: id,
      name: spec.name,
      south: spec.south,
      west: spec.west,
      north: spec.north,
      east: spec.east,
      maxZoom: spec.maxZoom,
      createdAt: created,
      sizeBytes: r.completedResourceSize,
      completedResources: r.completedResourceCount,
      requiredResources: r.requiredResourceCount,
    );
  }

  /// Bölgeyi siler. Başka bölgenin kullanmadığı karolar diskten de temizlenir.
  Future<void> delete(String id) async {
    final store = await _tileStore();
    await store.removeRegion(id);
  }

  /// Test için: Mapbox'ın ağ erişimini aç/kapat (uçak modu benzetimi).
  Future<void> setNetworkEnabled(bool enabled) =>
      OfflineSwitch.shared.setMapboxStackConnected(enabled);
}
