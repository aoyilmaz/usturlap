import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide MapEvent, Size;

import 'map_engine.dart';
import 'mapbox_geojson.dart';
import 'mapbox_night_style.dart';
import 'widget_rasterizer.dart';

/// Mapbox Maps SDK (native, GPU) ile çizen motor.
///
/// - Uydu: Mapbox `satellite-streets` stili (vektör etiketler, z22).
/// - Diğer internet karoları (OSM/Topo): boş stil + raster kaynak.
/// - Overlay'ler: 3 GeoJSON kaynağı (alan < çizgi < işaretçi).
/// - İşaretçiler: widget bir kez PNG'ye çevrilir → sembol katmanı (native, akıcı).
/// - Dosya tabanlı katmanlar (MBTiles/PMTiles) henüz desteklenmez (plan adım 6);
///   harita ekranı bu katmanlarda klasik motora geçer.
class MapboxEngine extends MapEngine {
  const MapboxEngine();

  /// Bu motor taban katmanı çizebilir mi?
  static bool supports(ResolvedBaseLayer layer) =>
      layer is RasterUrlBaseLayer || layer is NoBaseLayer;

  @override
  MapEngineController createController() => MapboxEngineController();

  @override
  bool get supportsTerrain => true;

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
    bool terrain3d = false,
    bool nightMode = false,
  }) {
    return _MapboxEngineView(
      key: key,
      controller: controller as MapboxEngineController,
      baseLayer: baseLayer,
      overlays: overlays,
      initialCamera: initialCamera,
      minZoom: minZoom,
      maxZoom: maxZoom,
      onReady: onReady,
      onCameraChanged: onCameraChanged,
      onTap: onTap,
      onLongPress: onLongPress,
      terrain3d: terrain3d,
      nightMode: nightMode,
    );
  }
}

Point _pt(LatLng p) => Point(coordinates: Position(p.longitude, p.latitude));
LatLng _ll(Point p) =>
    LatLng(p.coordinates.lat.toDouble(), p.coordinates.lng.toDouble());

class MapboxEngineController implements MapEngineController {
  MapboxMap? _map;
  MapCameraState _camera =
      const MapCameraState(center: LatLng(0, 0), zoom: 3);

  /// imageKey → PNG; stil değişse de tekrar resme çevrilmesin.
  final Map<String, Uint8List> _png = {};

  @override
  bool get isReady => _map != null;

  @override
  MapCameraState get camera => _camera;

  @override
  void moveTo(LatLng center, {double? zoom}) {
    _map?.setCamera(CameraOptions(center: _pt(center), zoom: zoom));
  }

  @override
  void rotateTo(double bearingDeg) {
    _map?.setCamera(CameraOptions(bearing: bearingDeg));
  }

  @override
  void fitBounds(GeoBounds bounds,
      {EdgeInsets padding = const EdgeInsets.all(40)}) {
    final map = _map;
    if (map == null) return;
    () async {
      final cam = await map.cameraForCoordinatesPadding(
        [_pt(bounds.southWest), _pt(bounds.northEast)],
        CameraOptions(bearing: _camera.bearing, pitch: 0),
        MbxEdgeInsets(
          top: padding.top,
          left: padding.left,
          bottom: padding.bottom,
          right: padding.right,
        ),
        null,
        null,
      );
      await map.easeTo(cam, MapAnimationOptions(duration: 600));
    }();
  }

  @override
  Future<GeoBounds?> boundsOfScreenRect(Rect rect) async {
    final map = _map;
    if (map == null) return null;
    final pts = <LatLng>[];
    for (final o in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      pts.add(_ll(await map.coordinateForPixel(ScreenCoordinate(x: o.dx, y: o.dy))));
    }
    return GeoBounds.fromPoints(pts);
  }

  @override
  void releaseBaseLayer(String layerId) {
    // Dosya tabanlı katman açmıyoruz (henüz) → serbest bırakılacak kaynak yok.
  }

  @override
  void dispose() {
    _map = null;
    _png.clear();
  }
}

// Kaynak/katman kimlikleri (stilde çakışmasın diye 'pz-' önekli).
const _srcAreas = 'pz-areas';
const _srcLines = 'pz-lines';
const _srcMarkers = 'pz-markers';
const _layerMarkers = 'pz-markers';
const _srcDem = 'pz-dem';
const _layerSky = 'pz-sky';

