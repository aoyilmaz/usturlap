import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/coord_format.dart';
import '../../core/bearing_format.dart';
import '../../core/geo_math.dart';
import '../../data/elevation/elevation_store.dart';
import '../../core/nav_math.dart';
import '../../core/sequential_name.dart';
import '../../domain/models/contact.dart';
import '../../domain/models/imported_layer.dart';
import '../../domain/models/bloodhound.dart';
import '../../domain/models/bullseye.dart';
import '../../domain/models/clear_item.dart';
import '../../domain/ports/alert_output.dart';
import '../../domain/usecases/graphic_hit.dart';
import '../../domain/usecases/shape_edit.dart';
import '../../domain/usecases/viewshed.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/repeater.dart';
import '../../domain/models/track.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/bloodhound_providers.dart';
import '../../providers/bullseye_providers.dart';
import '../../providers/elevation_providers.dart';
import '../../providers/alert_providers.dart';
import '../../providers/background_location_providers.dart';
import '../../providers/field_providers.dart';
import '../../providers/geofence_providers.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/resection_providers.dart';
import '../../providers/selection_providers.dart';
import '../../providers/terrain_analysis_providers.dart';
import '../../providers/viewshed_providers.dart';
import '../../providers/layer_providers.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/offline_providers.dart';
import '../../providers/route_providers.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/offline_region.dart';
import '../offline/offline_frame_panel.dart';
import '../offline/offline_regions_sheet.dart';
import '../overlays/overlay_manager_sheet.dart';
import '../../providers/map_cleaner.dart';
import '../../providers/overlay_providers.dart';
import '../../domain/models/saved_view.dart';
import '../../providers/repeater_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../hud/manual_position_sheet.dart';
import '../hud/self_info_box.dart';
import '../import/import_action.dart';
import '../import/incoming_files.dart';
import '../routes/route_widgets.dart';
import '../shell/coordinate_sheet.dart';
import '../shell/atak_toolbar.dart';
import '../shell/clear_content_dialog.dart';
import '../shell/map_controls.dart';
import '../shell/radial_menu.dart';
import '../shell/route_sheet.dart';
import '../shell/settings_sheet.dart';
import '../shell/tools_grid_sheet.dart';
import '../shell/toolbar_manager_sheet.dart';
import '../shell/toolbar_tools.dart';
import '../tools/graphic_list_sheet.dart';
import '../layers/import_layer_action.dart';
import '../nav/nav_banner.dart';
import '../symbols/nato_symbol.dart';
import '../elevation/elevation_data_panel.dart';
import '../backup/backup_panel.dart';
import '../export/export_sheet.dart';
import '../field/reports_panel.dart';
import '../field/sun_moon_panel.dart';
import '../field/weather_panel.dart';
import '../elevation/elevation_profile_panel.dart';
import '../elevation/terrain_analysis_panel.dart';
import '../elevation/viewshed_panel.dart';
import '../gallery/gallery_panel.dart';
import '../hud/resection_panel.dart';
import '../nav/bloodhound_panel.dart';
import '../routes/route_alerts.dart';
import '../nav/tactical_compass_page.dart';
import '../tools/bullseye_panel.dart';
import 'clear_map_sheet.dart';
import 'selection_panel.dart';
import '../tools/freehand_layer.dart';
import '../tools/geofence_panel.dart';
import '../tools/measure_common.dart';
import '../tools/range_line_panel.dart';
import '../tools/range_ring_panel.dart';
import '../tools/range_tools_bar.dart';
import '../tools/save_graphic_dialog.dart';
import '../tools/shape_edit_layer.dart';
import '../tracks/track_list_sheet.dart';
import '../waypoints/add_waypoint_dialog.dart';
import '../waypoints/edit_waypoint_dialog.dart';
import '../waypoints/point_dropper_bar.dart';
import '../waypoints/waypoint_detail_panel.dart';
import '../waypoints/waypoint_list_sheet.dart';
import 'base_layer.dart';
import 'base_layer_resolver.dart';
import 'missing_layer_dialog.dart';
import 'engine/map_engine.dart';
import 'saved_views_sheet.dart';
import 'widgets/compass_rose.dart';
import 'widgets/los_overlay.dart';
import 'widgets/scale_bar.dart';
import '../shell/adaptive_sheet.dart';

