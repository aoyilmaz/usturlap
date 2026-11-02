import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants.dart';
import '../../core/coord_format.dart';

/// SPIKE — Mapbox Maps SDK denemesi (bkz. docs/harita-motoru-gecis-plani.md).
///
/// Amaç: iPhone'da şunları doğrulamak:
///  1. Uydu görüntüsünün kalitesi ve z22'ye kadar kesintisiz zoom
///  2. 3B arazi
///  3. Ekrandaki alanı SDK'nın kendi offline özelliğiyle indirip uçak modunda görmek
///
/// Ana ekrana (flutter_map) dokunmaz; menüden ayrı açılır. Karar sonrası ya
/// gerçek mimariye taşınır ya da silinir.
class MapboxSpikeScreen extends StatefulWidget {
  const MapboxSpikeScreen({super.key});

  @override
  State<MapboxSpikeScreen> createState() => _MapboxSpikeScreenState();
}

/// Denenecek Mapbox stilleri.
const _styles = <(String, String)>[
  ('Uydu + etiket', MapboxStyles.SATELLITE_STREETS),
  ('Uydu (yalın)', MapboxStyles.SATELLITE),
  ('Standart uydu', MapboxStyles.STANDARD_SATELLITE),
  ('Arazi (outdoors)', MapboxStyles.OUTDOORS),
];

class _MapboxSpikeScreenState extends State<MapboxSpikeScreen> {
  static final _initialViewport = CameraViewportState(
    center: Point(
      coordinates: Position(AppConstants.initialCenter.longitude,
          AppConstants.initialCenter.latitude),
    ),
    zoom: AppConstants.initialZoom,
  );

  MapboxMap? _map;
  String _styleUri = _styles.first.$2;
  bool _terrain = false;
  bool _offlineMode = false;

  // HUD
  double _zoom = AppConstants.initialZoom;
  LatLng _center = AppConstants.initialCenter;

  // Offline
  TileStore? _tileStore;
  OfflineManager? _offlineManager;
  List<TileRegion> _regions = const [];
  double? _downloadProgress; // null → indirme yok
  int _downloadedBytes = 0;

  @override
  void initState() {
    super.initState();
    _initOffline();
  }

  @override
  void dispose() {
    // Ekrandan çıkarken ağı geri aç (OfflineSwitch uygulama geneli bir ayar).
    OfflineSwitch.shared.setMapboxStackConnected(true);
    super.dispose();
  }

  Future<void> _initOffline() async {
    _offlineManager = await OfflineManager.create();
    _tileStore = await TileStore.createDefault();
    await _refreshRegions();
  }

  Future<void> _refreshRegions() async {
    final regions = await _tileStore?.allTileRegions() ?? const <TileRegion>[];
    if (mounted) setState(() => _regions = regions);
  }

