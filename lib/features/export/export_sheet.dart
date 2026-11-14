import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/settings_repository.dart';
import '../../data/export/geo_exporter.dart';
import '../../data/package/data_package.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/track.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/route_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Dışa aktarılan nesne türleri.
enum ExportKind {
  waypoints('Noktalar', Icons.place_outlined),
  graphics('Çizimler', Icons.draw_outlined),
  tracks('İzler', Icons.timeline),
  rangeLines('R&B çizgileri', Icons.straighten),
  rangeRings('Menzil halkaları', Icons.radar),
  routes('Rotalar', Icons.route);

  const ExportKind(this.label, this.icon);
  final String label;
  final IconData icon;

  /// GPX'e girer mi.
  bool get inGpx => this == waypoints || this == tracks || this == routes;
}

/// Dışa aktar paneli (G7; ATAK Export): ne gideceği ve biçimi seçilir,
/// dosya paylaşılır (AirDrop, Dosyalar, mesaj…). [preset] verilirse
/// (ör. lasso seçimi) yalnız onlar; yoksa kayıtlı her şey.
Future<void> showExportSheet(
  BuildContext context, {
  ExportSet? preset,
  String title = 'Dışa aktar',
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'export',
    isScrollControlled: true,
    builder: (_) => ExportPanel(preset: preset, title: title),
  );
}

class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({super.key, this.preset, this.title = 'Dışa aktar'});

  final ExportSet? preset;
  final String title;

  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  final _off = <ExportKind>{};
  var _format = ExportFormat.kmz;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.preset;
    final waypoints =
        p?.waypoints ??
        ref.watch(waypointsProvider).value ??
        const <Waypoint>[];
    final graphics =
        p?.graphics ??
        ref.watch(mapGraphicsProvider).value ??
        const <MapGraphic>[];
    final tracks = p != null
        ? [for (final t in p.tracks) t.track]
        : ref.watch(tracksProvider).value ?? const <Track>[];
    final rangeLines =
        p?.rangeLines ??
        ref.watch(rangeLinesProvider).value ??
        const <RangeLine>[];
    final rangeRings =
        p?.rangeRings ??
        ref.watch(rangeRingsProvider).value ??
        const <RangeRing>[];
    final routes =
        p?.routes ?? ref.watch(routesProvider).value ?? const <RoutePlan>[];
    final counts = {
      ExportKind.waypoints: waypoints.length,
      ExportKind.graphics: graphics.length,
      ExportKind.tracks: tracks.where((t) => t.endedAt != null).length,
      ExportKind.rangeLines: rangeLines.length,
      ExportKind.rangeRings: rangeRings.length,
      ExportKind.routes: routes.length,
    };
    bool on(ExportKind k) =>
        !_off.contains(k) &&
        (counts[k] ?? 0) > 0 &&
        (_format != ExportFormat.gpx || k.inGpx);
    final total = ExportKind.values
        .where(on)
        .fold<int>(0, (n, k) => n + counts[k]!);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final f in ExportFormat.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _format == f,
                onSelected: (_) => setState(() => _format = f),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            _format.hint,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        for (final k in ExportKind.values)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            secondary: Icon(k.icon),
            title: Text('${k.label} (${counts[k]})'),
            subtitle: _format == ExportFormat.gpx && !k.inGpx
                ? const Text('GPX\'e girmez')
                : null,
            value: on(k),
            onChanged:
                (counts[k] ?? 0) == 0 ||
                    (_format == ExportFormat.gpx && !k.inGpx)
                ? null
                : (v) =>
                      setState(() => v == true ? _off.remove(k) : _off.add(k)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: total == 0 || _busy
              ? null
              : () => _export(
                  waypoints: on(ExportKind.waypoints) ? waypoints : const [],
                  graphics: on(ExportKind.graphics) ? graphics : const [],
                  tracks: on(ExportKind.tracks)
                      ? [
                          for (final t in tracks)
                            if (t.endedAt != null) t,
                        ]
                      : const [],
                  rangeLines: on(ExportKind.rangeLines) ? rangeLines : const [],
                  rangeRings: on(ExportKind.rangeRings) ? rangeRings : const [],
                  routes: on(ExportKind.routes) ? routes : const [],
                ),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
          label: Text('Paylaş ($total nesne, ${_format.label})'),
        ),
      ],
    );
  }

  Future<void> _export({
    required List<Waypoint> waypoints,
    required List<MapGraphic> graphics,
    required List<Track> tracks,
    required List<RangeLine> rangeLines,
    required List<RangeRing> rangeRings,
    required List<RoutePlan> routes,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      final trackRepo = ref.read(trackRepositoryProvider);
      final set = ExportSet(
        waypoints: waypoints,
        graphics: graphics,
        rangeLines: rangeLines,
        rangeRings: rangeRings,
        routes: routes,
        tracks: [
          for (final t in tracks)
            TrackExport(t, await trackRepo.pointsOf(t.id!)),
        ],
      );
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}';
      const name = 'Usturlap';
      final Uint8List bytes;
      switch (_format) {
        case ExportFormat.kmz:
          bytes = GeoExporter.toKmz(
            set,
            name: name,
            photos: await _photos(waypoints),
          );
        case ExportFormat.package:
          bytes = DataPackage.build(
            set,
            name: '$name $stamp',
            creatorUid: await ref.read(settingsRepositoryProvider).deviceUid(),
            creatorCallsign: ref.read(callsignProvider),
            photos: await _photos(waypoints),
          );
        case ExportFormat.kml:
          bytes = utf8.encode(GeoExporter.toKml(set, name: name));
        case ExportFormat.gpx:
          bytes = utf8.encode(GeoExporter.toGpx(set, name: name));
        case ExportFormat.geojson:
          bytes = utf8.encode(GeoExporter.toGeoJson(set, name: name));
      }
      final path =
          '${Directory.systemTemp.path}/usturlap_'
          '${_format == ExportFormat.package ? 'paket_' : ''}'
          '$stamp.${_format.extension}';
      await File(path).writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'Usturlap verisi',
          text: 'Usturlap verisi (${set.count} nesne, ${_format.label})',
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Dışa aktarılamadı: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// KMZ için noktaların fotoğrafları.
  Future<Map<String, List<KmzPhoto>>> _photos(List<Waypoint> wps) async {
    final repo = ref.read(attachmentRepositoryProvider);
    final out = <String, List<KmzPhoto>>{};
    for (final w in wps) {
      for (final a in await repo.watchFor(w.uid).first) {
        final f = File(a.filePath);
        if (!await f.exists()) continue;
        final dot = a.filePath.lastIndexOf('.');
        (out[w.uid] ??= []).add(
          KmzPhoto(
            dot < 0 ? '.jpg' : a.filePath.substring(dot),
            await f.readAsBytes(),
          ),
        );
      }
    }
    return out;
  }
}
