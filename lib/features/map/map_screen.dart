import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/coord_format.dart';
import '../../core/geo_math.dart';
import '../../domain/models/contact.dart';
import '../../domain/models/imported_layer.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/repeater.dart';
import '../../domain/models/track.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/layer_providers.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/offline_providers.dart';
import '../../providers/route_providers.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/offline_region.dart';
import '../offline/offline_frame_panel.dart';
import '../offline/offline_regions_sheet.dart';
import '../../providers/repeater_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../hud/callsign_hud.dart';
import '../import/import_action.dart';
import '../routes/route_widgets.dart';
import '../shell/coordinate_sheet.dart';
import '../shell/map_controls.dart';
import '../shell/missions_sheet.dart';
import '../shell/route_sheet.dart';
import '../shell/settings_sheet.dart';
import '../shell/tactical_bottom_bar.dart';
import '../tools/graphic_list_sheet.dart';
import '../layers/import_layer_action.dart';
import '../nav/nav_banner.dart';
import '../symbols/nato_symbol.dart';
import '../tools/tool_banner.dart';
import '../tools/tools_palette.dart';
import '../tracks/track_list_sheet.dart';
import '../waypoints/add_waypoint_dialog.dart';
import '../waypoints/edit_waypoint_dialog.dart';
import '../waypoints/waypoint_list_sheet.dart';
import 'base_layer.dart';
import 'base_layer_resolver.dart';
import 'engine/map_engine.dart';
import 'widgets/los_overlay.dart';
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

  /// Çevrimdışı bölge çerçeveleme modu açık mı.
  bool _framing = false;

  /// Harita her hareket ettiğinde artar (çerçeve boyut tahmini için).
  final ValueNotifier<int> _cameraTick = ValueNotifier(0);

  /// Listeden "haritada göster" denen bölge (sınırı vurgulanır).
  String? _highlightRegionId;

  /// Rota listesinden "haritada göster" denen rota (dokununca kaybolur).
  RoutePlan? _previewRoute;

  @override
  void initState() {
    super.initState();
    _selected = kBaseLayers.firstWhere(
      (l) => l.type == BaseLayerSourceType.offlineMbtiles,
      orElse: () => kBaseLayers.first,
    );
    // Açılışta yalnızca varsayılan katmanı yükle (büyük topo'yu değil).
    _ready = _ensureResolved(_selected);
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
        layer.type != BaseLayerSourceType.vectorPmtiles) {
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
    _cameraTick.dispose();
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
    return MapMarker(
      id: 'self',
      imageKey: heading == null ? 'self:dot' : 'self:arrow',
      point: self.position,
      width: 44,
      height: 44,
      rotationDeg: heading,
      child: heading == null
          ? const Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 28)
          : const Icon(Icons.navigation, color: Colors.lightBlueAccent, size: 34),
    );
  }

  /// Kayıtlı bir waypoint'in işaretçisi (dokun → detay/sil).
  /// APP-6 sadakati varsa NATO çerçevesi, yoksa kırmızı pin.
  MapMarker _waypointMarker(Waypoint wp) {
    final isNato = wp.affiliation != Affiliation.waypoint;
    return MapMarker(
      id: 'wp:${wp.id}',
      // Aynı görünen semboller tek resmi paylaşır.
      imageKey: isNato
          ? 'wp:nato:${wp.affiliation.name}:${wp.echelon}:${wp.role}'
          : 'wp:pin',
      point: wp.position,
      width: isNato ? 34 : 40,
      height: isNato ? 34 : 40,
      onTap: () => _showWaypointDetail(wp),
      child: isNato
          ? NatoSymbol(
              affiliation: wp.affiliation,
              echelon: wp.echelon,
              role: wp.role,
              size: 34)
          : const Icon(Icons.location_on, color: Colors.redAccent, size: 36),
    );
  }

  /// Telsiz röle işaretçisi (anten ikonu; dokun → özellikler).
  MapMarker _repeaterMarker(Repeater r) {
    return MapMarker(
      id: 'rep:${r.id}',
      imageKey: 'repeater',
      point: r.position,
      width: 32,
      height: 32,
      onTap: () {
        ref.read(selectedRepeaterProvider.notifier).select(r);
        _showRepeaterDetail(r);
      },
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

  /// Kalıcı taktik grafikler (çizgi + alan). Alanlar çizgilerin altında.
  List<MapOverlay> _graphicOverlays(List<MapGraphic> graphics) {
    final areas = <MapOverlay>[];
    final lines = <MapOverlay>[];
    for (final g in graphics) {
      if (g.points.length < 2) continue;
      final color = Color(g.colorValue);
      if (g.type == GraphicType.area && g.points.length >= 3) {
        areas.add(MapArea(
          points: g.points,
          fillColor: color.withValues(alpha: 0.22),
          strokeColor: color,
          strokeWidth: 3,
        ));
      } else {
        lines.add(MapLine(points: g.points, width: 4, color: color));
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
      case ToolMode.none:
        break;
    }

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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _centerOn(wp.position);
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Ortala'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(navTargetProvider.notifier)
                          .set(wp.position, wp.name);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Git'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showEditWaypointDialog(context, ref, wp);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Düzenle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final text = '${wp.name}\n'
                          '${CoordFormat.mgrs(wp.position)}'
                          '${wp.note != null && wp.note!.isNotEmpty ? "\n${wp.note}" : ""}';
                      SharePlus.instance
                          .share(ShareParams(text: text, subject: wp.name));
                    },
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Paylaş'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final target = ref.read(navTargetProvider);
                      if (target != null && target.position == wp.position) {
                        ref.read(navTargetProvider.notifier).clear();
                      }
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

  void _onLayerTapped(BaseLayerDef layer) {
    Navigator.of(context).pop();
    if (!layer.isAvailable) {
      final msg = layer.type == BaseLayerSourceType.onlineSatellite
          ? '“${layer.label}” için Mapbox anahtarı yok. Uygulamayı '
              '--dart-define=MAPBOX_ACCESS_TOKEN=pk.... ile çalıştırın.'
          : '“${layer.label}” için henüz MBTiles yok. '
              'assets/tiles/ içine dosyayı ekleyip base_layer.dart\'a tanımlayınca aktif olur.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }
    setState(() => _selected = layer);
    // Katmanı (gerekirse) tembel yükle — büyük topo yalnızca seçilince kopyalanır.
    // (Yükleme bitince _ensureResolved zaten kapsama alanına götürür.)
    _ensureResolved(layer);
    // Zaten yüklüyse hemen kapsama alanına git (tekrar girememe sorunu).
    _recenterToLayer(layer);
  }

  /// İçe-aktarılmış katmanı (drift modeli) harita BaseLayerDef'ine çevirir.
  BaseLayerDef _importedToDef(ImportedLayer l) {
    return BaseLayerDef(
      id: l.id,
      label: l.label,
      icon: l.isVector ? Icons.public : Icons.map_outlined,
      type: l.isVector
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
    final l = await pickAndImportLayer(context, ref);
    if (l == null || !mounted) return;
    final def = _importedToDef(l);
    setState(() => _selected = def);
    await _ensureResolved(def);
    _recenterToLayer(def);
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
                    subtitle: layer.isAvailable
                        ? null
                        : const Text('henüz eklenmedi'),
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
                    subtitle: Text(
                        l.isVector ? 'içe aktarılan vektör' : 'içe aktarılan raster'),
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

  void _openMissions() {
    showMissionsSheet(
      context,
      onWaypoints: () => showWaypointListSheet(context, ref,
          onTapWaypoint: (wp) => _centerOn(wp.position)),
      onTracks: () => showTrackListSheet(context, ref),
      onGraphics: () => showGraphicListSheet(context, ref),
      onOfflineRegions: () => showOfflineRegionsSheet(
        context,
        onShowRegion: _showRegion,
        onNewRegion: _startFraming,
      ),
      onImportGpxKml: () => runGpxKmlImport(context, ref),
    );
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
    final recording = ref.watch(recordingProvider);
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
    final nightMode = ref.watch(nightModeProvider);
    // Seçili katmanın dosyası cihazda yok (ör. Türkiye paketi kopyalanmamış).
    final layerMissing = _missingFiles.contains(_selected.id);
    // Seçili çevrimdışı katman henüz çözülmediyse (tembel) göstergede uyar.
    final layerLoading = !layerMissing &&
        (_selected.type == BaseLayerSourceType.offlineMbtiles ||
            _selected.type == BaseLayerSourceType.vectorPmtiles) &&
        !_resolved.containsKey(_selected.id);

    // Yerleşim: dikeyde alt çubuk; yatayda (ATAK gibi) sol dikey şerit,
    // sağdan yan paneller, dar HUD — harita olabildiğince açık kalsın.
    final landscape = isLandscape(context);
    final safe = MediaQuery.paddingOf(context);
    final safeBottom = safe.bottom;
    // Alt kenarda arayüzün kapladığı yükseklik / sol kenarda şerit genişliği.
    final bottomInset = landscape ? safeBottom : kBottomBarHeight + safeBottom;
    final leftInset = landscape ? kSideRailWidth + safe.left : 0.0;

    // Harita üstü çizimler — liste sırası = çizim sırası (alttan üste).
    final overlays = <MapOverlay>[
      // İndirilmiş bölgelerin sınırları (çerçevelerken hepsi, yoksa seçilen).
      ..._regionOutlines(),
      // Kalıcı taktik grafikler (çizgi/alan).
      ..._graphicOverlays(graphics),
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
      for (final wp in waypoints) _waypointMarker(wp),
      if (self != null) _selfMarker(self),
    ];

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
                return kMapEngine.buildView(
                  terrain3d: _terrain3d && kMapEngine.supportsTerrain,
                  // Logo/atıf alt çubuğun (çerçevelerken panelin) üstünde kalsın.
                  ornamentPadding: _framing
                      ? EdgeInsets.only(bottom: landscape ? 0 : safeBottom + 300)
                      : EdgeInsets.only(left: leftInset, bottom: bottomInset),
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
                    if (_framing) _cameraTick.value++;
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
                    if (ref.read(routePlanningProvider).active) {
                      HapticFeedback.selectionClick();
                      ref.read(routePlanningProvider.notifier).addPoint(point);
                      return;
                    }
                    if (ref.read(toolProvider).active) {
                      HapticFeedback.selectionClick();
                      ref.read(toolProvider.notifier).addPoint(point);
                    }
                  },
                  // Uzun bas → waypoint ekle.
                  onLongPress: (point) {
                    HapticFeedback.mediumImpact();
                    showAddWaypointDialog(context, ref, point);
                  },
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
                            '${_selected.fileName} dosyasını\nDosyalar (ya da Finder) ile\nKerteriz içine kopyalayın.',
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

          // Üst: kalıcı HUD + (araç aktifse) ölçüm şeridi
          Align(
            alignment: landscape ? Alignment.topLeft : Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(left: _framing ? 0 : leftInset),
              child: ConstrainedBox(
                // Yatayda dar: haritanın üst bandını kaplamasın.
                constraints:
                    BoxConstraints(maxWidth: landscape ? 380 : double.infinity),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CallsignHud(),
                    if (planning.active) const RoutePlanInfo(),
                    const ToolBanner(),
                    const NavBanner(),
                  ],
                ),
              ),
            ),
          ),

          // Ortadaki artı imleç (eldivenle nokta koymak / ölçmek için).
          if (!_framing) MapCrosshair(night: nightMode),

          // Sağ kenar: harita kontrolleri (Kerteriz tarzı).
          if (!_framing)
            Positioned(
              right: 12 + (landscape ? safe.right : 0),
              bottom: bottomInset + (landscape ? 8 : 16),
              child: MapControlsColumn(
                compact: landscape,
                night: nightMode,
                onSettings: () => showSettingsSheet(context),
                onLayers: _openLayers,
                onTerrain: kMapEngine.supportsTerrain
                    ? () => setState(() => _terrain3d = !_terrain3d)
                    : null,
                terrainOn: _terrain3d,
                onAdd: _addAtCrosshair,
                addLabel: tool.active ? 'İmleçe araç noktası' : 'İmleçe nokta ekle',
                onRecenter: _recenter,
                following: _follow,
                onOrientation: _toggleOrientation,
                trackUp: _trackUp,
              ),
            ),

          // Sağ kenardan içeri kaydır → katmanlar (§8 jest). Yatayda kontrol
          // sütunu sağ kenarı kapladığı için yok (Katmanlar düğmesi var).
          if (!_framing && !landscape)
            Positioned(
              right: 0,
              top: 160,
              bottom: bottomInset + 380,
              width: 20,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -100) {
                    HapticFeedback.selectionClick();
                    _openLayers();
                  }
                },
              ),
            ),

          // Çevrimdışı indirme ilerlemesi + ağ-kapalı (test) uyarısı.
          if (!_framing)
            Positioned(
              left: leftInset + 12,
              right: landscape ? null : 76,
              width: landscape ? 380 : null,
              bottom: bottomInset +
                  (activeRoute != null ? 170 : (landscape ? 12 : 40)),
              child: const _OfflineStatusCards(),
            ),

          // Rota takip paneli (alt çubuğun üstünde).
          if (!_framing && !planning.active && activeRoute != null)
            Positioned(
              left: leftInset + 8,
              right: landscape ? null : 68,
              width: landscape ? 440 : null,
              bottom: bottomInset + 8,
              child: RouteFollowPanel(night: nightMode),
            ),

          // Rota planlarken alt çubuk planlama düğmelerine dönüşür.
          if (!_framing && planning.active)
            Positioned(
              left: 0,
              right: landscape ? null : 0,
              top: landscape ? 0 : null,
              bottom: 0,
              child: RoutePlanBar(
                  onAddAtCrosshair: _addAtCrosshair, vertical: landscape),
            ),

          // Alt çubuk: Koordinat · Araçlar · ● İz · Rota · Görevler.
          if (!_framing && !planning.active)
            Positioned(
              left: 0,
              right: landscape ? null : 0,
              top: landscape ? 0 : null,
              bottom: 0,
              child: TacticalBottomBar(
                vertical: landscape,
                night: nightMode,
                recording: recording.isRecording,
                toolActive: tool.active,
                navActive: navTarget != null || activeRoute != null,
                onCoordinate: _openCoordinate,
                onTools: () => showToolsPalette(context, ref),
                onRecord: () {
                  final n = ref.read(recordingProvider.notifier);
                  recording.isRecording ? n.stop() : n.start();
                },
                onRoute: () => showRouteSheet(
                  context,
                  onPlanNew: _startRoutePlanning,
                  onShowRoute: _showRoute,
                ),
                onMissions: _openMissions,
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
                defaultName: 'Bölge ${(ref.read(offlineRegionsProvider).value?.length ?? 0) + 1}',
                frameBounds: () => _map.boundsOfScreenRect(_frameRect(context)),
                cameraTick: _cameraTick,
                onClose: () => setState(() => _framing = false),
              ),
            ),
          ],
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

  Rect _frameRect(BuildContext context) => offlineFrameRect(
        MediaQuery.sizeOf(context),
        MediaQuery.paddingOf(context),
        rightPanel: isLandscape(context) ? sidePanelWidth(context) : 0,
      );

  /// Çerçeveleme modunu aç. İndirilen görüntü Mapbox uydu olduğundan,
  /// kendi paket katmanı seçiliyse uydu katmanına geçilir.
  void _startFraming() {
    if (AppConstants.mapboxAccessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bölge indirmek için Mapbox anahtarı gerekli.')));
      return;
    }
    final sat = kBaseLayers.firstWhere((l) => l.id == 'online_satellite');
    if (_selected.id != sat.id) {
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
