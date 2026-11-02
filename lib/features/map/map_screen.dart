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
import '../map_spike/mapbox_spike_screen.dart';
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
import '../../providers/repeater_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../hud/callsign_hud.dart';
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

/// Adım 3 — çevrimdışı/çevrimiçi harita + kendi konum işaretçisi + HUD +
/// kuzey/track-up modu + takip.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// Motor başına kontrolcü (Mapbox / Klasik). Aktif olan [_map].
  final Map<MapEngineKind, MapEngineController> _controllers = {};
  MapEngineKind _activeKind = MapEngineKind.flutterMap;

  /// Aktif motorun kontrolcüsü.
  MapEngineController get _map => _controllers.putIfAbsent(
      _activeKind, () => engineFor(_activeKind).createController());

  /// Son bilinen kamera — motor değişince yeni harita buradan başlar.
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
    // Motorların açtığı karo kaynaklarını da kapatır.
    for (final c in _controllers.values) {
      c.dispose();
    }
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
  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final tool = ref.watch(toolProvider);
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

                // SPIKE: Mapbox motoru denemesi (geçici).
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Mapbox haritası (deneme)'),
                  subtitle: const Text('uydu · z22 · 3B · bölge indirme'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const MapboxSpikeScreen(),
                    ));
                  },
                ),

                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('Harita katmanı',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white70)),
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
                // --- Görünüm ayarları ---
                Consumer(builder: (context, ref, _) {
                  final kind = ref.watch(mapEngineKindProvider);
                  final hasToken = AppConstants.mapboxAccessToken.isNotEmpty;
                  return SwitchListTile(
                    secondary: const Icon(Icons.memory),
                    title: const Text('Harita motoru: Mapbox'),
                    subtitle: Text(!hasToken
                        ? 'Mapbox anahtarı yok — Klasik motor'
                        : kind == MapEngineKind.mapbox
                            ? 'GPU, akıcı · kendi paketleriniz Klasik\'te açılır'
                            : 'Kapalı — Klasik (flutter_map)'),
                    value: kind == MapEngineKind.mapbox,
                    onChanged: !hasToken
                        ? null
                        : (on) => ref.read(mapEngineKindProvider.notifier).set(
                            on ? MapEngineKind.mapbox : MapEngineKind.flutterMap),
                  );
                }),
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
                Consumer(builder: (context, ref, _) {
                  final on = ref.watch(showRepeatersProvider);
                  final count =
                      ref.watch(repeatersProvider).value?.length ?? 0;
                  final band = ref.watch(repeaterBandProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.cell_tower),
                        title: const Text('Telsiz röleleri'),
                        subtitle: Text('Haritada göster ($count röle)'),
                        value: on,
                        onChanged: (_) =>
                            ref.read(showRepeatersProvider.notifier).toggle(),
                      ),
                      if (on)
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Row(
                            children: [
                              const Text('Band: ',
                                  style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 6),
                              for (final b in const [null, 'VHF', 'UHF'])
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(b ?? 'Tümü'),
                                    selected: band == b,
                                    onSelected: (_) => ref
                                        .read(repeaterBandProvider.notifier)
                                        .set(b),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
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
      case ToolMode.lineOfSight:
        return 'görüş hattı';
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

    // Etkin motor: tercih Mapbox olsa bile kendi MBTiles/PMTiles paketlerimiz
    // (henüz) Klasik motorda çizilir — özellik kaybı olmasın.
    final preferred = ref.watch(mapEngineKindProvider);
    final fileLayer = _selected.type == BaseLayerSourceType.offlineMbtiles ||
        _selected.type == BaseLayerSourceType.vectorPmtiles;
    final kind = fileLayer ? MapEngineKind.flutterMap : preferred;
    if (kind != _activeKind) {
      if (_map.isReady) _lastCamera = _map.camera;
      _activeKind = kind;
    }

    // Harita üstü çizimler — liste sırası = çizim sırası (alttan üste).
    final overlays = <MapOverlay>[
      // Kalıcı taktik grafikler (çizgi/alan).
      ..._graphicOverlays(graphics),
      // Aktif ölçüm/çizim aracı.
      ..._toolOverlays(tool),
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
                return engineFor(kind).buildView(
                  key: ValueKey('engine_${kind.name}'),
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
                    if (byGesture && _follow) {
                      setState(() => _follow = false);
                    }
                  },
                  // Tek dokun → araç aktifse nokta koy.
                  onTap: (point) {
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
          const Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CallsignHud(),
                ToolBanner(),
                NavBanner(),
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
          const LosOverlay(),
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