/// Adım 3 — çevrimdışı/çevrimiçi harita + kendi konum işaretçisi + HUD +
/// kuzey/track-up modu + takip.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// Harita motoru kontrolcüsü (motor: engine/map_engine.dart → kMapEngine).
  final MapEngineController _map = kMapEngine.createController();

  /// Son bilinen kamera — harita yeniden kurulursa buradan başlar.
  MapCameraState _lastCamera = const MapCameraState(
    center: AppConstants.initialCenter,
    zoom: AppConstants.initialZoom,
  );
  static const _resolver = BaseLayerResolver();

  /// Çözülmüş (dosyası bulunmuş / adresi belli) taban katmanlar — id → katman.
  final Map<String, ResolvedBaseLayer> _resolved = {};
  final Map<String, GeoBounds> _layerBounds = {};
  final Set<String> _loadingLayers = {};
  final Set<String> _missingFiles = {}; // Documents'ta dosyası olmayan katmanlar

  late BaseLayerDef _selected;
  late Future<void> _ready;

  /// Harita kendi konumumuzu otomatik takip etsin mi.
  bool _follow = true;

  /// true: track-up (harita hareket yönüne döner), false: kuzey-yukarı.
  bool _trackUp = false;

  /// 3B arazi açık mı (yalnızca Mapbox motorunda).
  bool _terrain3d = false;

  /// İki parmakla döndürme kilitli mi (pusula okuna uzun bas → kilit).
  bool _rotationLocked = false;

  /// Nokta bırakma modu (ATAK Point Dropper): haritaya her dokunuş nokta koyar.
  bool _dropMode = false;

  /// Araç çubuğu gizli mi (≡'ye uzun bas).
  bool _toolbarHidden = false;

  /// Ölçüm araçları çubuğu (ATAK Range Tools) açık mı. Bir araç seçiliyse
  /// (ör. ≡ ızgarasından) çubuk zaten görünür.
  bool _rangeBarOpen = false;

  /// Çizim araçları çubuğu (ATAK Drawing Tools) açık mı.
  bool _drawBarOpen = false;

  /// Lasso: seçmek için çevre çiziliyor (harita kaymaz).
  bool _lassoMode = false;

  /// Çevrimdışı bölge çerçeveleme modu açık mı.
  bool _framing = false;

  /// Açık radyal menü (ATAK Radial Menu): hangi nesne, ekranda nerede.
  _RadialTarget? _radial;

  /// Radyal menü "Taşı": sonraki dokunuş bu noktayı oraya taşır.
  Waypoint? _moving;

  /// Şekli düzenlenen çizim (radyal "Şekil"); null = yok.
  ShapeEditState? _shapeEdit;

  /// Konumu düzelt → "Haritada göster": sonraki dokunuş elle konum olur.
  bool _placingSelf = false;

  /// Point Dropper'ın bu oturumda verdiği adlar: hızlı art arda dokunuşta
  /// veritabanı akışı gelmeden aynı ad iki kez verilmesin.
  final _droppedNames = <String>[];

  /// Pusula gülünün ölçeklendiği zoom (yarım kademeye yuvarlı; gül ekranda
  /// aşağı yukarı aynı büyüklükte kalsın diye kademe değişince yenilenir).
  double? _roseZoom;

  /// Harita her hareket ettiğinde artar (çerçeve boyut tahmini için).
  final ValueNotifier<int> _cameraTick = ValueNotifier(0);
  // Ölçek çubuğu kameranın her değişiminde güncellenir (ekranı yeniden kurmadan).
  late final ValueNotifier<MapCameraState> _scaleCamera =
      ValueNotifier(_lastCamera);

  /// Listeden "haritada göster" denen bölge (sınırı vurgulanır).
  String? _highlightRegionId;

  /// Rota listesinden "haritada göster" denen rota (dokununca kaybolur).
  RoutePlan? _previewRoute;

  /// Görüş alanı resmi: aynı sonuç için bir kez üretilir (motor aynı
  /// nesneyi görünce yeniden yüklemez).
  ViewshedGrid? _viewshedFor;
  MapImage? _viewshedImage;

  /// Arazi renkli katmanı resmi (aynı sonuç için bir kez).
  TerrainLayerImage? _terrainFor;
  MapImage? _terrainImage;

  @override
  void initState() {
    super.initState();
    _selected = kBaseLayers.firstWhere(
      (l) => l.type == BaseLayerSourceType.offlineMbtiles,
      orElse: () => kBaseLayers.first,
    );
    // Açılışta yalnızca varsayılan katmanı yükle (büyük topo'yu değil).
    _ready = _ensureResolved(_selected);
    getApplicationDocumentsDirectory()
        .then((d) => _docsPath = d.path)
        .catchError((_) => '');
    // Arka plan konumu tek yerden: iz kaydı ya da arka planda izlenen
    // geofence varken açık.
    ref.listenManual<bool>(
      backgroundLocationNeededProvider,
      (_, need) => ref.read(positionSourceProvider).setBackgroundEnabled(need),
      fireImmediately: true,
    );
    // Uyarı bildirimi gerekecek (geofence / rota takibi) → izin iste
    // (iOS yalnız ilk seferde sorar; açılışta boşuna sormaz).
    ref.listenManual<bool>(
      alertPermissionWantedProvider,
      (prev, want) {
        if (want && prev != true) {
          ref.read(alertNotificationsProvider).requestPermission();
        }
      },
      fireImmediately: true,
    );
    // Ekranı açık tut (Ayarlar → Saha): görevdeyken ya da her zaman.
    ref.listenManual<bool>(wakeWantedProvider, (_, on) {
      WakelockPlus.toggle(enable: on).catchError((_) {});
    }, fireImmediately: true);
    // Düşük pil: titreşim + şerit + sesli / bildirim.
    ref.listenManual<({int level, int seq})?>(lowBatteryProvider, (_, next) {
      if (next == null || !mounted) return;
      HapticFeedback.heavyImpact();
      final rec = ref.read(recordingProvider).isRecording;
      final text =
          'Pil %${next.level}${rec ? ' · iz kaydı sürüyor' : ''}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('Düşük pil: $text'),
        ));
      ref.read(alertDispatcherProvider).alert(
            title: 'Düşük pil',
            body: text,
            speech: 'Düşük pil. Yüzde ${next.level}.',
          );
    });
    // İz kaydı: başlarken otomatik durma süresi; süre dolunca uyarı.
    ref.listenManual<RecordingState>(recordingProvider, (prev, next) {
      if (!mounted || prev == null) return;
      final messenger = ScaffoldMessenger.of(context);
      if (!prev.isRecording && next.isRecording && next.stopAt != null) {
        final m = next.stopAt!.difference(DateTime.now()).inMinutes + 1;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
                'İz kaydı başladı · ${(m / 60).round()} sa sonra kendiliğinden durur'),
          ));
      }
      if (prev.isRecording && !next.isRecording && next.autoStopped) {
        HapticFeedback.heavyImpact();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('İz kaydı süresi doldu, kendiliğinden durdu.')));
        ref.read(alertDispatcherProvider).alert(
              title: 'İz kaydı durdu',
              body: 'Süre doldu; iz kaydedildi.',
              speech: 'İz kaydı süresi doldu, kayıt durdu.',
            );
      }
    });
    // "Usturlap ile aç" (AirDrop / Dosyalar): gelen dosya önizletilir.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => IncomingFiles.listen(_openIncoming),
    );
  }

  Future<void> _openIncoming(String path) async {
    if (!mounted) return;
    await importFromPath(context, ref, path, deleteAfter: true);
  }

  /// Katmanı (gerekirse) tembel çözer: internet katmanı anında; dosya tabanlı
  /// katman (MBTiles/PMTiles) dosyası bulunup kapsama alanı okunarak. Büyük
  /// asset'ler yalnızca seçilince kopyalanır. Karo okuyucularını motor açar.
  Future<void> _ensureResolved(BaseLayerDef layer) async {
    if (_resolved.containsKey(layer.id) || _loadingLayers.contains(layer.id)) {
      return;
    }
    final online = _resolver.resolveOnline(layer);
    if (online != null) {
      _resolved[layer.id] = online;
      return;
    }
    if (layer.type != BaseLayerSourceType.offlineMbtiles &&
        layer.type != BaseLayerSourceType.vectorPmtiles &&
        layer.type != BaseLayerSourceType.offlineGpkg) {
      return; // kullanılamayan katman (ör. token yok)
    }

    _loadingLayers.add(layer.id);
    try {
      final r = await _resolver.resolveFile(layer);
      if (!mounted) return;
      switch (r) {
        case BaseLayerFileMissing():
          setState(() => _missingFiles.add(layer.id));
          return;
        case BaseLayerReady(layer: final resolved, :final bounds):
          setState(() {
            _missingFiles.remove(layer.id);
            _resolved[layer.id] = resolved;
            if (bounds != null) _layerBounds[layer.id] = bounds;
          });
      }
      _recenterToLayer(layer);
    } finally {
      _loadingLayers.remove(layer.id);
    }
  }

  /// Seçili çevrimdışı katmanın kapsama alanı mevcut görünümün dışındaysa
  /// haritayı oraya götürür (bounds'a sığdırır; bounds yoksa manuel center).
  void _recenterToLayer(BaseLayerDef layer) {
    if (!_map.isReady || layer.id != _selected.id) return;
    final b = _layerBounds[layer.id];
    if (b != null) {
      if (b.contains(_map.camera.center)) return; // zaten kapsamda
      setState(() => _follow = false);
      _map.fitBounds(b, padding: const EdgeInsets.all(40));
      return;
    }
    final c = layer.center;
    if (c != null) {
      setState(() => _follow = false);
      _map.moveTo(c, zoom: 13);
    }
  }

  @override
  void dispose() {
    IncomingFiles.stop();
    _cameraTick.dispose();
    _scaleCamera.dispose();
    _map.dispose(); // motorun açtığı kaynakları da kapatır
    super.dispose();
  }

  /// Yeni konum/kerteriz geldiğinde haritayı (takip/track-up açıksa) güncelle.
  void _onSelfUpdate(Contact c) {
    if (_follow) {
      _map.moveTo(c.position);
    }
    if (_trackUp && c.headingDeg != null) {
      _map.rotateTo(c.headingDeg!);
    }
  }

  /// Kendi konum işaretçisi: kerteriz varsa ok, yoksa nokta.
  MapMarker _selfMarker(Contact self) {
    final heading = self.headingDeg;
    // Elle verilen konum turuncu (GPS değil, bir bakışta belli olsun).
    if (ref.read(manualPositionProvider) != null) {
      return MapMarker(
        id: 'self',
        imageKey: 'self:manual',
        point: self.position,
        width: 44,
        height: 44,
        onTap: () => _onObjectTap(
          self.position,
          title: '${self.callsign} (elle)',
          actions: () => _selfActions(self),
          anchor: RbEnd.selfRef,
        ),
        child: const Icon(Icons.person_pin_circle,
            color: Colors.orangeAccent, size: 38),
      );
    }
    return MapMarker(
      id: 'self',
      imageKey: heading == null ? 'self:dot' : 'self:arrow',
      point: self.position,
      width: 44,
      height: 44,
      rotationDeg: heading,
      onTap: () => _onObjectTap(
        self.position,
        title: self.callsign,
        actions: () => _selfActions(self),
        anchor: RbEnd.selfRef,
      ),
      child: heading == null
          ? const Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 28)
          : const Icon(Icons.navigation, color: Colors.lightBlueAccent, size: 34),
    );
  }

  /// Kayıtlı bir waypoint'in işaretçisi (dokun → detay/sil).
  /// APP-6 sadakati varsa NATO çerçevesi, görev noktasında mor rozet,
  /// sade noktada kırmızı pin.
  MapMarker _waypointMarker(Waypoint wp) {
    final isPin = wp.affiliation == Affiliation.waypoint;
    return MapMarker(
      id: 'wp:${wp.id}',
      // Aynı görünen semboller tek resmi paylaşır.
      imageKey: isPin
          ? 'wp:pin'
          : 'wp:${wp.affiliation.name}:${wp.echelon.name}:${wp.role.name}',
      point: wp.position,
      width: isPin ? 40 : 34,
      height: isPin ? 40 : 34,
      onTap: () => _onObjectTap(
        wp.position,
        title: wp.name,
        actions: () => _waypointActions(wp),
        anchor: RbEnd.waypointRef(wp.uid),
      ),
      child: PointSymbol(
        affiliation: wp.affiliation,
        echelon: wp.echelon,
        role: wp.role,
        size: isPin ? 36 : 34,
      ),
    );
  }

  /// R&B etiketi yazı stili (ölçüm ve çizim aynı stili kullanır; resim
  /// uygulama temasından bağımsız çizildiği için miras almaz).
  static const _rbLabelStyle = TextStyle(
    inherit: false,
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.none,
  );

  /// R&B çizgisinin ortasındaki etiket: "kerteriz · mesafe". Dokununca
  /// çizginin menüsü. Yazı değiştikçe resim yenilenir (değişken anahtar).
  MapMarker _rangeLabelMarker(
    ResolvedRangeLine r,
    BearingFormatter fmt,
    bool night,
  ) {
    final m = r.measure;
    return _labelMarker(
      id: 'rb:${r.line.id}',
      text:
          '${fmt.format(m.bearing, r.from)} · ${GeoMath.fmtDistance(m.meters)}',
      color: night ? Colors.redAccent : Color(r.line.colorValue),
      point: r.middle,
      onTap: () => _onObjectTap(
        r.middle,
        title: r.line.name,
        actions: () => _rangeLineActions(r),
      ),
    );
  }

  List<MapOverlay> _rangeRingCircles(ResolvedRangeRing r, bool night) {
    final color = night ? Colors.redAccent : Color(r.ring.colorValue);
    final n = r.ring.radii.length;
    return [
      for (var i = 0; i < n; i++)
        MapCircle(
          center: r.center,
          radiusMeters: r.ring.radii[i],
          fillColor: color.withValues(alpha: i == 0 ? 0.10 : 0.0),
          // İçteki halka en belirgin; dıştakiler en çok %50'ye solar.
          strokeColor:
              color.withValues(alpha: n == 1 ? 1.0 : 1.0 - 0.5 * i / (n - 1)),
          strokeWidth: 2,
        ),
    ];
  }

  /// Her halkanın kuzey ucunda mesafe etiketi; dokununca halkanın menüsü.
  List<MapMarker> _rangeRingLabels(ResolvedRangeRing r, bool night) {
    final color = night ? Colors.redAccent : Color(r.ring.colorValue);
    return [
      for (var i = 0; i < r.ring.radii.length; i++)
        _labelMarker(
          id: 'rr:${r.ring.id}:$i',
          text: GeoMath.fmtDistance(r.ring.radii[i]),
          color: color,
          point: r.labelPoint(i),
          onTap: () => _onObjectTap(
            r.labelPoint(i),
            title: r.ring.name,
            actions: () => _rangeRingActions(r),
          ),
        ),
    ];
  }

  /// Haritaya yazı etiketi (R&B, halka): koyu zemin, renkli çerçeve.
  /// Yazı değiştikçe resim yenilenir (değişken anahtar).
  MapMarker _labelMarker({
    required String id,
    required String text,
    required Color color,
    required LatLng point,
    required VoidCallback onTap,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _rbLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = (tp.width + 18).ceilToDouble();
    tp.dispose();
    return MapMarker(
      id: id,
      imageKey: '${MapMarker.volatilePrefix}lbl:${color.toARGB32()}:$text',
      point: point,
      width: width,
      height: 26,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(text, style: _rbLabelStyle, maxLines: 1),
      ),
    );
  }

  static const _bullseyeColor = Color(0xFFF5F5F5);

  List<MapOverlay> _bullseyeOverlays(
    ResolvedBullseye b,
    NorthRef north,
    bool night,
  ) {
    final color = night ? Colors.redAccent : _bullseyeColor;
    final outer = b.bullseye.outerRadius;
    return [
      for (final r in b.bullseye.radii)
        MapCircle(
          center: b.center,
          radiusMeters: r,
          fillColor: Colors.transparent,
          strokeColor: color.withValues(alpha: 0.8),
          strokeWidth: 1.5,
        ),
      for (final brg in Bullseye.radialBearings(b.center, north))
        MapLine(
          points: [b.center, GeoMath.destination(b.center, outer, brg)],
          width: 1.5,
          color: color.withValues(alpha: 0.6),
        ),
    ];
  }

  /// Merkez işareti, ışın uçlarında kerteriz ve halkalarda mesafe
  /// etiketleri; hepsine dokununca bullseye'ın menüsü.
  List<MapMarker> _bullseyeMarkers(
    ResolvedBullseye b,
    BearingFormatter fmt,
    bool night,
  ) {
    final color = night ? Colors.redAccent : _bullseyeColor;
    final be = b.bullseye;
    void tap(LatLng p) => _onObjectTap(
          p,
          title: be.name,
          actions: () => _bullseyeActions(b),
        );
    final bearings = Bullseye.radialBearings(b.center, fmt.ref);
    // Halka etiketleri ışınların arasında (ilk iki ışının ortası).
    final ringBearing = bearings[0] + Bullseye.radialStep / 2;
    final many = be.ringCount > 5;
    return [
      MapMarker(
        id: 'be:center',
        imageKey: 'be:center:${color.toARGB32()}',
        point: b.center,
        width: 34,
        height: 34,
        onTap: () => tap(b.center),
        child: Icon(Icons.track_changes, color: color, size: 30),
      ),
      for (var i = 0; i < bearings.length; i++)
        _labelMarker(
          id: 'be:r$i',
          text: fmt.format(bearings[i], b.center),
          color: color,
          point: GeoMath.destination(b.center, be.outerRadius, bearings[i]),
          onTap: () => tap(b.center),
        ),
      for (var k = 1; k <= be.ringCount; k++)
        // Çok halkada her ikinciye (ve en dıştakine) etiket: kalabalık olmasın.
        if (!many || k.isEven || k == be.ringCount)
          _labelMarker(
            id: 'be:k$k',
            text: GeoMath.fmtDistance(be.ringSpacing * k),
            color: color,
            point:
                GeoMath.destination(b.center, be.ringSpacing * k, ringBearing),
            onTap: () => tap(b.center),
          ),
    ];
  }

  /// Geriden kestirme: her noktadan bana doğru nişan çizgisi, hata alanı
  /// ve bulunan konum.
  List<MapOverlay> _resectionOverlays(ResectionPreview p) {
    const color = Colors.amber;
    final at = p.result.position;
    return [
      if (p.result.errorPolygon.length >= 3)
        MapArea(
          points: p.result.errorPolygon,
          fillColor: color.withValues(alpha: 0.25),
          strokeColor: color,
          strokeWidth: 2,
        ),
      for (final s in p.sightings)
        MapLine(
          points: [
            s.landmark,
            // Konum bulunduysa biraz ötesine, yoksa 5 km.
            GeoMath.destination(
              s.landmark,
              at == null ? 5000 : GeoMath.distance(s.landmark, at) * 1.3,
              s.trueBearing + 180,
            ),
          ],
          width: 2,
          color: color,
        ),
      if (at != null)
        MapMarker(
          id: 'resection',
          imageKey: 'resection',
          point: at,
          width: 40,
          height: 40,
          child: const Icon(Icons.person_pin_circle,
              color: Colors.orangeAccent, size: 36),
        ),
    ];
  }

  List<RadialAction> _bloodhoundActions(ResolvedBloodhound r) => [
        RadialAction(
            icon: Icons.info_outline,
            label: 'Detay',
            onTap: _openBloodhounds),
        RadialAction(
            icon: Icons.center_focus_strong,
            label: 'Hedef',
            onTap: () => _centerOn(r.to)),
        RadialAction(
            icon: Icons.close,
            label: 'Kaldır',
            color: Colors.redAccent,
            onTap: () => ref
                .read(bloodhoundsProvider.notifier)
                .remove(r.bloodhound.id)),
      ];

  List<RadialAction> _bullseyeActions(ResolvedBullseye b) => [
        RadialAction(
            icon: Icons.info_outline, label: 'Detay', onTap: _openBullseye),
        RadialAction(
            icon: Icons.center_focus_strong,
            label: 'Ortala',
            onTap: () => _centerOn(b.center)),
        RadialAction(
            icon: Icons.delete_outline,
            label: 'Kaldır',
            color: Colors.redAccent,
            onTap: () async {
              final n = ref.read(bullseyeProvider.notifier);
              if (await confirmDeleteNamed(context, b.bullseye.name)) {
                n.set(null);
              }
            }),
      ];

  /// Halka grubunun menüsü.
  List<RadialAction> _rangeRingActions(ResolvedRangeRing r) => [
        RadialAction(
            icon: Icons.info_outline,
            label: 'Detay',
            onTap: () => showRangeRingPanel(context,
                ringId: r.ring.id!, onCenter: _centerOn)),
        RadialAction(
            icon: Icons.center_focus_strong,
            label: 'Ortala',
            onTap: () => _centerOn(r.center)),
        RadialAction(
            icon: Icons.delete_outline,
            label: 'Sil',
            color: Colors.redAccent,
            onTap: () async {
              final repo = ref.read(rangeRingRepositoryProvider);
              if (await confirmDeleteNamed(context, r.ring.name)) {
                await repo.delete(r.ring.id!);
              }
            }),
      ];

  /// R&B çizgisinin menüsü.
  List<RadialAction> _rangeLineActions(ResolvedRangeLine r) => [
        RadialAction(
            icon: Icons.info_outline,
            label: 'Detay',
            onTap: () => showRangeLinePanel(context,
                lineId: r.line.id!, onCenter: _centerOn)),
        RadialAction(
            icon: Icons.center_focus_strong,
            label: 'Ortala',
            onTap: () => _centerOn(r.middle)),
        RadialAction(
            icon: Icons.delete_outline,
            label: 'Sil',
            color: Colors.redAccent,
            onTap: () async {
              final repo = ref.read(rangeLineRepositoryProvider);
              if (await confirmDeleteNamed(context, r.line.name)) {
                await repo.delete(r.line.id!);
              }
            }),
      ];

  /// Telsiz röle işaretçisi (anten ikonu; dokun → özellikler).
  MapMarker _repeaterMarker(Repeater r) {
    return MapMarker(
      id: 'rep:${r.id}',
      imageKey: 'repeater',
      point: r.position,
      width: 32,
      height: 32,
      onTap: () => _onObjectTap(
        r.position,
        title: r.name,
        // Kapsama dairesi menü açıkken de görünsün.
        onOpen: () => ref.read(selectedRepeaterProvider.notifier).select(r),
        actions: () => _repeaterActions(r),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.tealAccent, width: 1.5),
        ),
        child: const Icon(Icons.cell_tower, color: Colors.tealAccent, size: 20),
      ),
    );
  }

  void _showRepeaterDetail(Repeater r) {
    String fmtFreq(double? f) => f == null ? '—' : '${f.toStringAsFixed(3)} MHz';
    showAdaptiveSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.cell_tower, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 10),
              _repRow('RX (dinle)', fmtFreq(r.listenFreq)),
              _repRow('TX (gönder)', fmtFreq(r.sendFreq)),
              _repRow('Shift', r.offset == null ? '—' : '${r.offset} MHz'),
              _repRow('CTCSS', r.ctcss == null ? 'yok' : '${r.ctcss} Hz'),
              _repRow('Band / tip', '${r.band ?? '—'} · ${r.type ?? '—'}'),
              _repRow('Operatör', r.operator ?? '—'),
              _repRow('Bölge', r.region ?? '—'),
              _repRow('Koordinat',
                  CoordFormat.format(r.position, ref.read(coordFormatProvider))),
              if (r.notes != null && r.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.notes!, style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _centerOn(r.position);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Ortala'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(navTargetProvider.notifier)
                        .set(r.position, r.name);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Git'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _repRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  /// Kalıcı taktik grafikler (çizgi, alan, daire, dikdörtgen). Kapalı
  /// şekiller çizgilerin altında; kalınlık ve kesikli stil grafiğin kendi.
  List<MapOverlay> _graphicOverlays(List<MapGraphic> graphics) {
    final areas = <MapOverlay>[];
    final lines = <MapOverlay>[];
    for (final g in graphics) {
      final pts = g.outline;
      if (pts.length < 2) continue;
      final color = Color(g.colorValue);
      if (g.closed && pts.length >= 3) {
        areas.add(MapArea(
          points: pts,
          fillColor: color.withValues(alpha: 0.22),
          strokeColor: color,
          strokeWidth: g.strokeWidth,
          dashed: g.dashed,
          height: g.height,
        ));
      } else {
        lines.add(MapLine(
          points: pts,
          width: g.strokeWidth,
          color: color,
          dashed: g.dashed,
        ));
      }
    }
    return [...areas, ...lines];
  }

  /// Aktif ölçüm/çizim aracının çizimleri (çizgi/poligon/sektör + köşeler).
  List<MapOverlay> _toolOverlays(ToolState tool) {
    if (!tool.active || !tool.visible || tool.points.isEmpty) return const [];
    final pts = tool.points;
    const amber = Colors.amber;
    final fill = amber.withValues(alpha: 0.25);
    final out = <MapOverlay>[];

    switch (tool.mode) {
      case ToolMode.distance:
        if (pts.length >= 2) {
          out.add(MapLine(points: pts, width: 4, color: amber));
        }
        break;
      case ToolMode.polygon:
        if (pts.length >= 3) {
          out.add(MapArea(
              points: pts, fillColor: fill, strokeColor: amber, strokeWidth: 3));
        } else if (pts.length == 2) {
          out.add(MapLine(points: pts, width: 4, color: amber));
        }
        break;
      case ToolMode.sector:
        if (pts.length == 2) {
          out.add(MapLine(points: pts, width: 3, color: amber));
        } else if (pts.length >= 3) {
          final r = GeoMath.distance(pts[0], pts[1]);
          final b1 = GeoMath.bearing(pts[0], pts[1]);
          final b2 = GeoMath.bearing(pts[0], pts[2]);
          out.add(MapArea(
              points: GeoMath.sectorPolygon(pts[0], r, b1, b2),
              fillColor: fill,
              strokeColor: amber,
              strokeWidth: 3));
        }
        break;
      case ToolMode.lineOfSight:
        if (pts.length >= 2) {
          out.add(MapLine(
              points: [pts[0], pts[1]], width: 4, color: Colors.blueAccent));
        }
        break;
      case ToolMode.rangeRings:
        if (pts.length >= 2) {
          final r = GeoMath.distance(pts[0], pts[1]);
          for (final k in const [1, 2, 3]) {
            out.add(MapCircle(
              center: pts[0],
              radiusMeters: r * k,
              fillColor: amber.withValues(alpha: k == 1 ? 0.10 : 0.0),
              strokeColor: amber.withValues(alpha: 1.0 - (k - 1) * 0.25),
              strokeWidth: 2,
            ));
          }
          out.add(MapLine(points: [pts[0], pts[1]], width: 2, color: amber));
        }
        break;
      case ToolMode.polyline:
      case ToolMode.freehand:
        if (pts.length >= 2) {
          out.add(MapLine(points: pts, width: 4, color: amber));
        }
        break;
      case ToolMode.circle:
        if (pts.length >= 2) {
          out.add(MapCircle(
            center: pts[0],
            radiusMeters: GeoMath.distance(pts[0], pts[1]),
            fillColor: fill,
            strokeColor: amber,
            strokeWidth: 3,
          ));
          out.add(MapLine(points: [pts[0], pts[1]], width: 2, color: amber));
        }
        break;
      case ToolMode.rectangle:
        if (pts.length >= 2) {
          out.add(MapArea(
              points: GeoMath.rectangleCorners(pts[0], pts[1]),
              fillColor: fill,
              strokeColor: amber,
              strokeWidth: 3));
        }
        break;
      case ToolMode.none:
        break;
    }

    // Serbest çizimde nokta çok: köşe işareti yok.
    if (tool.mode == ToolMode.freehand) return out;

    // Dokunulan köşeleri küçük noktalarla göster.
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      out.add(MapMarker(
        id: 'tool:$i',
        imageKey: 'tool:vertex',
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
      ));
    }
    return out;
  }

  /// Haritayı bir noktaya ortalar (ve otomatik takibi bırakır).
  void _centerOn(LatLng p) {
    setState(() => _follow = false);
    _map.moveTo(p);
  }

  /// Haritayı bir izin tamamını gösterecek şekilde sığdırır.
  void _fitTrack(List<TrackPoint> points) {
    if (points.isEmpty) return;
    setState(() => _follow = false);
    if (points.length == 1) {
      _map.moveTo(points.first.position);
      return;
    }
    final bounds = GeoBounds.fromPoints([for (final p in points) p.position]);
    _map.fitBounds(bounds, padding: const EdgeInsets.all(60));
  }

  void _showWaypointDetail(Waypoint wp) {
    showAdaptiveSheet<void>(
      context: context,
      id: 'waypoint-detail',
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => WaypointDetailPanel(
        initial: wp,
        onCenter: (w) => _centerOn(w.position),
        onGo: (w) => ref.read(navTargetProvider.notifier).set(w.position, w.name),
        onEdit: (w) => showEditWaypointDialog(this.context, ref, w),
        onShare: _shareWaypoint,
        onDelete: _deleteWaypoint,
        onViewshed: (w) => _openViewshed(observer: w.position, name: w.name),
      ),
    );
  }

  void _shareWaypoint(Waypoint wp) {
    final text = '${wp.name}\n'
        '${CoordFormat.mgrs(wp.position)}'
        '${wp.note != null && wp.note!.isNotEmpty ? "\n${wp.note}" : ""}';
    SharePlus.instance.share(ShareParams(text: text, subject: wp.name));
  }

  void _deleteWaypoint(Waypoint wp) {
    final target = ref.read(navTargetProvider);
    if (target != null && target.position == wp.position) {
      ref.read(navTargetProvider.notifier).clear();
    }
    // Fotoğrafları da gitsin (dosya + kayıt).
    ref.read(attachmentRepositoryProvider).deleteAllFor(wp.uid);
    ref.read(waypointRepositoryProvider).delete(wp.id!);
  }

  // ------------------------------------------------ radyal menü (ATAK s.11)

  /// Haritadaki bir nesneye dokunuldu. Ölçüm, rota planlama ya da taşıma
  /// sürüyorsa nokta nesnenin tam üstüne konur (ATAK: nesneye yapışma);
  /// değilse nesnenin radyal menüsü açılır.
  /// [anchor]: ölçüm aracı açıkken bu nesneye dokunulursa noktanın bağı
  /// (kaydedilen R&B çizgisinin ucu nesneyle hareket eder).
  void _onObjectTap(
    LatLng p, {
    required String title,
    required List<RadialAction> Function() actions,
    VoidCallback? onOpen,
    String? anchor,
  }) {
    if (_shapeEdit != null) {
      _shapeEditTap(p);
      return;
    }
    if (_moving != null) {
      _finishMove(p);
      return;
    }
    // Bilinen bir noktanın üstündeysem konumum tam orası.
    if (_placingSelf) {
      _setManualPosition(p);
      return;
    }
    if (ref.read(routePlanningProvider).active) {
      HapticFeedback.selectionClick();
      ref.read(routePlanningProvider.notifier).addPoint(p);
      return;
    }
    if (ref.read(toolProvider).active) {
      HapticFeedback.selectionClick();
      ref.read(toolProvider.notifier).addPoint(p, ref: anchor);
      return;
    }
    onOpen?.call();
    _openRadial(p, title, actions());
  }

  Future<void> _openRadial(
    LatLng point,
    String title,
    List<RadialAction> actions,
  ) async {
    final screen = await _map.screenPointOf(point);
    if (!mounted || screen == null) return;
    HapticFeedback.selectionClick();
    setState(() => _radial = _RadialTarget(point, title, actions, screen));
  }

  void _closeRadial() {
    if (_radial != null) setState(() => _radial = null);
  }

  /// Kamera değişince (elle ya da takipte) menü nesneyle birlikte kayar;
  /// nesne ekrandan çıkarsa kapanır.
  Future<void> _repositionRadial() async {
    final r = _radial;
    if (r == null) return;
    final screen = await _map.screenPointOf(r.point);
    if (!mounted || _radial?.point != r.point) return;
    final size = MediaQuery.sizeOf(context);
    if (screen == null || !(Offset.zero & size).contains(screen)) {
      setState(() => _radial = null);
      return;
    }
    setState(() => _radial = _radial!.at(screen));
  }

  List<RadialAction> _waypointActions(Waypoint wp) => [
        RadialAction(
            icon: Icons.info_outline,
            label: 'Detay',
            onTap: () => _showWaypointDetail(wp)),
        RadialAction(
            icon: Icons.navigation_outlined,
            label: 'Git',
            onTap: () => ref
                .read(navTargetProvider.notifier)
                .set(wp.position, wp.name)),
        RadialAction(
            icon: Icons.pets,
            label: 'Takip',
            onTap: () => _followWaypoint(wp)),
        RadialAction(
            icon: Icons.straighten,
            label: 'R&B',
            onTap: () => _startToolAt(ToolMode.distance, wp.position,
                anchor: RbEnd.waypointRef(wp.uid))),
        RadialAction(
            icon: Icons.radar,
            label: 'Halka',
            onTap: () => _startToolAt(ToolMode.rangeRings, wp.position,
                anchor: RbEnd.waypointRef(wp.uid))),
        RadialAction(
            icon: Icons.open_with, label: 'Taşı', onTap: () => _startMove(wp)),
        RadialAction(
            icon: Icons.ios_share,
            label: 'Paylaş',
            onTap: () => _shareWaypoint(wp)),
        RadialAction(
            icon: Icons.delete_outline,
            label: 'Sil',
            color: Colors.redAccent,
            onTap: () => _confirmDeleteWaypoint(wp)),
        RadialAction(
            icon: Icons.center_focus_strong,
            label: 'Ortala',
            onTap: () => _centerOn(wp.position)),
      ];

  /// Kendi işaretinin menüsü (ATAK self-marker, kılavuz s.8). Açık
  /// seçenekler yeşil.
  List<RadialAction> _selfActions(Contact self) {
    const on = Colors.lightGreenAccent;
    final circle = ref.read(showGpsCircleProvider);
    final rose = ref.read(showCompassRoseProvider);
    final trail = ref.read(showRecentTrailProvider);
    final manual = ref.read(manualPositionProvider) != null;
    return [
      RadialAction(
          icon: Icons.my_location, label: 'Ortala', onTap: _recenter),
      RadialAction(
          icon: Icons.edit_location_alt_outlined,
          label: 'Düzelt',
          color: manual ? Colors.orangeAccent : null,
          onTap: _openManualPosition),
      if (manual)
        RadialAction(
            icon: Icons.gps_fixed,
            label: 'GPS\'e dön',
            color: Colors.orangeAccent,
            onTap: () => ref.read(manualPositionProvider.notifier).clear()),
      RadialAction(
          icon: Icons.gps_fixed,
          label: 'Daire',
          color: circle ? on : null,
          onTap: () => ref.read(showGpsCircleProvider.notifier).toggle()),
      RadialAction(
          icon: Icons.explore_outlined,
          label: 'Pusula',
          color: rose ? on : null,
          onTap: () => ref.read(showCompassRoseProvider.notifier).toggle()),
      RadialAction(
          icon: Icons.history,
          label: '15 dk',
          color: trail ? on : null,
          onTap: () => ref.read(showRecentTrailProvider.notifier).toggle()),
      // Benden hedefe R&B: ikinci ucu haritaya / bir nesneye dokunarak koy;
      // kaydedilen çizgi ben hareket ettikçe güncellenir (ATAK dinamik R&B).
      RadialAction(
          icon: Icons.straighten,
          label: 'R&B',
          onTap: () => _startToolAt(ToolMode.distance, self.position,
              anchor: RbEnd.selfRef)),
      RadialAction(
          icon: Icons.ios_share,
          label: 'Paylaş',
          onTap: () => _shareSelf(self)),
    ];
  }

  void _openManualPosition() {
    showManualPositionSheet(
      context,
      onPickOnMap: () => setState(() {
        _placingSelf = true;
        _moving = null;
        _dropMode = false;
      }),
      onApplied: (p) {
        setState(() => _follow = true);
        _map.moveTo(p);
      },
      onResection: _openResection,
    );
  }

  void _setManualPosition(LatLng p) {
    HapticFeedback.mediumImpact();
    setState(() {
      _placingSelf = false;
      _follow = true;
    });
    ref.read(manualPositionProvider.notifier).set(p);
  }

  void _shareSelf(Contact self) {
    final text = '${self.callsign}\n'
        '${CoordFormat.mgrs(self.position)}\n'
        '${CoordFormat.wgs84(self.position)}';
    SharePlus.instance.share(ShareParams(text: text, subject: self.callsign));
  }

  List<RadialAction> _repeaterActions(Repeater r) => [
        RadialAction(
            icon: Icons.info_outline,
            label: 'Detay',
            onTap: () => _showRepeaterDetail(r)),
        RadialAction(
            icon: Icons.navigation_outlined,
            label: 'Git',
            onTap: () =>
                ref.read(navTargetProvider.notifier).set(r.position, r.name)),
        RadialAction(
            icon: Icons.straighten,
            label: 'R&B',
            onTap: () => _startToolAt(ToolMode.distance, r.position)),
        RadialAction(
            icon: Icons.center_focus_strong,
            label: 'Ortala',
            onTap: () => _centerOn(r.position)),
      ];

  /// Ölçüm aracını nesneden başlat (R&B: ikinci nokta için haritaya dokun;
  /// halka: dokunulan yer yarıçapı belirler).
  void _startToolAt(ToolMode mode, LatLng p, {String? anchor}) {
    final n = ref.read(toolProvider.notifier);
    n.setMode(mode);
    n.addPoint(p, ref: anchor);
    setState(() {
      _rangeBarOpen = true;
      _dropMode = false;
      _moving = null;
    });
  }

  void _startMove(Waypoint wp) {
    ref.read(toolProvider.notifier).reset();
    setState(() {
      _moving = wp;
      _dropMode = false;
      _rangeBarOpen = false;
      _placingSelf = false;
    });
  }

  // ------------------------------------------------ çizim düzenleme

  /// Dokunulan noktadaki çizim (görünenler arasında; ~24 pt tolerans).
  MapGraphic? _graphicAt(LatLng p) {
    final vis = ref.read(overlayVisibilityProvider);
    final graphics = [
      for (final g
          in ref.read(mapGraphicsProvider).value ?? const <MapGraphic>[])
        if (vis.showsGraphic(g)) g,
    ];
    if (graphics.isEmpty) return null;
    final tol = 24 * metersPerPixel(_map.camera.zoom, p.latitude);
    return hitGraphic(p, graphics, tol);
  }

  /// Çizimin radyal menüsü (ATAK: şekle dokun).
  List<RadialAction> _graphicActions(MapGraphic g) => [
        RadialAction(
            icon: Icons.edit_outlined,
            label: 'Düzenle',
            onTap: () => showEditGraphicDialog(context, ref, g)),
        RadialAction(
            icon: Icons.polyline_outlined,
            label: 'Şekil',
            onTap: () => _startShapeEdit(g)),
        if (g.closed)
          RadialAction(
              icon: Icons.fence,
              label: 'Geofence',
              color: g.geofence == null ? null : Colors.orangeAccent,
              onTap: () => showGeofenceDialog(context, ref, g)),
        if (g.type == GraphicType.line)
          RadialAction(
              icon: Icons.area_chart_outlined,
              label: 'Profil',
              onTap: () => showElevationProfilePanel(
                    context,
                    title: '${g.name}: yükseklik profili',
                    points: g.points,
                  )),
        RadialAction(
            icon: Icons.delete_outline,
            label: 'Sil',
            color: Colors.redAccent,
            onTap: () => _confirmDeleteGraphic(g)),
      ];

  void _startShapeEdit(MapGraphic g) {
    ref.read(toolProvider.notifier).reset();
    setState(() {
      _shapeEdit = ShapeEditState(g);
      _moving = null;
      _dropMode = false;
      _placingSelf = false;
      _lassoMode = false;
      _rangeBarOpen = false;
      _drawBarOpen = false;
      _radial = null;
    });
  }

  void _shapeEditSelect(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      final s = _shapeEdit;
      if (s == null) return;
      // Seçili köşeye yeniden dokunmak seçimi bırakır.
      _shapeEdit = s.select(s.selected == i ? null : i);
    });
  }

  /// Şekil düzenlemede haritaya / nesneye dokunuldu: seçili köşe oraya.
  void _shapeEditTap(LatLng p) {
    final s = _shapeEdit;
    if (s == null || s.selected == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _shapeEdit = s.moveSelectedTo(p));
  }

  Future<void> _saveShapeEdit() async {
    final s = _shapeEdit;
    if (s == null) return;
    setState(() => _shapeEdit = null);
    if (!s.changed) return;
    HapticFeedback.mediumImpact();
    await ref.read(mapGraphicRepositoryProvider).setPoints(
          s.graphic.id!,
          s.points,
        );
  }

  /// Radyal "Sil": onaylı; Geri al'lı (Haritayı temizle altyapısı).
  Future<void> _confirmDeleteGraphic(MapGraphic g) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDeleteNamed(context, g.name)) return;
    final cleaner = ref.read(mapCleanerProvider);
    final snapshot = await cleaner.clear(
      {ClearItem.graphics},
      targets: MapClearTargets(
        tool: const ToolState(),
        rangeLines: const [],
        rangeRings: const [],
        bullseye: null,
        bloodhounds: const [],
        navTarget: null,
        activeRoute: null,
        displayedTrackId: null,
        viewshed: null,
        terrain: null,
        waypoints: const [],
        graphics: [g],
      ),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: ClearMapPanel.undoWindow,
        persist: false,
        content: Text('“${g.name}” silindi.'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => cleaner.undo(snapshot),
        ),
      ));
  }

  Future<void> _finishMove(LatLng p) async {
    final wp = _moving;
    if (wp == null) return;
    setState(() => _moving = null);
    HapticFeedback.mediumImpact();
    await ref.read(waypointRepositoryProvider).move(wp.id!, p);
    // Git hedefi bu noktaysa hedef de taşınır.
    final target = ref.read(navTargetProvider);
    if (target != null && target.position == wp.position) {
      ref.read(navTargetProvider.notifier).set(p, wp.name);
    }
  }

  /// Radyal "Sil": eldivenle yanlış dilime basılabilir → onay sorulur.
  Future<void> _confirmDeleteWaypoint(Waypoint wp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('“${wp.name}” silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _deleteWaypoint(wp);
  }

  void _recenter() {
    final self = ref.read(selfContactProvider);
    setState(() => _follow = true);
    if (self != null) {
      // Uzaktaysak konuma yakınlaş (sokak seviyesi); zaten yakınsak zoom'u koru.
      final zoom = _map.camera.zoom;
      _map.moveTo(self.position, zoom: zoom < 16 ? 16.0 : zoom);
    }
  }

  void _toggleOrientation() {
    setState(() => _trackUp = !_trackUp);
    if (!_trackUp) {
      _map.rotateTo(0); // kuzey-yukarı
    } else {
      final self = ref.read(selfContactProvider);
      if (self?.headingDeg != null) _map.rotateTo(self!.headingDeg!);
    }
  }

  Future<void> _onLayerTapped(BaseLayerDef layer) async {
    Navigator.of(context).pop();
    // Dosyası cihazda yoksa katman değiştirilmez; yol gösterilir.
    if (layer.needsFile && !await _layerFileExists(layer)) {
      if (!mounted) return;
      final choice = await showMissingLayerDialog(context, layer);
      if (!mounted) return;
      switch (choice) {
        case MissingLayerChoice.importFile:
          await _importLayer();
        case MissingLayerChoice.downloadStreets:
          final streets =
              kBaseLayers.firstWhere((l) => l.id == 'mapbox_streets');
          _selectLayer(streets);
          _startFraming();
        case null:
          break;
      }
      return;
    }
    if (!mounted) return;
    if (!layer.isAvailable) {
      final msg = layer.type == BaseLayerSourceType.mapboxStyle
          ? '“${layer.label}” için Mapbox anahtarı yok. Uygulamayı '
              '--dart-define=MAPBOX_ACCESS_TOKEN=pk.... ile çalıştırın.'
          : '“${layer.label}” için henüz MBTiles yok. '
              'assets/tiles/ içine dosyayı ekleyip base_layer.dart\'a tanımlayınca aktif olur.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }
    _selectLayer(layer);
  }

  void _selectLayer(BaseLayerDef layer) {
    setState(() {
      _selected = layer;
      _missingFiles.remove(layer.id);
    });
    // Katmanı (gerekirse) tembel yükle — büyük topo yalnızca seçilince kopyalanır.
    // (Yükleme bitince _ensureResolved zaten kapsama alanına götürür.)
    _ensureResolved(layer);
    // Zaten yüklüyse hemen kapsama alanına git (tekrar girememe sorunu).
    _recenterToLayer(layer);
  }

  /// Belgeler klasörü (katman dosyası var mı denetimi için; açılışta okunur).
  String? _docsPath;

  Future<bool> _layerFileExists(BaseLayerDef layer) async {
    final name = layer.fileName;
    if (name == null) return true;
    final docs = _docsPath ??= (await getApplicationDocumentsDirectory()).path;
    return File('$docs/$name').exists();
  }

  /// Listede dosyası olmadığı bilinen katman (açılışta bakılır).
  bool _knownMissing(BaseLayerDef layer) {
    final name = layer.fileName;
    final docs = _docsPath;
    if (!layer.needsFile || name == null || docs == null) return false;
    return !File('$docs/$name').existsSync();
  }

  // ----------------------------------------- kayıtlı görünümler (ATAK s.22)

  void _openResection() => showResectionPanel(context, onCenter: _centerOn);

  void _openBloodhounds() =>
      showBloodhoundPanel(context, onCenter: _centerOn);

  /// Noktayı takip et (benden noktaya). Aynı takip açıksa söyler.
  void _followWaypoint(Waypoint wp) {
    final me = ref.read(selfContactProvider)?.position;
    final added = ref.read(bloodhoundsProvider.notifier).add(
          RbEnd(me ?? wp.position, RbEnd.selfRef),
          RbEnd(wp.position, RbEnd.waypointRef(wp.uid)),
        );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added
          ? '${wp.name} takip ediliyor. Hepsi: ≡ → Takip.'
          : '${wp.name} zaten takip ediliyor.'),
    ));
  }

  void _openViewshed({LatLng? observer, String? name}) => showViewshedPanel(
        context,
        mapCenter: () => _map.camera.center,
        onCenter: _centerOn,
        observer: observer,
        observerName: name,
      );

  /// Görüş alanı katmanı + gözlemci ve yarıçap.
  List<MapOverlay> _viewshedOverlays(ViewshedState? v, bool night) {
    final grid = v?.grid;
    if (v == null || grid == null) return const [];
    if (!identical(grid, _viewshedFor)) {
      _viewshedFor = grid;
      _viewshedImage = MapImage(
        id: 'viewshed',
        north: grid.north,
        south: grid.south,
        east: grid.east,
        west: grid.west,
        width: grid.size,
        height: grid.size,
        pixels: grid.toRgba(),
      );
    }
    final color = night ? Colors.redAccent : Colors.white;
    return [
      _viewshedImage!,
      MapCircle(
        center: v.params.observer,
        radiusMeters: v.params.radius,
        fillColor: Colors.transparent,
        strokeColor: color.withValues(alpha: 0.7),
        strokeWidth: 1.5,
      ),
      MapMarker(
        id: 'viewshed:observer',
        imageKey: 'viewshed:observer:${color.toARGB32()}',
        point: v.params.observer,
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(Icons.visibility, color: color, size: 18),
        ),
      ),
    ];
  }

  /// Arazi analizi: renkli katman (resim) ve eş yükselti eğrileri.
  List<MapOverlay> _terrainOverlays(TerrainAnalysisState? t, bool night) {
    if (t == null) return const [];
    final out = <MapOverlay>[];
    final img = t.image;
    if (img != null) {
      if (!identical(img, _terrainFor)) {
        _terrainFor = img;
        _terrainImage = MapImage(
          id: 'terrain',
          north: img.north,
          south: img.south,
          east: img.east,
          west: img.west,
          width: img.width,
          height: img.height,
          pixels: img.pixels,
        );
      }
      out.add(_terrainImage!);
    }
    final interval = t.interval;
    if (interval == null) return out;
    final color = night ? Colors.redAccent : const Color(0xFFE8B060);
    // Her beşinci eğri (ana eğri) kalın ve etiketli; etiket sayısı sınırlı.
    bool major(double level) => (level / (interval * 5)).round() * interval * 5 == level;
    var labels = 0;
    for (final c in t.contours) {
      if (c.points.length < 2) continue;
      final isMajor = major(c.level);
      out.add(MapLine(
        points: c.points,
        width: isMajor ? 2 : 1,
        color: color.withValues(alpha: isMajor ? 0.95 : 0.7),
      ));
      if (isMajor && c.points.length >= 12 && labels < 40) {
        labels++;
        final at = c.points[c.points.length ~/ 2];
        out.add(_labelMarker(
          id: 'contour:$labels',
          text: '${c.level.round()}',
          color: color,
          point: at,
          onTap: () => showTerrainAnalysisPanel(context,
              mapCenter: () => _map.camera.center),
        ));
      }
    }
    return out;
  }

  /// Lasso çizildi: içindeki görünür nesneler seçilir, seçim paneli açılır.
  Future<void> _finishLasso(List<Offset> points) async {
    final ll = await _map.latLngsAt(points);
    if (!mounted) return;
    if (ll == null || ll.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Seçmek için bir alanın çevresini çiz.')));
      return;
    }
    final sel = ref.read(selectionProvider.notifier).select(ll);
    setState(() => _lassoMode = false);
    if (sel.isEmpty) {
      ref.read(selectionProvider.notifier).clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seçilen alanda nesne yok.')));
      return;
    }
    showSelectionPanel(context);
  }

  /// Serbest çizim bitti: ekran noktaları konuma çevrilip araca verilir.
  Future<void> _finishFreehand(List<Offset> points) async {
    final ll = await _map.latLngsAt(points);
    if (ll == null || ll.length < 2 || !mounted) return;
    ref.read(toolProvider.notifier).setPath(ll);
  }

  void _openBullseye() {
    showBullseyePanel(
      context,
      mapCenter: () => _map.camera.center,
      onCenter: _centerOn,
    );
  }

  void _openSavedViews() {
    showSavedViewsSheet(
      context,
      current: (name) {
        final cam = _map.camera;
        return SavedView(
          id: '',
          name: name,
          center: cam.center,
          zoom: cam.zoom,
          bearing: cam.bearing,
          layerId: _selected.id,
          createdAt: DateTime.now(),
        );
      },
      onApply: _applySavedView,
      layerLabel: (id) => _layerById(id)?.label,
    );
  }

  /// Katman kimliğinden tanım: gömülü ya da içe aktarılmış.
  BaseLayerDef? _layerById(String? id) {
    if (id == null) return null;
    for (final l in kBaseLayers) {
      if (l.id == id) return l;
    }
    for (final l in ref.read(importedLayersProvider).value ??
        const <ImportedLayer>[]) {
      if (l.id == id) return _importedToDef(l);
    }
    return null;
  }

  /// Görünüme dön: harita kaynağını seç (yüklenmesini bekle), sonra kamera.
  /// Takip ve yön-yukarı kapanır (açık kalsa kamerayı geri çekerdi).
  Future<void> _applySavedView(SavedView v) async {
    final layer = _layerById(v.layerId);
    final usable = layer != null && layer.isAvailable;
    setState(() {
      _follow = false;
      _trackUp = false;
      if (usable) _selected = layer;
    });
    if (usable) await _ensureResolved(layer);
    if (!mounted) return;
    _map.moveTo(v.center, zoom: v.zoom);
    _map.rotateTo(v.bearing);
    if (!usable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Görünümün harita kaynağı bulunamadı; mevcut haritada '
            'açıldı.'),
      ));
    }
  }

  /// İçe-aktarılmış katmanı (drift modeli) harita BaseLayerDef'ine çevirir.
  BaseLayerDef _importedToDef(ImportedLayer l) {
    return BaseLayerDef(
      id: l.id,
      label: l.label,
      icon: l.isVector ? Icons.public : Icons.map_outlined,
      type: l.sourceType == 'gpkg'
          ? BaseLayerSourceType.offlineGpkg
          : l.isVector
              ? BaseLayerSourceType.vectorPmtiles
              : BaseLayerSourceType.offlineMbtiles,
      fileName: l.fileName,
      stylePath: l.stylePath,
      maxNativeZoom: l.maxZoom,
      center: (l.centerLat != null && l.centerLon != null)
          ? LatLng(l.centerLat!, l.centerLon!)
          : null,
    );
  }

  /// Dosyalar'dan harita paketi içe aktar → kaydet → seç → göster.
  Future<void> _importLayer() async {
    final r = await pickAndImportLayer(context, ref);
    if (r == null || !mounted) return;
    final imported = r.imported;
    final def = imported != null
        ? _importedToDef(imported)
        : kBaseLayers.firstWhere((l) => l.id == r.builtInId);
    _selectLayer(def);
  }

  /// İçe-aktarılmış katmanı sil (drift kaydı + Documents dosyası + bellek).
  Future<void> _deleteImportedLayer(ImportedLayer l) async {
    Navigator.of(context).pop(); // menüyü kapat
    if (_selected.id == l.id) {
      final fallback = kBaseLayers.first;
      setState(() => _selected = fallback);
      await _ensureResolved(fallback);
      _recenterToLayer(fallback);
    }
    await ref.read(importedLayerRepositoryProvider).delete(l.id);
    _resolved.remove(l.id);
    _map.releaseBaseLayer(l.id);
    _layerBounds.remove(l.id);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/${l.fileName}');
      if (await f.exists()) await f.delete();
    } catch (_) {/* dosya yoksa yok say */}
  }

  /// Tek birleşik menü: veri & araçlar + harita katmanı + görünüm ayarları.
  /// ▤ Katmanlar: taban harita, içe aktarılan paketler, çevrimdışı bölgeler.
  void _openLayers() {
    showAdaptiveSheet<void>(
      context: context,
      id: 'layers',
      toggle: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final imported =
            ref.watch(importedLayersProvider).value ?? const <ImportedLayer>[];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Katmanlar',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Harita paketi içe aktar'),
                  subtitle: const Text('.pmtiles / .mbtiles — Dosyalar\'dan'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _importLayer();
                  },
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
                    subtitle: !layer.isAvailable
                        ? Text(layer.type == BaseLayerSourceType.mapboxStyle
                            ? 'Mapbox anahtarı yok'
                            : 'henüz eklenmedi')
                        : _knownMissing(layer)
                            ? const Text('dosya yok · dokun: nasıl eklenir',
                                style: TextStyle(color: Colors.orangeAccent))
                            : layer.hint == null
                                ? null
                                : Text(layer.hint!),
                    trailing: layer.id == _selected.id
                        ? const Icon(Icons.check,
                            color: Colors.lightGreenAccent)
                        : null,
                    onTap: () => _onLayerTapped(layer),
                  ),
                // İçe-aktarılmış katmanlar (sil edilebilir).
                for (final l in imported)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 2),
                    leading: Icon(l.isVector ? Icons.public : Icons.map_outlined),
                    title: Text(
                      l.label,
                      style: TextStyle(
                        fontWeight: l.id == _selected.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(l.sourceType == 'gpkg'
                        ? 'içe aktarılan raster (GeoPackage)'
                        : l.isVector
                            ? 'içe aktarılan vektör'
                            : 'içe aktarılan raster'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (l.id == _selected.id)
                          const Icon(Icons.check,
                              color: Colors.lightGreenAccent),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Sil',
                          onPressed: () => _deleteImportedLayer(l),
                        ),
                      ],
                    ),
                    onTap: () => _onLayerTapped(_importedToDef(l)),
                  ),

                const Divider(),
                Consumer(builder: (context, ref, _) {
                  final regions =
                      ref.watch(offlineRegionsProvider).value ?? const [];
                  final total =
                      regions.fold<int>(0, (s, r) => s + r.sizeBytes);
                  return ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text('Çevrimdışı haritalar'),
                    subtitle: Text(regions.isEmpty
                        ? 'bölge indir · sinyalsiz kullan'
                        : '${regions.length} bölge · ${fmtBytes(total)}'),
                    onTap: () {
                      Navigator.of(context).pop();
                      showOfflineRegionsSheet(
                        this.context,
                        onShowRegion: _showRegion,
                        onNewRegion: _startFraming,
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// "+" düğmesi: araç açıksa imleçteki noktayı araca ekler, değilse
  /// imleçteki yere nokta (waypoint) ekleme penceresini açar.
  void _addAtCrosshair() {
    final p = _map.camera.center;
    if (_shapeEdit != null) {
      _shapeEditTap(p);
      return;
    }
    if (_moving != null) {
      _finishMove(p);
      return;
    }
    if (_placingSelf) {
      _setManualPosition(p);
      return;
    }
    if (_dropMode) {
      _dropPoint(p);
      return;
    }
    if (ref.read(routePlanningProvider).active) {
      ref.read(routePlanningProvider.notifier).addPoint(p);
      return;
    }
    if (ref.read(toolProvider).active) {
      ref.read(toolProvider.notifier).addPoint(p);
    } else {
      HapticFeedback.mediumImpact();
      showAddWaypointDialog(context, ref, p);
    }
  }

  void _openCoordinate() {
    showCoordinateSheet(
      context,
      crosshair: _map.camera.center,
      onShowOnMap: (p) {
        setState(() => _follow = false);
        final z = _map.camera.zoom;
        _map.moveTo(p, zoom: z < 15 ? 15.0 : z);
      },
      onSaveHere: (p) => showAddWaypointDialog(context, ref, p),
      onNavigateHere: (p) {
        ref.read(navTargetProvider.notifier).set(p, CoordFormat.mgrs(p));
      },
    );
  }

  /// ≡ Bütün araçlar (ATAK Additional Tools). Bugünkü alt çubuk, Görevler ve
  /// araç paletindeki her şey burada.
  void _openToolsGrid() {
    final tool = ref.read(toolProvider);
    void setTool(ToolMode m) {
      setState(() => _dropMode = false);
      ref.read(toolProvider.notifier).setMode(m);
    }

    ToolGridItem toolItem(ToolMode m, IconData icon, String label) =>
        ToolGridItem(
          icon: icon,
          label: label,
          active: tool.mode == m,
          onTap: () => setTool(m),
        );

    // Araç çubuğuna konabilen araçlar burada da var (çubuktan çıkan araç
    // kaybolmasın); görünüm ve iş tek yerden: _toolbarItem.
    ToolGridItem catalog(ToolbarTool t) {
      final item = _toolbarItem(t);
      return ToolGridItem(
        icon: item.icon,
        label: t.label,
        active: item.active,
        onTap: item.onTap,
      );
    }

    showToolsGridSheet(context, sections: [
      ToolGridSection('Navigasyon', [
        catalog(ToolbarTool.goTo),
        catalog(ToolbarTool.bloodhound),
        catalog(ToolbarTool.resection),
        catalog(ToolbarTool.tacticalCompass),
        catalog(ToolbarTool.routes),
      ]),
      ToolGridSection('Ölçüm', [
        toolItem(ToolMode.distance, Icons.straighten, 'Mesafe / R&B'),
        toolItem(ToolMode.polygon, Icons.pentagon_outlined, 'Alan'),
        toolItem(ToolMode.sector, Icons.pie_chart_outline, 'Sektör'),
        toolItem(ToolMode.rangeRings, Icons.radar, 'Menzil halkası'),
        toolItem(ToolMode.lineOfSight, Icons.landscape_outlined, 'Görüş hattı'),
        catalog(ToolbarTool.bullseye),
        catalog(ToolbarTool.viewshed),
        catalog(ToolbarTool.terrainAnalysis),
      ]),
      ToolGridSection('Veri', [
        catalog(ToolbarTool.dropPoint),
        catalog(ToolbarTool.record),
        catalog(ToolbarTool.waypoints),
        catalog(ToolbarTool.tracks),
        catalog(ToolbarTool.draw),
        catalog(ToolbarTool.lasso),
        catalog(ToolbarTool.quickPic),
        catalog(ToolbarTool.gallery),
        catalog(ToolbarTool.geofence),
        catalog(ToolbarTool.graphics),
        // G7: KMZ / KML / GPX / GeoJSON.
        ToolGridItem(
            icon: Icons.file_open_outlined,
            label: 'İçe aktar',
            onTap: () => runImport(context, ref)),
        ToolGridItem(
            icon: Icons.ios_share,
            label: 'Dışa aktar',
            onTap: () => showExportSheet(context)),
      ]),
      ToolGridSection('Saha', [
        catalog(ToolbarTool.reports),
        catalog(ToolbarTool.weather),
        catalog(ToolbarTool.sunMoon),
      ]),
      ToolGridSection('Harita', [
        catalog(ToolbarTool.maps),
        catalog(ToolbarTool.overlays),
        catalog(ToolbarTool.savedViews),
        catalog(ToolbarTool.clearMap),
        catalog(ToolbarTool.elevationData),
        catalog(ToolbarTool.offlineRegions),
        ToolGridItem(
            icon: Icons.file_download_outlined,
            label: 'Harita paketi içe aktar',
            onTap: _importLayer),
      ]),
      ToolGridSection('Sistem', [
        catalog(ToolbarTool.settings),
        ToolGridItem(
            icon: Icons.view_week_outlined,
            label: 'Araç çubuğu',
            onTap: () => showToolbarManagerSheet(context)),
        ToolGridItem(
            icon: Icons.backup_outlined,
            label: 'Yedekle / geri yükle',
            onTap: () => showBackupPanel(context)),
        ToolGridItem(
          icon: Icons.delete_forever,
          label: 'Acil veri silme',
          color: Colors.redAccent,
          onTap: () => showClearContentDialog(context, ref),
        ),
      ]),
    ]);
  }

  /// Bir aracın düğmesi: ikon, ad, iş ve açık/kapalı durumu. Araç çubuğu ve
  /// ≡ ızgarası ikisi de bunu kullanır. Durumları ref.read ile okur: harita
  /// ekranı kayıt/araç/rota/gece/artı imleç sağlayıcılarını build'de zaten
  /// izliyor (ref.watch), değişince çubuk yeniden çizilir.
  ToolbarItem _toolbarItem(ToolbarTool t) {
    switch (t) {
      case ToolbarTool.dropPoint:
        return ToolbarItem(
            icon: t.icon, label: t.label, active: _dropMode, onTap: _onDropPoint);
      case ToolbarTool.measure:
        final tool = ref.read(toolProvider);
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: _rangeBarOpen || (tool.active && !tool.mode.isDrawing),
          // R&B: ölçüm araçları çubuğunu aç/kapat.
          onTap: () {
            final t = ref.read(toolProvider);
            final open = !(_rangeBarOpen || (t.active && !t.mode.isDrawing));
            if (!open || t.mode.isDrawing) {
              ref.read(toolProvider.notifier).reset();
            }
            setState(() {
              _rangeBarOpen = open;
              _drawBarOpen = false;
              _dropMode = false;
            });
          },
        );
      case ToolbarTool.quickPic:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => quickPic(context, ref,
              fallback: () => _map.camera.center, onCenter: _centerOn),
        );
      case ToolbarTool.gallery:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showGalleryPanel(context, onCenter: _centerOn),
        );
      case ToolbarTool.reports:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showReportsPanel(
            context,
            fallback: () => _map.camera.center,
          ),
        );
      case ToolbarTool.weather:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showWeatherPanel(
            context,
            fallback: () => _map.camera.center,
          ),
        );
      case ToolbarTool.sunMoon:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showSunMoonPanel(
            context,
            fallback: () => _map.camera.center,
          ),
        );
      case ToolbarTool.geofence:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showGeofencePanel(context, onCenter: _centerOn),
        );
      case ToolbarTool.lasso:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: _lassoMode,
          onTap: () {
            ref.read(toolProvider.notifier).reset();
            setState(() {
              _lassoMode = !_lassoMode;
              _drawBarOpen = false;
              _rangeBarOpen = false;
              _dropMode = false;
            });
          },
        );
      case ToolbarTool.draw:
        final tool = ref.read(toolProvider);
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: _drawBarOpen || tool.mode.isDrawing,
          // Çizim araçları çubuğunu aç/kapat.
          onTap: () {
            final open = !(_drawBarOpen || ref.read(toolProvider).mode.isDrawing);
            ref.read(toolProvider.notifier).reset();
            setState(() {
              _drawBarOpen = open;
              _rangeBarOpen = false;
              _dropMode = false;
            });
          },
        );
      case ToolbarTool.goTo:
        return ToolbarItem(icon: t.icon, label: t.label, onTap: _openCoordinate);
      case ToolbarTool.maps:
        return ToolbarItem(icon: t.icon, label: t.label, onTap: _openLayers);
      case ToolbarTool.record:
        final on = ref.read(recordingProvider).isRecording;
        return ToolbarItem(
          icon: on ? Icons.stop_circle : t.icon,
          label: on ? 'İz kaydını durdur' : 'İz kaydını başlat',
          active: on,
          accent: Colors.red.shade700,
          activeForeground: Colors.white,
          haptic: HapticFeedback.mediumImpact,
          onTap: () {
            final n = ref.read(recordingProvider.notifier);
            ref.read(recordingProvider).isRecording ? n.stop() : n.start();
          },
        );
      case ToolbarTool.routes:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: ref.read(activeRouteProvider) != null,
          onTap: () => showRouteSheet(
            context,
            onPlanNew: _startRoutePlanning,
            onShowRoute: _showRoute,
          ),
        );
      case ToolbarTool.waypoints:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showWaypointListSheet(context, ref,
              onTapWaypoint: (wp) => _centerOn(wp.position)),
        );
      case ToolbarTool.tracks:
        return ToolbarItem(
            icon: t.icon,
            label: t.label,
            onTap: () => showTrackListSheet(context, ref));
      case ToolbarTool.graphics:
        return ToolbarItem(
            icon: t.icon,
            label: t.label,
            onTap: () => showGraphicListSheet(context, ref));
      case ToolbarTool.offlineRegions:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          onTap: () => showOfflineRegionsSheet(
            context,
            onShowRegion: _showRegion,
            onNewRegion: _startFraming,
          ),
        );
      case ToolbarTool.overlays:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: !ref.read(overlayVisibilityProvider).isDefault,
          onTap: () => showOverlayManagerSheet(
            context,
            onCenter: _centerOn,
            onShowRoute: _showRoute,
          ),
        );
      case ToolbarTool.savedViews:
        return ToolbarItem(
            icon: t.icon, label: t.label, onTap: _openSavedViews);
      case ToolbarTool.elevationData:
        return ToolbarItem(
            icon: t.icon,
            label: t.label,
            onTap: () =>
                showElevationDataPanel(context, onCenter: _centerOn));
      case ToolbarTool.clearMap:
        return ToolbarItem(
            icon: t.icon,
            label: t.label,
            onTap: () => showClearMapSheet(context));
      case ToolbarTool.bloodhound:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: ref.read(bloodhoundsProvider).isNotEmpty,
          onTap: _openBloodhounds,
        );
      case ToolbarTool.tacticalCompass:
        return ToolbarItem(
            icon: t.icon,
            label: t.label,
            onTap: () => showTacticalCompass(context));
      case ToolbarTool.resection:
        return ToolbarItem(
            icon: t.icon, label: t.label, onTap: _openResection);
      case ToolbarTool.viewshed:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: ref.read(viewshedProvider)?.grid != null,
          onTap: () => _openViewshed(),
        );
      case ToolbarTool.terrainAnalysis:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: ref.read(terrainAnalysisProvider) != null,
          onTap: () => showTerrainAnalysisPanel(context,
              mapCenter: () => _map.camera.center),
        );
      case ToolbarTool.bullseye:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: ref.read(bullseyeProvider) != null,
          onTap: _openBullseye,
        );
      case ToolbarTool.nightMode:
        final on = ref.read(nightModeProvider);
        return ToolbarItem(
          icon: on ? Icons.nightlight_round : t.icon,
          label: t.label,
          active: on,
          onTap: () => ref.read(nightModeProvider.notifier).toggle(),
        );
      case ToolbarTool.crosshair:
        return ToolbarItem(
          icon: t.icon,
          label: t.label,
          active: ref.read(crosshairProvider),
          onTap: () => ref.read(crosshairProvider.notifier).toggle(),
        );
      case ToolbarTool.settings:
        return ToolbarItem(
            icon: t.icon,
            label: t.label,
            onTap: () => showSettingsSheet(context));
    }
  }

  String _nextDropName(DropKind k, List<Waypoint> waypoints) =>
      nextSequentialName(
          k.prefix, [for (final w in waypoints) w.name, ..._droppedNames]);

  /// Point Dropper: seçili türde, sıra numaralı adla, diyalogsuz nokta.
  Future<void> _dropPoint(LatLng p) async {
    HapticFeedback.mediumImpact();
    final k = ref.read(dropKindProvider);
    final name = _nextDropName(
        k, ref.read(waypointsProvider).value ?? const <Waypoint>[]);
    _droppedNames.add(name);
    await ref
        .read(waypointRepositoryProvider)
        .add(name: name, position: p, affiliation: k.affiliation, role: k.role);
  }

  /// Araç çubuğu "Nokta bırak": Point Dropper paletini açar/kapatır.
  /// Palet açıkken haritaya her dokunuş nokta bırakır; artı imleç açıksa
  /// palette "İmlece bırak" da var.
  void _onDropPoint() {
    final on = !_dropMode;
    if (on) ref.read(toolProvider.notifier).reset();
    setState(() {
      _dropMode = on;
      if (on) {
        _rangeBarOpen = false;
        _drawBarOpen = false;
        _moving = null;
        _placingSelf = false;
      }
    });
  }

  void _toggleRotationLock() {
    setState(() => _rotationLocked = !_rotationLocked);
    _map.setRotationLocked(_rotationLocked);
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
    final showRepeaters = ref.watch(showRepeatersProvider);
    final band = ref.watch(repeaterBandProvider);
    final repeaters = showRepeaters
        ? (ref.watch(repeatersProvider).value ?? const <Repeater>[])
            .where((r) => band == null || r.band == band)
            .toList()
        : const <Repeater>[];
    final selectedRepeater =
        showRepeaters ? ref.watch(selectedRepeaterProvider) : null;
    final navTarget = ref.watch(navTargetProvider);
    // Kayıt düğmesi (araç çubuğu / ızgara) kayıt durumunu ref.read ile okur;
    // değişince çubuk yeniden çizilsin diye burada izlenir.
    ref.watch(recordingProvider);
    final planning = ref.watch(routePlanningProvider);
    final activeRoute = ref.watch(activeRouteProvider);
    // Rota noktasına varınca titreşim + bilgi.
    ref.listen<ActiveRouteState?>(activeRouteProvider, (prev, next) {
      final a = prev?.progress, b = next?.progress;
      if (a == null || b == null || b.targetIndex <= a.targetIndex) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(b.finished
            ? 'Rota tamamlandı: ${next!.route.name}'
            : 'Nokta ${a.targetIndex + 1} geçildi → sıradaki ${b.targetIndex + 1}'),
      ));
    });
    final currentTrack =
        ref.watch(currentTrackPointsProvider).value ?? const <TrackPoint>[];
    final displayedTrack =
        ref.watch(displayedTrackPointsProvider).value ?? const <TrackPoint>[];
    final tool = ref.watch(toolProvider);
    final graphics = ref.watch(mapGraphicsProvider).value ?? const <MapGraphic>[];
    // Overlay yöneticisi: gizlenen grup/nesne ve etiket süzgeci.
    final visibility = ref.watch(overlayVisibilityProvider);
    // Kalıcı R&B çizgileri, uçları bağlı nesnelere göre çözülmüş.
    final rangeLines = [
      for (final r in ref.watch(resolvedRangeLinesProvider))
        if (visibility.showsRangeLine(r.line)) r,
    ];
    // Kalıcı menzil / tehdit halkaları (merkez bağlıysa onunla gider).
    final rangeRings = [
      for (final r in ref.watch(resolvedRangeRingsProvider))
        if (visibility.showsRangeRing(r.ring)) r,
    ];
    final bearingFmt = ref.watch(bearingFormatterProvider);
    final bullseye = ref.watch(resolvedBullseyeProvider);
    final bloodhounds = ref.watch(resolvedBloodhoundsProvider);
    final resection = ref.watch(resectionPreviewProvider);
    final viewshed = ref.watch(viewshedProvider);
    final selection = ref.watch(selectionProvider);
    // Geofence: giriş / çıkışta güçlü titreşim + uyarı (dinlemek izleyiciyi
    // de canlı tutar).
    ref.listen<GeofenceState>(geofenceProvider, (prev, next) {
      if (identical(prev?.latest, next.latest) || next.latest.isEmpty) return;
      HapticFeedback.heavyImpact();
      final text = next.latest
          .map((e) => '${e.name}: ${e.entered ? 'girildi' : 'çıkıldı'}')
          .join(' · ');
      // Önde: sesli; arka planda: bildirim.
      final alerts = ref.read(alertDispatcherProvider);
      for (final e in next.latest) {
        final what = e.entered ? 'Alana girildi' : 'Alandan çıkıldı';
        final t = e.at.toLocal();
        alerts.alert(
          title: 'Geofence: ${e.name}',
          body: '$what (${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')})',
          speech: '${spokenName(e.name)}. $what.',
        );
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: Colors.orange.shade900,
          duration: const Duration(seconds: 8),
          persist: false,
          content: Text('Geofence — $text'),
          action: SnackBarAction(
            label: 'Liste',
            textColor: Colors.white,
            onPressed: () => showGeofencePanel(context, onCenter: _centerOn),
          ),
        ));
    });
    final terrain = ref.watch(terrainAnalysisProvider);
    // Yükseklik verisi kapsamı (Yükseklik verisi panelinden açılır).
    final elevationTiles = ref.watch(showElevationCoverageProvider)
        ? ref.watch(elevationTilesProvider).value ??
            const <ElevationTileInfo>[]
        : const <ElevationTileInfo>[];
    // Rota takibi: nokta geçildi / rota bitti / saptın → titreşim + uyarı.
    ref.listen<ActiveRouteState?>(activeRouteProvider, (prev, next) {
      final p = next?.progress;
      if (prev == null || next == null || p == null) return;
      if (prev.route.uid != next.route.uid) return;
      final self = ref.read(selfContactProvider)?.position;
      final a = routeAlert(prev.progress, p, next.route,
          bearing: (b) => self == null
              ? GeoMath.fmtBearing(b)
              : bearingFmt.format(b, self));
      if (a == null) return;
      a.strong ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
      ref
          .read(alertDispatcherProvider)
          .alert(title: 'Rota: ${next.route.name}', body: a.text, speech: a.speech);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(a.text)));
    });
    // Bir takip gerçek hızla kırmızı eşiğe girince bir kez titret + söyle
    // (ATAK'ta çizgi yanıp söner). Duruyorken (tahmini ETA) uyarmaz.
    ref.listen<List<ResolvedBloodhound>>(resolvedBloodhoundsProvider,
        (prev, next) {
      final before = {
        for (final r in prev ?? const <ResolvedBloodhound>[])
          r.bloodhound.id: r.reading.level,
      };
      for (final r in next) {
        if (r.reading.level == EtaLevel.close &&
            !r.reading.estimated &&
            before[r.bloodhound.id] != EtaLevel.close) {
          HapticFeedback.heavyImpact();
          final eta = r.reading.eta!;
          ref.read(alertDispatcherProvider).alert(
                title: 'Takip',
                body: 'Varışa ${NavMath.fmtDuration(eta)}',
                speech: 'Takip. Varışa ${spokenDuration(eta)}.',
              );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Takip: varışa ${NavMath.fmtDuration(eta)}'),
          ));
        }
      }
    });
    final nightMode = ref.watch(nightModeProvider);
    final showGpsCircle = ref.watch(showGpsCircleProvider);
    final dropKind = ref.watch(dropKindProvider);
    final showRose = ref.watch(showCompassRoseProvider);
    final showTrail = ref.watch(showRecentTrailProvider);
    // Her zaman izlenir: seçenek kapalıyken de son 15 dk toplansın.
    final recentTrail = ref.watch(recentTrailProvider);
    // Seçili katmanın dosyası cihazda yok (ör. Türkiye paketi kopyalanmamış).
    final layerMissing = _missingFiles.contains(_selected.id);
    // Seçili çevrimdışı katman henüz çözülmediyse (tembel) göstergede uyar.
    final layerLoading = !layerMissing &&
        (_selected.type == BaseLayerSourceType.offlineMbtiles ||
            _selected.type == BaseLayerSourceType.vectorPmtiles ||
            _selected.type == BaseLayerSourceType.offlineGpkg) &&
        !_resolved.containsKey(_selected.id);

    // Yerleşim: dikeyde alt çubuk; yatayda (ATAK gibi) sol dikey şerit,
    // sağdan yan paneller, dar HUD — harita olabildiğince açık kalsın.
    // ATAK düzeni (kılavuz s.5): sol üstte araç çubuğu, altında pusula/◎/zoom
    // sütunu; sol altta bilgi kutuları + ölçek; sağ altta konum kutusu.
    final landscape = isLandscape(context);
    // Açık panelin haritadan kapladığı kenar (yatay: sağ, dikey: alt).
    final panelInsets = PanelHost.insetsOf(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final safe = MediaQuery.paddingOf(context);
    final safeBottom = safe.bottom;
    final bottomInset = safeBottom;
    final crosshairOn = ref.watch(crosshairProvider);
    // Araç seçilince nokta bırakma modu kapanır (aynı anda tek dokunuş işi).
    ref.listen<ToolState>(toolProvider, (prev, next) {
      if (next.active &&
          (_dropMode || _moving != null || _placingSelf || _lassoMode)) {
        setState(() {
          _dropMode = false;
          _moving = null;
          _placingSelf = false;
          _lassoMode = false;
        });
      }
    });

    // Harita üstü çizimler — liste sırası = çizim sırası (alttan üste).
    final overlays = <MapOverlay>[
      // Lasso seçim alanı (seçim paneli açıkken).
      if (selection != null && selection.polygon.length >= 3)
        MapArea(
          points: selection.polygon,
          fillColor: Colors.cyanAccent.withValues(alpha: 0.08),
          strokeColor: Colors.cyanAccent,
          strokeWidth: 2,
          dashed: true,
        ),
      // Arazi analizi (renkli katman + eş yükselti eğrileri) ve görüş alanı.
      ..._terrainOverlays(terrain, nightMode),
      ..._viewshedOverlays(viewshed, nightMode),
      // İndirilmiş bölgelerin sınırları (çerçevelerken hepsi, yoksa seçilen).
      ..._regionOutlines(),
      // Yükseklik verisi kareleri (1°×1°).
      for (final t in elevationTiles)
        MapArea(
          points: [
            LatLng(t.south.toDouble(), t.west.toDouble()),
            LatLng(t.south.toDouble(), t.west + 1.0),
            LatLng(t.south + 1.0, t.west + 1.0),
            LatLng(t.south + 1.0, t.west.toDouble()),
          ],
          fillColor: Colors.cyanAccent.withValues(alpha: 0.06),
          strokeColor: Colors.cyanAccent.withValues(alpha: 0.8),
          strokeWidth: 1.5,
        ),
      // Kalıcı taktik grafikler (çizgi/alan).
      ..._graphicOverlays([
        for (final g in graphics)
          if (visibility.showsGraphic(g) && g.uid != _shapeEdit?.graphic.uid)
            g,
        ?_shapeEdit?.preview,
      ]),
      // Bullseye: halkalar + 30°'de bir ışın (seçili kuzeye hizalı).
      if (bullseye != null)
        ..._bullseyeOverlays(bullseye, bearingFmt.ref, nightMode),
      // Görüş konileri (nokta gizlenince konisi de gizlenir).
      for (final wp in waypoints)
        if (wp.fov != null && visibility.showsWaypoint(wp))
          MapArea(
            points: wp.fov!.polygon(wp.position),
            fillColor: affiliationColor(wp.affiliation).withValues(alpha: 0.16),
            strokeColor:
                affiliationColor(wp.affiliation).withValues(alpha: 0.8),
            strokeWidth: 1.5,
          ),
      // Kalıcı menzil halkaları: içten dışa solan çizgi, içte hafif dolgu.
      for (final r in rangeRings) ..._rangeRingCircles(r, nightMode),
      // Kalıcı R&B çizgileri (etiketleri işaretçilerle birlikte, üstte).
      for (final r in rangeLines)
        MapLine(
          points: [r.from, r.to],
          width: 3,
          color: nightMode ? Colors.redAccent : Color(r.line.colorValue),
        ),
      // Takipler (Bloodhound): ETA rengine göre.
      for (final r in bloodhounds)
        MapLine(
          points: [r.from, r.to],
          width: 4,
          color: etaColor(r.reading.level),
        ),
      // Geriden kestirme önizlemesi (panel açıkken).
      if (resection != null) ..._resectionOverlays(resection),
      // Aktif ölçüm/çizim aracı.
      ..._toolOverlays(tool),
      // Rota: planlanan / takip edilen / önizlenen.
      ..._routeOverlays(planning, activeRoute, self?.position),
      // Navigasyon çizgisi (kendi konum → hedef).
      if (navTarget != null && self != null)
        MapLine(
          points: [self.position, navTarget.position],
          width: 3,
          color: nightMode ? Colors.redAccent : Colors.limeAccent,
        ),
      // Seçili kayıtlı iz (camgöbeği).
      if (displayedTrack.length >= 2)
        MapLine(
          points: [for (final p in displayedTrack) p.position],
          width: 4,
          color: Colors.cyanAccent,
        ),
      // Kayıttaki canlı iz (turuncu).
      if (currentTrack.length >= 2)
        MapLine(
          points: [for (final p in currentTrack) p.position],
          width: 4,
          color: Colors.orangeAccent,
        ),
      if (selectedRepeater != null)
        MapCircle(
          center: selectedRepeater.position,
          radiusMeters: 30000, // ~30 km kaba kapsama
          fillColor: Colors.tealAccent.withValues(alpha: 0.10),
          strokeColor: Colors.tealAccent.withValues(alpha: 0.6),
          strokeWidth: 1.5,
        ),
      for (final r in repeaters) _repeaterMarker(r),
      for (final wp in waypoints)
        if (visibility.showsWaypoint(wp)) _waypointMarker(wp),
      for (final r in rangeLines) _rangeLabelMarker(r, bearingFmt, nightMode),
      for (final r in bloodhounds)
        _labelMarker(
          id: 'bh:${r.bloodhound.id}',
          text: bloodhoundText(r.reading, r.from, bearingFmt),
          color: etaColor(r.reading.level),
          point: r.middle,
          onTap: () => _onObjectTap(
            r.middle,
            title: 'Takip',
            actions: () => _bloodhoundActions(r),
          ),
        ),
      for (final r in rangeRings) ..._rangeRingLabels(r, nightMode),
      if (bullseye != null)
        ..._bullseyeMarkers(bullseye, bearingFmt, nightMode),
      // Son 15 dakikanın izi (kendi işaret menüsünden açılır).
      if (showTrail && self != null && recentTrail.isNotEmpty)
        MapLine(
          points: [...recentTrail, self.position],
          width: 3,
          color: (nightMode ? Colors.redAccent : Colors.lightBlueAccent)
              .withValues(alpha: 0.7),
        ),
      // Pusula gülü (kendi işaret menüsünden açılır).
      if (showRose && self != null)
        ...compassRoseOverlays(
          self.position,
          roseRadiusMeters(
            _roseZoom ?? (_map.camera.zoom * 2).round() / 2,
            self.position.latitude,
          ),
          night: nightMode,
        ),
      // GPS doğruluk dairesi (ATAK GPS Error Overlay).
      if (showGpsCircle && self != null && (self.accuracyMeters ?? 0) > 0)
        MapCircle(
          center: self.position,
          radiusMeters: self.accuracyMeters!,
          fillColor: (nightMode ? Colors.redAccent : Colors.lightBlueAccent)
              .withValues(alpha: 0.12),
          strokeColor: (nightMode ? Colors.redAccent : Colors.lightBlueAccent)
              .withValues(alpha: 0.55),
          strokeWidth: 1,
        ),
      if (self != null) _selfMarker(self),
      // Şekil düzenleme tutamaçları en üstte.
      if (_shapeEdit != null)
        ...shapeEditHandles(
          _shapeEdit!,
          night: nightMode,
          onVertex: (i) => _shapeEditSelect(i),
          onMidpoint: (i) {
            HapticFeedback.selectionClick();
            setState(() => _shapeEdit = _shapeEdit?.insertMidpoint(i));
          },
          onMoveAll: () => _shapeEditSelect(ShapeEditState.moveAll),
        ),
    ];

    return Scaffold(
      body: _wrapNight(
        nightMode,
        Stack(
        // Ekranı doldur: bütün kontroller Positioned olduğu için Stack kendini
        // çocuklarından boyutlandıramaz (yoksa 0×0'a büzülür → siyah ekran).
        fit: StackFit.expand,
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
                if (AppConstants.mapboxAccessToken.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Mapbox anahtarı yok.\n\nUygulamayı şöyle derleyin:\n'
                        'flutter run --dart-define-from-file=dart_defines.json',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ValueListenableBuilder<EdgeInsets>(
                  valueListenable: panelInsets,
                  builder: (context, panel, _) => kMapEngine.buildView(
                    terrain3d: _terrain3d && kMapEngine.supportsTerrain,
                    // Logo/atıf alttaki panelin (çerçevelerken bölge panelinin)
                    // üstünde kalsın. Güvenli alana EK olarak haritayı örten
                    // arayüz (Mapbox iOS kenar boşluklarını güvenli alandan
                    // ölçer; bkz. map_engine).
                    ornamentPadding: _framing
                        ? EdgeInsets.only(bottom: landscape ? 0 : 300)
                        : EdgeInsets.only(
                            bottom: math.max(0, panel.bottom - safeBottom)),
                    nightMode: nightMode,
                    controller: _map,
                    baseLayer: _resolved[_selected.id] ?? const NoBaseLayer(),
                    overlays: overlays,
                    initialCamera: _lastCamera,
                    // Motor değişince yeni harita hazır olunca katman alanına git.
                    onReady: () => _recenterToLayer(_selected),
                    minZoom: AppConstants.minZoom,
                    maxZoom: AppConstants.maxZoom,
                    // Kullanıcı elle kaydırınca takibi bırak.
                    onCameraChanged: (camera, byGesture) {
                      _lastCamera = camera;
                      _scaleCamera.value = camera;
                      if (_framing) _cameraTick.value++;
                      if (_radial != null) _repositionRadial();
                      final roseZoom = (camera.zoom * 2).round() / 2;
                      if (roseZoom != _roseZoom &&
                          ref.read(showCompassRoseProvider)) {
                        setState(() => _roseZoom = roseZoom);
                      }
                      if (byGesture && _follow) {
                        setState(() => _follow = false);
                      }
                    },
                    // Tek dokun → araç aktifse nokta koy.
                    onTap: (point) {
                      if (_highlightRegionId != null || _previewRoute != null) {
                        setState(() {
                          _highlightRegionId = null;
                          _previewRoute = null;
                        });
                      }
                      if (_shapeEdit != null) {
                        _shapeEditTap(point);
                        return;
                      }
                      if (_moving != null) {
                        _finishMove(point);
                        return;
                      }
                      if (_placingSelf) {
                        _setManualPosition(point);
                        return;
                      }
                      if (ref.read(routePlanningProvider).active) {
                        HapticFeedback.selectionClick();
                        ref.read(routePlanningProvider.notifier).addPoint(point);
                        return;
                      }
                      if (_dropMode) {
                        _dropPoint(point);
                        return;
                      }
                      if (ref.read(toolProvider).active) {
                        HapticFeedback.selectionClick();
                        ref.read(toolProvider.notifier).addPoint(point);
                        return;
                      }
                      // Boş araçta çizime dokunuldu → çizimin menüsü.
                      final g = _graphicAt(point);
                      if (g != null) {
                        _openRadial(point, g.name, _graphicActions(g));
                      }
                    },
                    // Uzun bas → waypoint ekle.
                    onLongPress: (point) {
                      HapticFeedback.mediumImpact();
                      showAddWaypointDialog(context, ref, point);
                    },
                  ),
                );
              },
            ),
          ),

          // Lasso: seçilecek alanın çevresi çizilir.
          if (_lassoMode)
            Positioned.fill(
              child: FreehandLayer(
                color: nightMode ? Colors.redAccent : Colors.cyanAccent,
                onDone: _finishLasso,
              ),
            ),

          // Serbest çizim: parmak izi yakalanır, harita kaymaz (araç
          // çubukları üstte kaldığı için dokunulabilir).
          if (tool.mode == ToolMode.freehand)
            Positioned.fill(
              child: FreehandLayer(
                color: nightMode ? Colors.redAccent : Colors.amber,
                onDone: _finishFreehand,
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

          // Katmanın dosyası cihazda yoksa kullanıcıyı yönlendir.
          if (layerMissing)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_off_outlined,
                              size: 32, color: Colors.orangeAccent),
                          const SizedBox(height: 10),
                          Text('“${_selected.label}” dosyası bulunamadı',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            '${_selected.fileName} dosyasını\nDosyalar (ya da Finder) ile\nUsturlap içine kopyalayın.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
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

          // ---------------------------------------------- alt bölge (ATAK)
          // Sol alt: bilgi kutuları (indirme, hedef, rota takibi) + ölçek;
          // sağ alt: konum kutusu. Dikeyde kutular tam genişlik, konum
          // kutusunun üstünde; yatayda solda dar sütun.
          // Panel açıkken (ATAK: panel açılınca harita alanı daralır) köşe
          // kutuları görünür kalır: yatayda panelin soluna, dikeyde üstüne
          // kayar. Dikey panel tam ekrana büyütülünce kutular gizlenir.
          if (!_framing)
            ValueListenableBuilder<EdgeInsets>(
              valueListenable: panelInsets,
              builder: (context, panel, _) => AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: 8 + safe.left,
                right: 8 + safe.right + panel.right,
                // Alt panel güvenli alanı da kaplar.
                bottom: (panel.bottom > 0 ? panel.bottom : bottomInset) + 8,
                child: Offstage(
                  offstage: panel.bottom > screenH * 0.55,
                  child: _bottomCluster(
                    landscape: landscape,
                    night: nightMode,
                    showRoutePanel: !planning.active && activeRoute != null,
                  ),
                ),
              ),
            ),

          // Ortadaki artı imleç (Ayarlar'dan açılır).
          if (!_framing && crosshairOn) MapCrosshair(night: nightMode),

          // Araç çubuğunun altında, sol sütunun yanında: rota planı, nokta
          // bırakma ipucu, aktif ölçüm aracı.
          if (!_framing)
            ValueListenableBuilder<EdgeInsets>(
              valueListenable: panelInsets,
              builder: (context, panel, child) => AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                top: safe.top + 6 + kAtakToolbarHeight + 6,
                left: safe.left + 8 + kToolbarButtonSize + 10,
                right: safe.right + 8 + panel.right,
                child: child!,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ATAK: aktif aracın kendi çubuğu ana çubuğun altında.
                      if (planning.active)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: RoutePlanToolbar(
                            onAddAtCrosshair:
                                crosshairOn ? _addAtCrosshair : null,
                          ),
                        ),
                      if (_dropMode)
                        PointDropperBar(
                          night: nightMode,
                          selected: dropKind,
                          nextName: _nextDropName(dropKind, waypoints),
                          onSelect: (k) =>
                              ref.read(dropKindProvider.notifier).set(k),
                          onClose: () => setState(() => _dropMode = false),
                          onDropAtCrosshair:
                              crosshairOn ? _addAtCrosshair : null,
                        ),
                      // Etiket süzgeci açık: yeni nesneler etiketsizse
                      // görünmez; kullanıcı bilsin.
                      if (_lassoMode)
                        _ModeHint(
                          night: nightMode,
                          icon: Icons.highlight_alt,
                          text: 'Seçmek istediklerinin çevresini çiz',
                          closeTooltip: 'Seçimi kapat',
                          onClose: () => setState(() => _lassoMode = false),
                        ),
                      if (visibility.tag != null)
                        _ModeHint(
                          night: nightMode,
                          icon: Icons.filter_alt,
                          text: 'Yalnız #${visibility.tag} gösteriliyor',
                          closeTooltip: 'Etiket süzgecini kaldır',
                          onClose: () => ref
                              .read(overlayVisibilityProvider.notifier)
                              .update((v) => v.withTag(null)),
                        ),
                      if (_placingSelf)
                        _ModeHint(
                          night: nightMode,
                          icon: Icons.edit_location_alt,
                          text: 'Konumunu haritada dokunarak göster',
                          closeTooltip: 'Konum düzeltmeyi iptal et',
                          onClose: () => setState(() => _placingSelf = false),
                          action: crosshairOn
                              ? TextButton(
                                  onPressed: _addAtCrosshair,
                                  child: const Text('İmlece'),
                                )
                              : null,
                        ),
                      if (_shapeEdit != null)
                        ShapeEditBar(
                          state: _shapeEdit!,
                          night: nightMode,
                          onUndo: () =>
                              setState(() => _shapeEdit = _shapeEdit?.undo()),
                          onRemove: () => setState(
                            () => _shapeEdit = _shapeEdit?.removeSelected(),
                          ),
                          onCancel: () => setState(() => _shapeEdit = null),
                          onSave: _saveShapeEdit,
                        ),
                      if (_moving != null)
                        _ModeHint(
                          night: nightMode,
                          icon: Icons.open_with,
                          text: '“${_moving!.name}”: yeni yerine dokun',
                          closeTooltip: 'Taşımayı iptal et',
                          onClose: () => setState(() => _moving = null),
                          action: crosshairOn
                              ? TextButton(
                                  onPressed: _addAtCrosshair,
                                  child: const Text('İmlece taşı'),
                                )
                              : null,
                        ),
                      if (!planning.active &&
                          (_drawBarOpen || tool.mode.isDrawing))
                        RangeToolsBar.drawing(
                          onClose: () {
                            ref.read(toolProvider.notifier).reset();
                            setState(() => _drawBarOpen = false);
                          },
                        )
                      else if (!planning.active &&
                          (_rangeBarOpen || tool.active))
                        RangeToolsBar(
                          onClose: () {
                            ref.read(toolProvider.notifier).reset();
                            setState(() => _rangeBarOpen = false);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Sol sütun: pusula oku · ◎ · zoom (bilgi kutularının üstünde
          // çizilir; pusulanın ek düğmeleri örtülmesin).
          if (!_framing)
            Positioned(
              top: safe.top + 6 + kAtakToolbarHeight + 6,
              left: safe.left + 8,
              child: MapSideControls(
                camera: _scaleCamera,
                night: nightMode,
                trackUp: _trackUp,
                onToggleOrientation: _toggleOrientation,
                rotationLocked: _rotationLocked,
                onToggleRotationLock: _toggleRotationLock,
                onToggleTerrain: kMapEngine.supportsTerrain
                    ? () => setState(() => _terrain3d = !_terrain3d)
                    : null,
                terrainOn: _terrain3d,
                onTacticalCompass: () => showTacticalCompass(context),
                following: _follow,
                onRecenter: _recenter,
                onZoomIn: () => _map.zoomBy(1),
                onZoomOut: () => _map.zoomBy(-1),
              ),
            ),

          // Sol üst: araç çubuğu (≡'ye uzun bas → gizle).
          if (!_framing)
            Positioned(
              top: safe.top + 6,
              left: safe.left + 8,
              child: _toolbarHidden
                  ? AtakToolbarHandle(
                      night: nightMode,
                      onShow: () => setState(() => _toolbarHidden = false),
                    )
                  : AtakToolbar(
                      night: nightMode,
                      onMenu: _openToolsGrid,
                      onHide: () => setState(() => _toolbarHidden = true),
                      // Bir araca uzun bas → Araç çubuğu paneli.
                      onEdit: () => showToolbarManagerSheet(context),
                      items: [
                        for (final t in ref.watch(toolbarToolsProvider))
                          _toolbarItem(t),
                      ],
                    ),
            ),

          // Görüş hattı profili (alt çubuğun üstünde açılır).
          const LosOverlay(),

          // Bölge çerçeveleme modu: karartma + alt panel.
          if (_framing) ...[
            OfflineFrameMask(frame: _frameRect(context)),
            Positioned(
              // Yatayda panel sağda (yan panel), dikeyde altta.
              left: landscape ? null : 0,
              right: 0,
              top: landscape ? 0 : null,
              bottom: 0,
              width: landscape ? sidePanelWidth(context) : null,
              child: OfflineFramePanel(
                sideways: landscape,
                initialTypes: [
                  _selected.mapType ?? OfflineMapType.satellite,
                ],
                defaultName: 'Bölge ${(ref.read(offlineRegionsProvider).value?.length ?? 0) + 1}',
                frameBounds: () => _map.boundsOfScreenRect(_frameRect(context)),
                cameraTick: _cameraTick,
                onClose: () => setState(() => _framing = false),
              ),
            ),
          ],

          // Radyal menü en üstte: dışına dokunuş menüyü kapatır ve alttaki
          // haritaya / düğmelere geçer.
          if (_radial != null && !_framing)
            Positioned.fill(
              child: RadialMenu(
                center: _radial!.screen,
                title: _radial!.title,
                actions: _radial!.actions,
                onDismiss: _closeRadial,
                night: nightMode,
              ),
            ),
        ],
        ),
      ),
    );
  }

  /// Rota planlamayı başlat (ölçüm aracı kapanır; dokunuşlar rotaya gider).
  void _startRoutePlanning() {
    ref.read(toolProvider.notifier).reset();
    setState(() {
      _follow = false;
      _previewRoute = null;
      _rangeBarOpen = false;
      _drawBarOpen = false;
      _dropMode = false;
      _moving = null;
      _placingSelf = false;
    });
    ref.read(routePlanningProvider.notifier).start();
  }

  /// Kayıtlı bir rotayı haritaya sığdırıp önizle.
  void _showRoute(RoutePlan r) {
    setState(() {
      _follow = false;
      _previewRoute = r;
    });
    _map.fitBounds(GeoBounds.fromPoints(r.points),
        padding: const EdgeInsets.fromLTRB(40, 160, 80, 200));
  }

  /// Numaralı rota noktası işaretçisi. [style]: plan / next / done / todo.
  MapMarker _routePoint(int i, LatLng p, String style) {
    final (Color bg, Color fg, double size) = switch (style) {
      'next' => (Colors.lightGreenAccent, Colors.black, 30.0),
      'done' => (Colors.grey.shade700, Colors.white70, 22.0),
      _ => (Colors.amber, Colors.black, 24.0),
    };
    return MapMarker(
      id: 'rp:$style:$i',
      imageKey: 'rp:$style:${i + 1}',
      point: p,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text('${i + 1}',
            style: TextStyle(
                color: fg, fontSize: size * 0.45, fontWeight: FontWeight.bold)),
      ),
    );
  }

  List<MapOverlay> _routeOverlays(
      RoutePlanningState planning, ActiveRouteState? active, LatLng? self) {
    const amber = Colors.amber;
    final out = <MapOverlay>[];
    if (planning.active) {
      final pts = planning.points;
      if (pts.length >= 2) out.add(MapLine(points: pts, width: 4, color: amber));
      for (var i = 0; i < pts.length; i++) {
        out.add(_routePoint(i, pts[i], 'plan'));
      }
      return out;
    }
    if (active != null) {
      final pts = active.route.points;
      final p = active.progress;
      final t = p == null ? 0 : p.targetIndex.clamp(0, pts.length);
      // Geçilen ayaklar gri, kalanlar sarı.
      if (t >= 2) {
        out.add(MapLine(
            points: pts.sublist(0, t), width: 4, color: Colors.grey.shade600));
      }
      final restStart = t == 0 ? 0 : t - 1;
      if (pts.length - restStart >= 2) {
        out.add(MapLine(points: pts.sublist(restStart), width: 5, color: amber));
      }
      // Konumdan sıradaki noktaya hat.
      if (self != null && p != null && !p.finished && t < pts.length) {
        out.add(MapLine(
            points: [self, pts[t]], width: 3, color: Colors.lightGreenAccent));
      }
      for (var i = 0; i < pts.length; i++) {
        out.add(_routePoint(
            i, pts[i], i < t ? 'done' : (i == t ? 'next' : 'todo')));
      }
      return out;
    }
    final r = _previewRoute;
    if (r != null) {
      out.add(MapLine(points: r.points, width: 4, color: amber));
      for (var i = 0; i < r.points.length; i++) {
        out.add(_routePoint(i, r.points[i], 'plan'));
      }
    }
    return out;
  }

  /// Alt bölge (ATAK): sol altta bilgi kutuları + ölçek, sağ altta konum
  /// kutusu. Kutular değişken yükseklikte olduğu için tek sütunda dizilir
  /// (üst üste binmesinler).
  Widget _bottomCluster({
    required bool landscape,
    required bool night,
    required bool showRoutePanel,
  }) {
    final cards = <Widget>[
      const _OfflineStatusCards(),
      const NavBanner(),
      BullseyeBanner(onTap: _openBullseye),
      if (showRoutePanel)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: RouteFollowPanel(night: night),
        ),
    ];
    final scale = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<MapCameraState>(
          valueListenable: _scaleCamera,
          builder: (context, cam, _) => MapScaleBar(
            zoom: cam.zoom,
            latitude: cam.center.latitude,
            night: night,
          ),
        ),
        // Mapbox logosu (85×21) + atıf düğmesi (44×44) bunun altında,
        // güvenli alanın 8 pt üstünde (kullanım şartı: görünür olmalı).
        const SizedBox(height: 36),
      ],
    );
    if (landscape) {
      // Yatayda ekran alçak: kutular büyüyünce sol sütunla (zoom) çakışmasın
      // diye sütunun sağından başlar.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: kToolbarButtonSize + 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [...cards, scale],
            ),
          ),
          const Spacer(),
          const SelfInfoBox(),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...cards,
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(alignment: Alignment.bottomLeft, child: scale),
            ),
            const SelfInfoBox(),
          ],
        ),
      ],
    );
  }

  Rect _frameRect(BuildContext context) => offlineFrameRect(
        MediaQuery.sizeOf(context),
        MediaQuery.paddingOf(context),
        rightPanel: isLandscape(context) ? sidePanelWidth(context) : 0,
      );

  /// Çerçeveleme modunu aç. Seçili katman Mapbox türüyse (Uydu / Sokak /
  /// Topografik) o tür önerilir; değilse uydu katmanına geçilir.
  void _startFraming() {
    if (AppConstants.mapboxAccessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bölge indirmek için Mapbox anahtarı gerekli.')));
      return;
    }
    if (_selected.mapType == null) {
      final sat = kBaseLayers.firstWhere((l) => l.id == 'online_satellite');
      setState(() => _selected = sat);
      _ensureResolved(sat);
    }
    setState(() {
      _framing = true;
      _follow = false;
      _highlightRegionId = null;
    });
  }

  /// Listeden seçilen bölgeye git ve sınırını vurgula.
  void _showRegion(OfflineRegion r) {
    setState(() {
      _follow = false;
      _highlightRegionId = r.id;
    });
    _map.fitBounds(
      GeoBounds(south: r.south, west: r.west, north: r.north, east: r.east),
      padding: const EdgeInsets.all(40),
    );
  }

  List<MapOverlay> _regionOutlines() {
    if (!_framing && _highlightRegionId == null) return const [];
    final regions = ref.watch(offlineRegionsProvider).value ?? const [];
    return [
      for (final r in regions)
        if (_framing || r.id == _highlightRegionId)
          MapArea(
            points: [
              LatLng(r.south, r.west),
              LatLng(r.south, r.east),
              LatLng(r.north, r.east),
              LatLng(r.north, r.west),
            ],
            fillColor: Colors.amber.withValues(alpha: 0.08),
            strokeColor: Colors.amber.withValues(alpha: 0.9),
            strokeWidth: 2,
          ),
    ];
  }

  /// Gece modunda FAB'ları kırmızı tonlar (gece görüşü).
  /// Gece teması. Theme her zaman ağaçta kalır, yalnız verisi değişir: koşullu
  /// sarmalama (gece → Theme, gündüz → çıplak) ağacın yapısını değiştirir ve
  /// alttaki her şeyi, haritanın platform görünümü dahil, yeniden yaratır
  /// (Android'de eski haritanın kanalları kopar, iOS'ta harita baştan kurulur).
  Widget _wrapNight(bool night, Widget child) {
    final base = Theme.of(context);
    return Theme(
      data: night
          ? base.copyWith(
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF7F1D1D),
                foregroundColor: Color(0xFFFECACA),
              ),
            )
          : base,
      child: child,
    );
  }
}


