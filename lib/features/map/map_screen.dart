import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
// 'Theme' Flutter widget'ıyla çakışmasın diye prefix'li.
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr
    show Theme, ThemeReader;

import '../../core/constants.dart';
import '../../core/coord_format.dart';
import '../../core/geo_math.dart';
import '../../data/tiles/cached_mbtiles_provider.dart';
import '../../data/tiles/mbtiles_asset_loader.dart';
import '../../data/tiles/pmtiles_vector_provider.dart';
import '../../domain/models/contact.dart';
import '../../domain/models/track.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../hud/callsign_hud.dart';
import '../tools/tool_banner.dart';
import '../tools/tools_palette.dart';
import '../tracks/track_list_sheet.dart';
import '../waypoints/add_waypoint_dialog.dart';
import '../waypoints/waypoint_list_sheet.dart';
import 'base_layer.dart';

/// Adım 3 — çevrimdışı/çevrimiçi harita + kendi konum işaretçisi + HUD +
/// kuzey/track-up modu + takip.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final Map<String, CachedMbtilesTileProvider> _providers = {};
  final Map<String, PmtilesVectorTileProvider> _vectorProviders = {};
  final Map<String, vtr.Theme> _themes = {}; // stylePath → tema (paylaşılır)
  final Map<String, LatLngBounds> _layerBounds = {};
  final Set<String> _loadingLayers = {};

  /// FlutterMap hazır mı (kamera erişimi güvenli mi).
  bool _mapReady = false;

  late BaseLayerDef _selected;
  late Future<void> _ready;

  /// Harita kendi konumumuzu otomatik takip etsin mi.
  bool _follow = true;

  /// true: track-up (harita hareket yönüne döner), false: kuzey-yukarı.
  bool _trackUp = false;

  @override
  void initState() {
    super.initState();
    _selected = kBaseLayers.firstWhere(
      (l) => l.type == BaseLayerSourceType.offlineMbtiles,
      orElse: () => kBaseLayers.first,
    );
    // Açılışta yalnızca varsayılan katmanı yükle (büyük topo'yu değil).
    _ready = _ensureProvider(_selected);
  }

  /// Bir çevrimdışı katmanın sağlayıcısını (gerekirse) tembel yükler — MBTiles
  /// (raster) ya da PMTiles (vektör). Büyük asset'ler yalnızca seçilince kopyalanır.
  Future<void> _ensureProvider(BaseLayerDef layer) async {
    final isMbtiles = layer.type == BaseLayerSourceType.offlineMbtiles;
    final isVector = layer.type == BaseLayerSourceType.vectorPmtiles;
    if (!isMbtiles && !isVector) return;
    final loaded = isMbtiles
        ? _providers.containsKey(layer.id)
        : _vectorProviders.containsKey(layer.id);
    if (loaded || _loadingLayers.contains(layer.id)) return;

    _loadingLayers.add(layer.id);
    try {
      final path = await MbtilesAssetLoader.ensureLocalCopy(layer.assetPath!);
      if (!mounted) return;
      if (isMbtiles) {
        final provider = CachedMbtilesTileProvider.fromPath(
          path: path,
          silenceTileNotFound: true,
        );
        LatLngBounds? bounds;
        try {
          final b = provider.mbtiles.getMetadata().bounds;
          if (b != null) {
            bounds =
                LatLngBounds(LatLng(b.bottom, b.left), LatLng(b.top, b.right));
          }
        } catch (_) {/* metadata eksikse yok say */}
        setState(() {
          _providers[layer.id] = provider;
          if (bounds != null) _layerBounds[layer.id] = bounds;
        });
      } else {
        // Vektör (PMTiles): provider + Protomaps teması.
        final provider = await PmtilesVectorTileProvider.open(path);
        final theme = await _ensureTheme(layer.stylePath!);
        if (!mounted) {
          await provider.dispose();
          return;
        }
        setState(() {
          _vectorProviders[layer.id] = provider;
          _themes[layer.stylePath!] = theme;
        });
      }
      _recenterToLayer(layer);
    } finally {
      _loadingLayers.remove(layer.id);
    }
  }

  /// MapLibre stil JSON'unu okuyup vektör temasını üretir (stilPath başına önbellek).
  Future<vtr.Theme> _ensureTheme(String stylePath) async {
    final cached = _themes[stylePath];
    if (cached != null) return cached;
    final jsonStr = await rootBundle.loadString(stylePath);
    return vtr.ThemeReader().read(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  /// Seçili çevrimdışı katmanın kapsama alanı mevcut görünümün dışındaysa
  /// haritayı oraya götürür (bounds'a sığdırır; bounds yoksa manuel center).
  void _recenterToLayer(BaseLayerDef layer) {
    if (!_mapReady || layer.id != _selected.id) return;
    final b = _layerBounds[layer.id];
    if (b != null) {
      if (b.contains(_mapController.camera.center)) return; // zaten kapsamda
      setState(() => _follow = false);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(40)),
      );
      return;
    }
    final c = layer.center;
    if (c != null) {
      setState(() => _follow = false);
      _mapController.move(c, 13);
    }
  }

  @override
  void dispose() {
    for (final p in _providers.values) {
      p.dispose();
    }
    for (final p in _vectorProviders.values) {
      p.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  /// Yeni konum/kerteriz geldiğinde haritayı (takip/track-up açıksa) güncelle.
  void _onSelfUpdate(Contact c) {
    if (_follow) {
      _mapController.move(c.position, _mapController.camera.zoom);
    }
    if (_trackUp && c.headingDeg != null) {
      _mapController.rotate(-c.headingDeg!);
    }
  }

  Widget _buildActiveTileLayer() {
    switch (_selected.type) {
      case BaseLayerSourceType.offlineMbtiles:
        final provider = _providers[_selected.id];
        // Henüz yüklenmediyse (tembel) boş bırak; üstte yükleme göstergesi var.
        if (provider == null) return const SizedBox.shrink();
        return TileLayer(
          // Benzersiz key: katman değişince taze TileLayer kurulur, eski
          // katmanın karoları tamponda kalıp sızmaz (topo'da uydu görünmesi).
          key: ValueKey('tile_${_selected.id}'),
          tileProvider: provider,
          maxNativeZoom: _selected.maxNativeZoom ?? 19,
          // Anlık göster (fade yok) + daha fazla karoyu tut → geçişler hızlı.
          tileDisplay: const TileDisplay.instantaneous(),
          keepBuffer: 4,
          panBuffer: 2,
        );
      case BaseLayerSourceType.vectorPmtiles:
        final provider = _vectorProviders[_selected.id];
        final theme = _themes[_selected.stylePath];
        if (provider == null || theme == null) return const SizedBox.shrink();
        // Vektör: sonsuz büyütme (overzoom) ile her zoom'da keskin.
        return VectorTileLayer(
          key: ValueKey('vec_${_selected.id}'),
          tileProviders: TileProviders({'protomaps': provider}),
          theme: theme,
          tileOffset: TileOffset.DEFAULT,
        );
      case BaseLayerSourceType.onlineOsm:
        return TileLayer(
          key: const ValueKey('tile_online_osm'),
          urlTemplate: AppConstants.osmTileUrl,
          userAgentPackageName: AppConstants.osmUserAgent,
        );
      case BaseLayerSourceType.missing:
        return const SizedBox.shrink();
    }
  }

  /// Kendi konum işaretçisi: kerteriz varsa ok, yoksa nokta.
  Marker _selfMarker(Contact self) {
    final heading = self.headingDeg;
    return Marker(
      point: self.position,
      width: 44,
      height: 44,
      child: heading == null
          ? const Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 28)
          : Transform.rotate(
              angle: heading * math.pi / 180.0,
              child: const Icon(Icons.navigation,
                  color: Colors.lightBlueAccent, size: 34),
            ),
    );
  }

  /// Kayıtlı bir waypoint'in işaretçisi (dokun → detay/sil).
  Marker _waypointMarker(Waypoint wp) {
    return Marker(
      point: wp.position,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showWaypointDetail(wp),
        child:
            const Icon(Icons.location_on, color: Colors.redAccent, size: 36),
      ),
    );
  }

  /// Aktif ölçüm/çizim aracı için harita katmanları (polyline/poligon/sektör).
  List<Widget> _buildToolLayers(ToolState tool) {
    if (!tool.active || !tool.visible || tool.points.isEmpty) return const [];
    final pts = tool.points;
    const amber = Colors.amber;
    final fill = amber.withValues(alpha: 0.25);
    final layers = <Widget>[];

    switch (tool.mode) {
      case ToolMode.distance:
        if (pts.length >= 2) {
          layers.add(PolylineLayer(polylines: [
            Polyline(points: pts, strokeWidth: 4, color: amber),
          ]));
        }
        break;
      case ToolMode.polygon:
        if (pts.length >= 3) {
          layers.add(PolygonLayer(polygons: [
            Polygon(
                points: pts,
                color: fill,
                borderColor: amber,
                borderStrokeWidth: 3),
          ]));
        } else if (pts.length == 2) {
          layers.add(PolylineLayer(polylines: [
            Polyline(points: pts, strokeWidth: 4, color: amber),
          ]));
        }
        break;
      case ToolMode.sector:
        if (pts.length == 2) {
          layers.add(PolylineLayer(polylines: [
            Polyline(points: pts, strokeWidth: 3, color: amber),
          ]));
        } else if (pts.length >= 3) {
          final r = GeoMath.distance(pts[0], pts[1]);
          final b1 = GeoMath.bearing(pts[0], pts[1]);
          final b2 = GeoMath.bearing(pts[0], pts[2]);
          layers.add(PolygonLayer(polygons: [
            Polygon(
                points: GeoMath.sectorPolygon(pts[0], r, b1, b2),
                color: fill,
                borderColor: amber,
                borderStrokeWidth: 3),
          ]));
        }
        break;
      case ToolMode.none:
        break;
    }

    // Dokunulan köşeleri küçük noktalarla göster.
    layers.add(MarkerLayer(
      markers: [
        for (final p in pts)
          Marker(
            point: p,
            width: 14,
            height: 14,
            child: Container(
              decoration: BoxDecoration(
                color: amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54, width: 1.5),
              ),
            ),
          ),
      ],
    ));
    return layers;
  }

  /// Haritayı bir noktaya ortalar (ve otomatik takibi bırakır).
  void _centerOn(LatLng p) {
    setState(() => _follow = false);
    _mapController.move(p, _mapController.camera.zoom);
  }

  /// Haritayı bir izin tamamını gösterecek şekilde sığdırır.
  void _fitTrack(List<TrackPoint> points) {
    if (points.isEmpty) return;
    setState(() => _follow = false);
    if (points.length == 1) {
      _mapController.move(points.first.position, _mapController.camera.zoom);
      return;
    }
    final bounds = LatLngBounds.fromPoints([for (final p in points) p.position]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  void _showWaypointDetail(Waypoint wp) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(wp.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(CoordFormat.format(wp.position, ref.read(coordFormatProvider)),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(CoordFormat.wgs84(wp.position),
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (wp.note != null && wp.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(wp.note!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _centerOn(wp.position);
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Ortala'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(waypointRepositoryProvider).delete(wp.id!);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Sil'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recenter() {
    final self = ref.read(selfContactProvider);
    setState(() => _follow = true);
    if (self != null) {
      _mapController.move(self.position, _mapController.camera.zoom);
    }
  }

  void _toggleOrientation() {
    setState(() => _trackUp = !_trackUp);
    if (!_trackUp) {
      _mapController.rotate(0); // kuzey-yukarı
    } else {
      final self = ref.read(selfContactProvider);
      if (self?.headingDeg != null) _mapController.rotate(-self!.headingDeg!);
    }
  }

  void _onLayerTapped(BaseLayerDef layer) {
    Navigator.of(context).pop();
    if (!layer.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '“${layer.label}” için henüz MBTiles yok. '
            'assets/tiles/ içine dosyayı ekleyip base_layer.dart\'a tanımlayınca aktif olur.',
          ),
        ),
      );
      return;
    }
    setState(() => _selected = layer);
    // Katmanı (gerekirse) tembel yükle — büyük topo yalnızca seçilince kopyalanır.
    // (Yükleme bitince _ensureProvider zaten kapsama alanına götürür.)
    _ensureProvider(layer);
    // Zaten yüklüyse hemen kapsama alanına git (tekrar girememe sorunu).
    _recenterToLayer(layer);
  }

  /// Tek birleşik menü: veri & araçlar + harita katmanı + görünüm ayarları.
  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final tool = ref.watch(toolProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('Menü',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),

                // --- Veri & araçlar ---
                ListTile(
                  leading: const Icon(Icons.straighten),
                  title: const Text('Ölçüm / çizim araçları'),
                  subtitle: Text(tool.active
                      ? 'aktif: ${_toolLabel(tool.mode)}'
                      : 'mesafe · alan · sektör'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showToolsPalette(context, ref);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Waypoint\'ler'),
                  subtitle: const Text('uzun bas → ekle; listele/sil'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showWaypointListSheet(context, ref,
                        onTapWaypoint: (wp) => _centerOn(wp.position));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.route),
                  title: const Text('İzler'),
                  subtitle: const Text('kayıtlı rotalar; göster/paylaş/sil'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showTrackListSheet(context, ref);
                  },
                ),

                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('Harita katmanı',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white70)),
                ),
                for (final layer in kBaseLayers)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 2),
                    leading: Icon(layer.icon,
                        color: layer.isAvailable ? null : Colors.grey),
                    title: Text(
                      layer.label,
                      style: TextStyle(
                        color: layer.isAvailable ? null : Colors.grey,
                        fontWeight: layer.id == _selected.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: layer.isAvailable
                        ? null
                        : const Text('henüz eklenmedi'),
                    trailing: layer.id == _selected.id
                        ? const Icon(Icons.check,
                            color: Colors.lightGreenAccent)
                        : null,
                    onTap: () => _onLayerTapped(layer),
                  ),

                const Divider(),
                // --- Görünüm ayarları ---
                Consumer(builder: (context, ref, _) {
                  final night = ref.watch(nightModeProvider);
                  return SwitchListTile(
                    secondary: Icon(
                        night
                            ? Icons.nightlight_round
                            : Icons.nightlight_outlined,
                        color: night ? Colors.redAccent : null),
                    title: const Text('Gece modu'),
                    subtitle: const Text('Düşük ışık — kırmızı tonlama'),
                    value: night,
                    onChanged: (_) =>
                        ref.read(nightModeProvider.notifier).toggle(),
                  );
                }),
                Consumer(builder: (context, ref, _) {
                  final on = ref.watch(accuracyFilterProvider);
                  return SwitchListTile(
                    secondary: const Icon(Icons.gps_fixed),
                    title: const Text('Track doğruluk filtresi'),
                    subtitle:
                        const Text('Düşük doğruluklu (>20 m) noktaları atla'),
                    value: on,
                    onChanged: (_) =>
                        ref.read(accuracyFilterProvider.notifier).toggle(),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _toolLabel(ToolMode m) {
    switch (m) {
      case ToolMode.distance:
        return 'mesafe';
      case ToolMode.polygon:
        return 'alan';
      case ToolMode.sector:
        return 'sektör';
      case ToolMode.none:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yeni konum geldikçe haritayı güncelle (takip/track-up).
    ref.listen<Contact?>(selfContactProvider, (prev, next) {
      if (next != null) _onSelfUpdate(next);
    });
    // Listeden bir iz seçilince haritada ona odaklan.
    ref.listen(displayedTrackPointsProvider, (prev, next) {
      final pts = next.value ?? const <TrackPoint>[];
      _fitTrack(pts);
    });

    final self = ref.watch(selfContactProvider);
    final waypoints = ref.watch(waypointsProvider).value ?? const <Waypoint>[];
    final recording = ref.watch(recordingProvider);
    final currentTrack =
        ref.watch(currentTrackPointsProvider).value ?? const <TrackPoint>[];
    final displayedTrack =
        ref.watch(displayedTrackPointsProvider).value ?? const <TrackPoint>[];
    final tool = ref.watch(toolProvider);
    final nightMode = ref.watch(nightModeProvider);
    // Seçili çevrimdışı katman henüz yüklenmediyse (tembel) göstergede uyar.
    final layerLoading = (_selected.type ==
                BaseLayerSourceType.offlineMbtiles &&
            !_providers.containsKey(_selected.id)) ||
        (_selected.type == BaseLayerSourceType.vectorPmtiles &&
            (!_vectorProviders.containsKey(_selected.id) ||
                !_themes.containsKey(_selected.stylePath)));

    return Scaffold(
      body: _wrapNight(
        nightMode,
        Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _ready,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          'Çevrimdışı karolar yüklenemedi:\n${snapshot.error}',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: AppConstants.initialCenter,
                    initialZoom: AppConstants.initialZoom,
                    minZoom: AppConstants.minZoom,
                    maxZoom: AppConstants.maxZoom,
                    onMapReady: () => _mapReady = true,
                    // Kullanıcı elle kaydırınca takibi bırak.
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture && _follow) {
                        setState(() => _follow = false);
                      }
                    },
                    // Tek dokun → araç aktifse nokta koy.
                    onTap: (tapPosition, point) {
                      if (ref.read(toolProvider).active) {
                        HapticFeedback.selectionClick();
                        ref.read(toolProvider.notifier).addPoint(point);
                      }
                    },
                    // Uzun bas → waypoint ekle.
                    onLongPress: (tapPosition, point) {
                      HapticFeedback.mediumImpact();
                      showAddWaypointDialog(context, ref, point);
                    },
                  ),
                  children: [
                    _buildActiveTileLayer(),
                    // Aktif ölçüm/çizim aracı katmanları.
                    ..._buildToolLayers(tool),
                    // Seçili kayıtlı iz (camgöbeği).
                    if (displayedTrack.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [for (final p in displayedTrack) p.position],
                          strokeWidth: 4,
                          color: Colors.cyanAccent,
                        ),
                      ]),
                    // Kayıttaki canlı iz (turuncu).
                    if (currentTrack.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [for (final p in currentTrack) p.position],
                          strokeWidth: 4,
                          color: Colors.orangeAccent,
                        ),
                      ]),
                    MarkerLayer(
                      markers: [for (final wp in waypoints) _waypointMarker(wp)],
                    ),
                    if (self != null)
                      MarkerLayer(markers: [_selfMarker(self)]),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                            '© OpenStreetMap katkıda bulunanlar'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Katman tembel yüklenirken gösterge (ör. ilk kez büyük topo seçilince).
          if (layerLoading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Katman yükleniyor…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Gece modu: haritanın üstüne kırmızı/karartma (gece görüşü).
          // Kontrollerin altında olduğu için butonlar okunaklı kalır.
          if (nightMode)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.red.withValues(alpha: 0.20)),
              ),
            ),

          // Üst: kalıcı HUD + (araç aktifse) ölçüm şeridi
          const Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CallsignHud(),
                ToolBanner(),
              ],
            ),
          ),

          // Tüm kontroller alt-sağda tek kolon (tek elle erişim).
          // En altta birincil (ortala, kayıt), üstte ikincil (menü, pusula).
          Positioned(
            right: 16,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pusula: kuzey-yukarı / track-up
                FloatingActionButton(
                  heroTag: 'orientation',
                  mini: true,
                  onPressed: _toggleOrientation,
                  tooltip:
                      _trackUp ? 'Track-up (dokun: kuzey)' : 'Kuzey-yukarı',
                  backgroundColor: _trackUp ? Colors.blueGrey : null,
                  child: Icon(_trackUp ? Icons.navigation : Icons.explore),
                ),
                const SizedBox(height: 12),
                // Menü (araçlar/waypoint/iz/katman/ayar)
                FloatingActionButton(
                  heroTag: 'menu',
                  mini: true,
                  backgroundColor: tool.active ? Colors.amber.shade800 : null,
                  onPressed: _openMenu,
                  tooltip: 'Menü',
                  child: const Icon(Icons.menu),
                ),
                const SizedBox(height: 12),
                // Konuma ortala / takip (birincil)
                FloatingActionButton(
                  heroTag: 'recenter',
                  onPressed: _recenter,
                  tooltip: 'Konuma ortala / takip',
                  backgroundColor: _follow ? Colors.blue : null,
                  child: Icon(
                      _follow ? Icons.my_location : Icons.location_searching),
                ),
                const SizedBox(height: 12),
                // İz kaydı başlat/durdur (birincil)
                FloatingActionButton(
                  heroTag: 'record',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final n = ref.read(recordingProvider.notifier);
                    recording.isRecording ? n.stop() : n.start();
                  },
                  backgroundColor: recording.isRecording ? Colors.red : null,
                  tooltip: recording.isRecording
                      ? 'Kaydı durdur'
                      : 'İz kaydını başlat',
                  child: Icon(recording.isRecording
                      ? Icons.stop
                      : Icons.fiber_manual_record),
                ),
              ],
            ),
          ),

          // Sağ kenardan içeri kaydır → menü (§8 jest).
          // FAB kümesini engellememek için orta-sağ şeride yerleşir.
          Positioned(
            right: 0,
            top: 120,
            bottom: 320,
            width: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -100) {
                  HapticFeedback.selectionClick();
                  _openMenu();
                }
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Gece modunda FAB'ları kırmızı tonlar (gece görüşü).
  Widget _wrapNight(bool night, Widget child) {
    if (!night) return child;
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF7F1D1D),
          foregroundColor: Color(0xFFFECACA),
        ),
      ),
      child: child,
    );
  }
}
