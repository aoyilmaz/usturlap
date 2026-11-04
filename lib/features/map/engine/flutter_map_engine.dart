import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
// 'Theme' Flutter widget'ıyla çakışmasın diye prefix'li.
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr
    show Theme, ThemeReader;

import '../../../data/tiles/cached_mbtiles_provider.dart';
import '../../../data/tiles/pmtiles_vector_provider.dart';
import 'map_engine.dart';

/// flutter_map (Dart/Canvas) ile çizen motor — geçiş tamamlanana kadar varsayılan.
class FlutterMapEngine extends MapEngine {
  const FlutterMapEngine();

  @override
  MapEngineController createController() => FlutterMapEngineController();

  @override
  Widget buildView({
    Key? key,
    required MapEngineController controller,
    required ResolvedBaseLayer baseLayer,
    required List<MapOverlay> overlays,
    required MapCameraState initialCamera,
    required double minZoom,
    required double maxZoom,
    VoidCallback? onReady,
    MapCameraCallback? onCameraChanged,
    MapPointCallback? onTap,
    MapPointCallback? onLongPress,
  }) {
    return _FlutterMapEngineView(
      key: key,
      controller: controller as FlutterMapEngineController,
      baseLayer: baseLayer,
      overlays: overlays,
      initialCamera: initialCamera,
      minZoom: minZoom,
      maxZoom: maxZoom,
      onReady: onReady,
      onCameraChanged: onCameraChanged,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class FlutterMapEngineController implements MapEngineController {
  final MapController _map = MapController();
  bool _ready = false;
  MapCameraState _initial = const MapCameraState(center: LatLng(0, 0), zoom: 3);

  // Katman kimliğine göre açık kaynaklar. Katmanlar arası geçişte yeniden
  // açılmasınlar diye tutulur (ImageCache ile birlikte hızlı geçiş).
  final Map<String, CachedMbtilesTileProvider> _mbtiles = {};
  final Map<String, PmtilesVectorTileProvider> _pmtiles = {};
  final Map<String, vtr.Theme> _themes = {}; // stylePath → tema (paylaşılır)

  @override
  bool get isReady => _ready;

  @override
  MapCameraState get camera {
    if (!_ready) return _initial;
    final c = _map.camera;
    // flutter_map 'rotation' saat yönünün tersine; bearing = -rotation.
    return MapCameraState(center: c.center, zoom: c.zoom, bearing: -c.rotation);
  }

  @override
  void moveTo(LatLng center, {double? zoom}) {
    if (!_ready) return;
    _map.move(center, zoom ?? _map.camera.zoom);
  }

  @override
  void rotateTo(double bearingDeg) {
    if (!_ready) return;
    _map.rotate(-bearingDeg);
  }

  @override
  void fitBounds(GeoBounds bounds,
      {EdgeInsets padding = const EdgeInsets.all(40)}) {
    if (!_ready) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(bounds.southWest, bounds.northEast),
      padding: padding,
    ));
  }

  @override
  Future<GeoBounds?> boundsOfScreenRect(Rect rect) async {
    if (!_ready) return null;
    final c = _map.camera;
    return GeoBounds.fromPoints([
      for (final o in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight])
        c.screenOffsetToLatLng(o),
    ]);
  }

  @override
  void releaseBaseLayer(String layerId) {
    _mbtiles.remove(layerId)?.dispose();
    _pmtiles.remove(layerId)?.dispose();
  }

  @override
  void dispose() {
    for (final p in _mbtiles.values) {
      p.dispose();
    }
    for (final p in _pmtiles.values) {
      p.dispose();
    }
    _mbtiles.clear();
    _pmtiles.clear();
    _map.dispose();
  }
}

class _FlutterMapEngineView extends StatefulWidget {
  const _FlutterMapEngineView({
    super.key,
    required this.controller,
    required this.baseLayer,
    required this.overlays,
    required this.initialCamera,
    required this.minZoom,
    required this.maxZoom,
    this.onReady,
    this.onCameraChanged,
    this.onTap,
    this.onLongPress,
  });

  final FlutterMapEngineController controller;
  final ResolvedBaseLayer baseLayer;
  final List<MapOverlay> overlays;
  final MapCameraState initialCamera;
  final double minZoom;
  final double maxZoom;
  final VoidCallback? onReady;
  final MapCameraCallback? onCameraChanged;
  final MapPointCallback? onTap;
  final MapPointCallback? onLongPress;

  @override
  State<_FlutterMapEngineView> createState() => _FlutterMapEngineViewState();
}

class _FlutterMapEngineViewState extends State<_FlutterMapEngineView> {
  final Set<String> _opening = {}; // açılmakta olan PMTiles katmanları