/// Haritanın sol altında: indirme ilerlemesi / sonucu ve ağ-kapalı uyarısı.
class _OfflineStatusCards extends ConsumerWidget {
  const _OfflineStatusCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dl = ref.watch(offlineDownloadProvider);
    final offlineTest = ref.watch(offlineTestModeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (offlineTest)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ActionChip(
              avatar: const Icon(Icons.cloud_off, size: 18, color: Colors.white),
              backgroundColor: Colors.red.shade700,
              label: const Text('Ağ kapalı (test) — dokun: aç',
                  style: TextStyle(color: Colors.white)),
              onPressed: () =>
                  ref.read(offlineTestModeProvider.notifier).set(false),
            ),
          ),
        if (dl != null)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dl.error != null
                              ? '“${dl.name}” indirilemedi'
                              : dl.done
                                  ? '“${dl.name}” indirildi · ${fmtBytes(dl.bytes)}'
                                  : '“${dl.name}” indiriliyor · '
                                      '%${(dl.fraction * 100).round()} · ${fmtBytes(dl.bytes)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (dl.error != null)
                          Text(dl.error!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.redAccent)),
                        if (dl.running) ...[
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: dl.fraction),
                          const SizedBox(height: 2),
                          const Text('Uygulama açık kalmalı',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                  if (!dl.running)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          ref.read(offlineDownloadProvider.notifier).dismiss(),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Nokta bırakma modu açıkken araç çubuğunun altında ipucu (✕ ile kapanır).
/// Haritaya dokunuşun anlamını değiştiren modların ipucu şeridi (nokta
/// bırak, taşı): ne olacağı + isteğe bağlı eylem + kapat.
class _ModeHint extends StatelessWidget {
  const _ModeHint({
    required this.icon,
    required this.text,
    required this.closeTooltip,
    required this.onClose,
    this.action,
    this.night = false,
  });

  final IconData icon;
  final String text;
  final String closeTooltip;
  final VoidCallback onClose;
  final Widget? action;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          ?action,
          IconButton(
            tooltip: closeTooltip,
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Açık radyal menünün nesnesi.
class _RadialTarget {
  const _RadialTarget(this.point, this.title, this.actions, this.screen);

  final LatLng point;
  final String title;
  final List<RadialAction> actions;

  /// Nesnenin ekran konumu (kamera değişince güncellenir).
  final Offset screen;

  _RadialTarget at(Offset s) => _RadialTarget(point, title, actions, s);
}