/// Uygulamanın kendi katmanları — gece stili bunlara dokunmaz.
const _ownLayers = {
  'pz-areas-fill',
  'pz-areas-line',
  'pz-lines',
  _layerMarkers,
  // pz-sky bilerek yok: gece modunda gökyüzü de söndürülür.
};

/// Taban katmana göre stil: ya Mapbox stil adresi ya da yerel stil JSON'u.
class _StyleSpec {
  const _StyleSpec.uri(String this.uri) : json = null;
  const _StyleSpec.json(String this.json) : uri = null;
  final String? uri;
  final String? json;
  String get key => uri ?? json!;
}

const _bgLayer = {
  'id': 'pz-bg',
  'type': 'background',
  'paint': {'background-color': '#1b1f23'},
};

_StyleSpec _styleFor(ResolvedBaseLayer base) {
  if (base is RasterUrlBaseLayer) {
    if (base.id == 'online_satellite') {
      // Raster static-tiles yerine native stil: vektör yol/yer adları keskin.
      return const _StyleSpec.uri(MapboxStyles.SATELLITE_STREETS);
    }
    var url = base.urlTemplate;
    base.additionalOptions.forEach((k, v) => url = url.replaceAll('{$k}', v));
    return _StyleSpec.json(jsonEncode({
      'version': 8,
      'sources': {
        'pz-base': {
          'type': 'raster',
          'tiles': [url],
          'tileSize': base.tileDimension,
          'maxzoom': base.maxNativeZoom,
          if (base.attribution != null) 'attribution': base.attribution,
        },
      },
      'layers': [
        _bgLayer,
        {'id': 'pz-base', 'type': 'raster', 'source': 'pz-base'},
      ],
    }));
  }
  return _StyleSpec.json(
      jsonEncode({'version': 8, 'sources': {}, 'layers': [_bgLayer]}));
}

class _MapboxEngineView extends StatefulWidget {
  const _MapboxEngineView({
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
    this.terrain3d = false,
    this.nightMode = false,
  });

  final MapboxEngineController controller;
  final ResolvedBaseLayer baseLayer;
  final List<MapOverlay> overlays;
  final MapCameraState initialCamera;
  final double minZoom;
  final double maxZoom;
  final VoidCallback? onReady;
  final MapCameraCallback? onCameraChanged;
  final MapPointCallback? onTap;
  final MapPointCallback? onLongPress;
  final bool terrain3d;
  final bool nightMode;

  @override
  State<_MapboxEngineView> createState() => _MapboxEngineViewState();
}

class _MapboxEngineViewState extends State<_MapboxEngineView> {
  late final CameraViewportState _initialViewport;
  late _StyleSpec _style;
  final List<StreamSubscription<Object?>> _subs = [];

  bool _styleReady = false;
  bool _layersAdded = false;
  final Set<String> _imagesInStyle = {};
  MapboxOverlayData? _data;
  double _dpr = 3;

  // Overlay senkronu: aynı anda tek iş; arada gelen güncellemeler birleştirilir.
  bool _syncing = false;
  bool _pending = false;