  // ---------------------------------------------------------------- harita

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    // Mapbox varsayılanı 22; açıkça belirtelim (Kerteriz ile aynı tavan).
    await map.setBounds(CameraBoundsOptions(maxZoom: 22, minZoom: 2));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: true));
    await map.compass.updateSettings(CompassSettings(enabled: true));
    await _enableLocationPuck();
  }

  /// Stil her değiştiğinde yeniden kurulan şeyler (arazi kaynağı vb.).
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_terrain) await _applyTerrain(true);
  }

  void _onCameraChanged(CameraChangedEventData e) {
    final c = e.cameraState.center.coordinates;
    setState(() {
      _zoom = e.cameraState.zoom;
      _center = LatLng(c.lat.toDouble(), c.lng.toDouble());
    });
  }

  /// Karo/stil yükleme hataları (ör. 401 token, 429 istek sınırı) — sessizce
  /// boş harita yerine ekranda görünsün. Aynı mesajı tekrar tekrar basma.
  String? _lastError;
  bool _offlineGapShown = false;
  void _onLoadError(MapLoadingErrorEventData e) {
    // Ağ kapalıyken indirilmemiş karo istendi: beklenen durum. Teknik mesaj
    // yerine bir kez anlaşılır uyarı göster (her karo için tekrar etme).
    if (_offlineMode && e.message.contains('connectivity is disabled')) {
      if (_offlineGapShown) return;
      _offlineGapShown = true;
      _toast('Bu alan/zoom çevrimdışı indirilmemiş. '
          'Mevcut karolar büyütülerek gösteriliyor.');
      return;
    }
    final msg = '${e.sourceId ?? e.type.name}: ${e.message}';
    if (msg == _lastError) return;
    _lastError = msg;
    _toast('Harita hatası — $msg');
  }

  Future<void> _enableLocationPuck() async {
    final perm = await geo.Geolocator.requestPermission();
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      return;
    }
    await _map?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ));
  }

  Future<void> _goToMyLocation() async {
    try {
      final p = await geo.Geolocator.getCurrentPosition();
      await _map?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(p.longitude, p.latitude)),
          zoom: 17,
        ),
        MapAnimationOptions(duration: 1200),
      );
    } catch (e) {
      _toast('Konum alınamadı: $e');
    }
  }

  Future<void> _applyTerrain(bool on) async {
    // MapboxMap, stil API'lerini doğrudan taşır (StyleManager).
    final style = _map;
    if (style == null) return;
    if (on) {
      if (!await style.styleSourceExists('mapbox-dem')) {
        await style.addSource(RasterDemSource(
          id: 'mapbox-dem',
          url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
          tileSize: 514,
          maxzoom: 14,
        ));
      }
      await style.setStyleTerrain(
          jsonEncode({'source': 'mapbox-dem', 'exaggeration': 1.5}));
      await _map?.flyTo(CameraOptions(pitch: 60), MapAnimationOptions());
    } else {
      await style.removeStyleTerrain();
      await _map?.flyTo(CameraOptions(pitch: 0), MapAnimationOptions());
    }
  }

  Future<void> _toggleOfflineMode() async {
    final next = !_offlineMode;
    // false → SDK ağa hiç çıkmaz; yalnızca indirilen bölgeler görünür.
    await OfflineSwitch.shared.setMapboxStackConnected(!next);
    setState(() {
      _offlineMode = next;
      _offlineGapShown = false; // her offline oturumunda bir kez uyar
    });
    _toast(next
        ? 'Mapbox ağı KAPALI — yalnız indirilen bölgeler görünür'
        : 'Mapbox ağı açık');
  }

  // --------------------------------------------------------------- offline

  /// Bir bbox'ın z0..maxZoom arasındaki yaklaşık karo sayısı (uyarı için).
  static int _estimateTiles(
      double west, double south, double east, double north, int maxZoom) {
    int lon2x(double lon, int z) => ((lon + 180) / 360 * (1 << z)).floor();
    int lat2y(double lat, int z) {
      final r = lat * math.pi / 180;
      return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) /
              2 *
              (1 << z))
          .floor();
    }

    var total = 0;
    for (var z = 0; z <= maxZoom; z++) {
      final dx = (lon2x(east, z) - lon2x(west, z)).abs() + 1;
      final dy = (lat2y(south, z) - lat2y(north, z)).abs() + 1;
      total += dx * dy;
    }
    return total;
  }

  Future<void> _downloadVisibleArea() async {
    final map = _map;
    final store = _tileStore;
    if (map == null || store == null || _offlineManager == null) return;

    // Görünen alan (eğim varsa düz kamerayla hesapla — yoksa ufka kadar uzar).
    final s = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(CameraOptions(
      center: s.center,
      zoom: s.zoom,
      bearing: s.bearing,
      pitch: 0,
    ));
    final sw = bounds.southwest.coordinates;
    final ne = bounds.northeast.coordinates;
    final west = sw.lng.toDouble(), south = sw.lat.toDouble();
    final east = ne.lng.toDouble(), north = ne.lat.toDouble();

    if (!mounted) return;
    final maxZoom = await _askMaxZoom(west, south, east, north);
    if (maxZoom == null) return;

    final id = 'bolge-${DateTime.now().millisecondsSinceEpoch}';
    final polygon = Polygon(coordinates: [
      [
        Position(west, south),
        Position(east, south),
        Position(east, north),
        Position(west, north),
        Position(west, south),
      ]
    ]);

    setState(() {
      _downloadProgress = 0;
      _downloadedBytes = 0;
    });

    try {
      // 1) Stil paketi (stil JSON, fontlar, ikonlar) — offline'da stilin açılması için.
      await _offlineManager!.loadStylePack(
        _styleUri,
        StylePackLoadOptions(
          glyphsRasterizationMode:
              GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
          acceptExpired: false,
        ),
        (_) {},
      );
      // 2) Karo bölgesi.
      await store.loadTileRegion(
        id,
        TileRegionLoadOptions(
          geometry: polygon.toJson(),
          descriptorsOptions: [
            TilesetDescriptorOptions(
              styleURI: _styleUri,
              minZoom: 0,
              maxZoom: maxZoom,
              // 3B arazi (DEM) stilin parçası değil, sonradan ekleniyor →
              // pakete ayrıca dahil et ki 3B çevrimdışı da çalışsın.
              // (DEM kaynağı en fazla z14 veri içerir; üstü büyütülür.)
              tilesets: const ['mapbox://mapbox.mapbox-terrain-dem-v1'],
            ),
          ],
          metadata: {
            'name': 'Bölge ${_regions.length + 1}',
            'style': _styleUri,
            'maxZoom': maxZoom,
          },
          acceptExpired: true,
          networkRestriction: NetworkRestriction.NONE,
        ),
        (p) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = p.requiredResourceCount == 0
                ? 0
                : p.completedResourceCount / p.requiredResourceCount;
            _downloadedBytes = p.completedResourceSize;
          });
        },
      );
      _toast('İndirildi: ${_mb(_downloadedBytes)}');
    } catch (e) {
      _toast('İndirme başarısız: $e');
    } finally {
      if (mounted) setState(() => _downloadProgress = null);
      await _refreshRegions();
    }
  }

  Future<int?> _askMaxZoom(
      double west, double south, double east, double north) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Görünen alanı indir — detay seviyesi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final z in const [14, 16, 18])
              Builder(builder: (context) {
                final tiles = _estimateTiles(west, south, east, north, z);
                return ListTile(
                  title: Text('z$z${switch (z) {
                    14 => ' — keşif',
                    16 => ' — arazi',
                    _ => ' — detay (bina/patika)',
                  }}'),
                  subtitle: Text('≈ $tiles karo'
                      '${tiles > 20000 ? '  ⚠️ çok büyük, yakınlaşın' : ''}'),
                  onTap: () => Navigator.of(context).pop(z),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRegion(TileRegion r) async {
    await _tileStore?.removeRegion(r.id);
    await _refreshRegions();
  }

  // ------------------------------------------------------------------- UI

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    if (AppConstants.mapboxAccessToken.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mapbox (deneme)')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Mapbox anahtarı yok.\n\nUygulamayı şöyle çalıştırın:\n'
            'flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxxxx',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox (deneme)'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers),
            initialValue: _styleUri,
            onSelected: (uri) => setState(() => _styleUri = uri),
            itemBuilder: (_) => [
              for (final (label, uri) in _styles)
                PopupMenuItem(value: uri, child: Text(label)),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('mapbox_spike'),
            styleUri: _styleUri,
            // Sabit nesne: her setState'te yeniden verilip kamerayı sıfırlamasın.
            viewport: _initialViewport,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onCameraChangeListener: _onCameraChanged,
            onMapLoadErrorListener: _onLoadError,
          ),
          // Üst bilgi şeridi: zoom + MGRS (zoom tavanını doğrulamak için).
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'z ${_zoom.toStringAsFixed(1)}   ${CoordFormat.mgrs(_center)}'
                '${_offlineMode ? '   ⛔ AĞ KAPALI' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'Menlo', fontSize: 13),
              ),
            ),
          ),
          if (_downloadProgress != null)
            Positioned(
              top: 52,
              left: 8,
              right: 8,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Çevrimdışı indiriliyor · '
                          '${(_downloadProgress! * 100).round()}% · '
                          '${_mb(_downloadedBytes)}'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _downloadProgress),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'loc',
            tooltip: 'Konumuma git',
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: '3d',
            tooltip: '3B arazi',
            backgroundColor: _terrain ? Colors.amber : null,
            onPressed: () async {
              setState(() => _terrain = !_terrain);
              await _applyTerrain(_terrain);
            },
            child: const Text('3B'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'net',
            tooltip: 'Ağı kapat/aç (offline testi)',
            backgroundColor: _offlineMode ? Colors.redAccent : null,
            onPressed: _toggleOfflineMode,
            child: Icon(_offlineMode ? Icons.cloud_off : Icons.cloud_done),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'regions',
            tooltip: 'İndirilen bölgeler',
            onPressed: _showRegions,
            child: const Icon(Icons.folder),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'dl',
            tooltip: 'Görünen alanı indir',
            onPressed: _downloadProgress == null ? _downloadVisibleArea : null,
            child: const Icon(Icons.download),
          ),
        ],
      ),
    );
  }

  void _showRegions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _regions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz indirilen bölge yok.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final r in _regions)
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: Text(r.id),
                      subtitle: Text('${_mb(r.completedResourceSize)} · '
                          '${r.completedResourceCount}/${r.requiredResourceCount} kaynak'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _deleteRegion(r);
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