  FlutterMapEngineController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c._initial = widget.initialCamera;
  }

  /// PMTiles sağlayıcısı + teması async açılır; hazır olunca yeniden çizilir.
  Future<void> _openPmtiles(PmtilesBaseLayer l) async {
    if (_opening.contains(l.id)) return;
    _opening.add(l.id);
    try {
      // pmtiles dosyadan range-okur → büyük dosya belleğe yüklenmez.
      final provider = await PmtilesVectorTileProvider.open(l.path);
      if (!_c._themes.containsKey(l.stylePath)) {
        final jsonStr = await rootBundle.loadString(l.stylePath);
        _c._themes[l.stylePath] = vtr.ThemeReader()
            .read(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
      if (!mounted) {
        await provider.dispose();
        return;
      }
      setState(() => _c._pmtiles[l.id] = provider);
    } finally {
      _opening.remove(l.id);
    }
  }

  Widget _buildBaseLayer() {
    final base = widget.baseLayer;
    switch (base) {
      case NoBaseLayer():
        return const SizedBox.shrink();
      case RasterUrlBaseLayer():
        return TileLayer(
          key: ValueKey('tile_${base.id}'),
          urlTemplate: base.urlTemplate,
          additionalOptions: base.additionalOptions,
          userAgentPackageName: _userAgent,
          tileDimension: base.tileDimension,
          zoomOffset: base.zoomOffset,
          // Kaynağın sınırının üstünde son karo büyütülür (boş karo yok).
          maxNativeZoom: base.maxNativeZoom,
        );
      case MbtilesBaseLayer():
        final provider = _c._mbtiles.putIfAbsent(
          base.id,
          () => CachedMbtilesTileProvider.fromPath(
              path: base.path, silenceTileNotFound: true),
        );
        return TileLayer(
          // Benzersiz key: katman değişince taze TileLayer kurulur, eski
          // katmanın karoları tamponda kalıp sızmaz (topo'da uydu görünmesi).
          key: ValueKey('tile_${base.id}'),
          tileProvider: provider,
          maxNativeZoom: base.maxNativeZoom,
          // Anlık göster (fade yok) + daha fazla karoyu tut → geçişler hızlı.
          tileDisplay: const TileDisplay.instantaneous(),
          keepBuffer: 4,
          panBuffer: 2,
        );
      case PmtilesBaseLayer():
        final provider = _c._pmtiles[base.id];
        final theme = _c._themes[base.stylePath];
        if (provider == null || theme == null) {
          _openPmtiles(base);
          return const SizedBox.shrink();
        }
        // Vektör: sonsuz büyütme (overzoom) ile her zoom'da keskin.
        return VectorTileLayer(
          key: ValueKey('vec_${base.id}'),
          tileProviders: TileProviders({'protomaps': provider}),
          theme: theme,
          tileOffset: TileOffset.DEFAULT,
          maximumZoom: 22,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attribution = widget.baseLayer.attribution;
    return FlutterMap(
      mapController: _c._map,
      options: MapOptions(
        initialCenter: widget.initialCamera.center,
        initialZoom: widget.initialCamera.zoom,
        initialRotation: -widget.initialCamera.bearing,
        minZoom: widget.minZoom,
        maxZoom: widget.maxZoom,
        onMapReady: () {
          _c._ready = true;
          widget.onReady?.call();
        },
        onPositionChanged: (camera, hasGesture) => widget.onCameraChanged?.call(
          MapCameraState(
              center: camera.center,
              zoom: camera.zoom,
              bearing: -camera.rotation),
          hasGesture,
        ),
        onTap: widget.onTap == null ? null : (_, p) => widget.onTap!(p),
        onLongPress:
            widget.onLongPress == null ? null : (_, p) => widget.onLongPress!(p),
      ),
      children: [
        _buildBaseLayer(),
        ...buildFlutterMapOverlayLayers(widget.overlays),
        if (attribution != null)
          RichAttributionWidget(
            attributions: [TextSourceAttribution(attribution)],
          ),
      ],
    );
  }
}

/// İşaretçi görünümüne döndürme + dokunma ekler (flutter_map'te widget olarak).
Widget _markerChild(MapMarker m) {
  Widget w = m.child;
  final r = m.rotationDeg;
  if (r != null) w = Transform.rotate(angle: r * math.pi / 180.0, child: w);
  if (m.onTap != null) w = GestureDetector(onTap: m.onTap, child: w);
  return w;
}

/// OSM vb. karo sunucularına gönderilen tanımlayıcı.
const String _userAgent = 'com.kerteriz.app';

/// Overlay listesini flutter_map katmanlarına çevirir. Ardışık aynı türdeki
/// öğeler tek katmanda toplanır; liste sırası (alttan üste) korunur.
@visibleForTesting
List<Widget> buildFlutterMapOverlayLayers(List<MapOverlay> overlays) {
  final layers = <Widget>[];
  var i = 0;
  while (i < overlays.length) {
    final type = overlays[i].runtimeType;
    var j = i;
    while (j < overlays.length && overlays[j].runtimeType == type) {
      j++;
    }
    final group = overlays.sublist(i, j);
    switch (group.first) {
      case MapLine():
        layers.add(PolylineLayer(polylines: [
          for (final l in group.cast<MapLine>())
            Polyline(points: l.points, strokeWidth: l.width, color: l.color),
        ]));
      case MapArea():
        layers.add(PolygonLayer(polygons: [
          for (final a in group.cast<MapArea>())
            Polygon(
              points: a.points,
              color: a.fillColor,
              borderColor: a.strokeColor,
              borderStrokeWidth: a.strokeWidth,
            ),
        ]));
      case MapCircle():
        layers.add(CircleLayer(circles: [
          for (final c in group.cast<MapCircle>())
            CircleMarker(
              point: c.center,
              radius: c.radiusMeters,
              useRadiusInMeter: true,
              color: c.fillColor,
              borderColor: c.strokeColor,
              borderStrokeWidth: c.strokeWidth,
            ),
        ]));
      case MapMarker():
        layers.add(MarkerLayer(markers: [
          for (final m in group.cast<MapMarker>())
            Marker(
              key: ValueKey(m.id),
              point: m.point,
              width: m.width,
              height: m.height,
              child: _markerChild(m),
            ),
        ]));
    }
    i = j;
  }
  return layers;
}