  MapboxEngineController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    final cam = widget.initialCamera;
    _c._camera = cam;
    _initialViewport = CameraViewportState(
      center: _pt(cam.center),
      zoom: cam.zoom,
      bearing: cam.bearing,
    );
    _style = _styleFor(widget.baseLayer);
  }

  @override
  void didUpdateWidget(covariant _MapboxEngineView old) {
    super.didUpdateWidget(old);
    final next = _styleFor(widget.baseLayer);
    if (next.key != _style.key) {
      _style = next;
      _loadStyle(); // yükleninince 3B/gece yeniden uygulanır
    } else if (old.nightMode != widget.nightMode) {
      // Gündüze dönüş: orijinal renkleri geri almanın en sağlam yolu stili
      // yeniden yüklemek (overlay'ler onStyleLoaded'da yeniden kurulur).
      if (widget.nightMode) {
        _applyNight();
      } else {
        _loadStyle();
      }
    }
    if (old.terrain3d != widget.terrain3d) {
      _applyTerrain(widget.terrain3d, animate: true);
    }
    if (!identical(old.overlays, widget.overlays)) _scheduleSync();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _c._map = null;
    super.dispose();
  }

  Future<void> _loadStyle() async {
    final map = _c._map;
    if (map == null) return;
    _styleReady = false;
    if (_style.uri != null) {
      await map.loadStyleURI(_style.uri!);
    } else {
      await map.loadStyleJson(_style.json!);
    }
  }

  Future<void> _onCreated(MapboxMap map) async {
    _c._map = map;
    await map.setBounds(
        CameraBoundsOptions(minZoom: widget.minZoom, maxZoom: widget.maxZoom));
    // Pusula/ölçek uygulamanın kendi kontrollerinde; Mapbox logo+atıf kalır.
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // İşaretçiye dokunma (haritaya dokunmadan önce yakalanır).
    map.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _layerMarkers), (f, _) {
        final id = f.properties['id'];
        if (id is String) _data?.markerById[id]?.onTap?.call();
      }),
      interactionID: 'pz-marker-tap',
    );
    map.addInteraction(
      TapInteraction.onMap((ctx) => widget.onTap?.call(_ll(ctx.point)),
          stopPropagation: false),
      interactionID: 'pz-map-tap',
    );
    map.addInteraction(
      LongTapInteraction.onMap(
          (ctx) => widget.onLongPress?.call(_ll(ctx.point))),
      interactionID: 'pz-map-longtap',
    );

    // Kullanıcı jesti → "elle kaydırıldı" (takibi bırakmak için).
    final g = map.gestures;
    for (final stream in [
      g.pan.gestureEvents,
      g.zoom.gestureEvents,
      g.rotate.gestureEvents,
      g.pitch.gestureEvents,
    ]) {
      _subs.add(stream.listen(
          (_) => widget.onCameraChanged?.call(_c._camera, true)));
    }

    // İlk stil: adres ise MapWidget zaten yüklüyor; JSON ise biz yükleriz.
    if (_style.json != null) await _loadStyle();
    widget.onReady?.call();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    // Stil değişince eklediğimiz kaynak/katman/resimler silinir → yeniden kur.
    _styleReady = true;
    _layersAdded = false;
    _imagesInStyle.clear();
    try {
      if (widget.terrain3d) await _applyTerrain(true, animate: false);
      if (widget.nightMode) await _applyNight();
    } catch (e) {
      debugPrint('Mapbox stil eki hatası: $e');
    }
    _scheduleSync();
  }

  /// 3B arazi: Mapbox yükseklik verisi (DEM) + gökyüzü; açınca kamera eğilir.
  Future<void> _applyTerrain(bool on, {required bool animate}) async {
    final map = _c._map;
    if (map == null || !_styleReady) return;
    if (on) {
      if (!await map.styleSourceExists(_srcDem)) {
        await map.addSource(RasterDemSource(
          id: _srcDem,
          url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
          tileSize: 514,
          maxzoom: 14,
        ));
      }
      await map.setStyleTerrain(
          jsonEncode({'source': _srcDem, 'exaggeration': 1.5}));
      if (!widget.nightMode && !await map.styleLayerExists(_layerSky)) {
        await map.addStyleLayer(
            jsonEncode({
              'id': _layerSky,
              'type': 'sky',
              'paint': {
                'sky-type': 'atmosphere',
                'sky-atmosphere-sun-intensity': 12,
              },
            }),
            null);
      }
      if (animate) {
        await map.easeTo(
            CameraOptions(pitch: 60), MapAnimationOptions(duration: 800));
      }
    } else {
      await map.removeStyleTerrain();
      if (await map.styleLayerExists(_layerSky)) {
        await map.removeStyleLayer(_layerSky);
      }
      if (animate) {
        await map.easeTo(
            CameraOptions(pitch: 0), MapAnimationOptions(duration: 600));
      }
    }
  }

  /// Gece stili: stil katmanlarını karart/kırmızıya çevir (bkz. mapbox_night_style).
  Future<void> _applyNight() async {
    final map = _c._map;
    if (map == null || !_styleReady) return;
    final infos = await map.getStyleLayers();
    final edits = nightStyleEdits(
      [for (final i in infos) if (i != null) (id: i.id, type: i.type)],
      keep: _ownLayers,
    );
    for (final e in edits) {
      try {
        await map.setStyleLayerProperty(e.layerId, e.property, e.value);
      } catch (_) {
        // Bazı katmanlar özelliği desteklemeyebilir — atla.
      }
    }
  }

  void _onCamera(CameraChangedEventData e) {
    final s = e.cameraState;
    _c._camera = MapCameraState(
      center: _ll(s.center),
      zoom: s.zoom,
      bearing: s.bearing,
    );
    widget.onCameraChanged?.call(_c._camera, false);
  }

  Future<void> _scheduleSync() async {
    if (_syncing) {
      _pending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _pending = false;
        await _sync();
      } while (_pending && mounted);
    } catch (e) {
      debugPrint('Mapbox overlay senkron hatası: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _sync() async {
    final map = _c._map;
    if (map == null || !_styleReady || !mounted) return;
    final data = MapboxOverlayData.from(widget.overlays);
    _data = data;

    // 1) İşaretçi resimleri (yalnızca stilde olmayanlar).
    for (final m in data.markerById.values) {
      if (_imagesInStyle.contains(m.imageKey)) continue;
      final png = _c._png[m.imageKey] ??= Uint8List.fromList(
        await rasterizeWidgetToPng(m.child,
            size: Size(m.width, m.height), pixelRatio: _dpr),
      );
      await map.addImage(m.imageKey, _dpr, StyleImage.bytes(png));
      _imagesInStyle.add(m.imageKey);
    }

    // 2) Kaynak + katmanlar (stil başına bir kez), sonra yalnızca veri.
    if (!_layersAdded) {
      await _addSourcesAndLayers(map, data);
      _layersAdded = true;
    } else {
      await map.setStyleSourceProperty(_srcAreas, 'data', data.areas);
      await map.setStyleSourceProperty(_srcLines, 'data', data.lines);
      await map.setStyleSourceProperty(_srcMarkers, 'data', data.markers);
    }
  }

  Future<void> _addSourcesAndLayers(
      MapboxMap map, MapboxOverlayData data) async {
    for (final (id, json) in [
      (_srcAreas, data.areas),
      (_srcLines, data.lines),
      (_srcMarkers, data.markers),
    ]) {
      if (await map.styleSourceExists(id)) {
        await map.setStyleSourceProperty(id, 'data', json);
      } else {
        await map.addSource(GeoJsonSource(id: id, data: json));
      }
    }
    Future<void> layer(Map<String, Object?> spec) async {
      if (await map.styleLayerExists(spec['id']! as String)) return;
      await map.addStyleLayer(jsonEncode(spec), null);
    }

    await layer({
      'id': 'pz-areas-fill',
      'type': 'fill',
      'source': _srcAreas,
      'layout': {
        'fill-sort-key': ['get', 'order'],
      },
      'paint': {
        'fill-color': ['get', 'fill'],
      },
    });
    await layer({
      'id': 'pz-areas-line',
      'type': 'line',
      'source': _srcAreas,
      'layout': {'line-join': 'round'},
      'paint': {
        'line-color': ['get', 'stroke'],
        'line-width': ['get', 'width'],
      },
    });
    await layer({
      'id': 'pz-lines',
      'type': 'line',
      'source': _srcLines,
      'layout': {
        'line-join': 'round',
        'line-cap': 'round',
        'line-sort-key': ['get', 'order'],
      },
      'paint': {
        'line-color': ['get', 'color'],
        'line-width': ['get', 'width'],
      },
    });
    await layer({
      'id': _layerMarkers,
      'type': 'symbol',
      'source': _srcMarkers,
      'layout': {
        'icon-image': ['get', 'icon'],
        'icon-rotate': ['get', 'rotate'],
        // flutter_map'teki gibi işaretçiler haritayla birlikte döner.
        'icon-rotation-alignment': 'map',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        'symbol-sort-key': ['get', 'order'],
        'symbol-z-order': 'source',
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    _dpr = MediaQuery.devicePixelRatioOf(context);
    return MapWidget(
      key: const ValueKey('pz-mapbox'),
      styleUri: _style.uri ?? MapboxStyles.SATELLITE_STREETS,
      viewport: _initialViewport,
      onMapCreated: _onCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onCameraChangeListener: _onCamera,
    );
  }
}
