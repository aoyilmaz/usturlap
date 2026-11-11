import 'dart:io';

import '../../core/uuid.dart';
import '../db/attachment_repository.dart';
import '../db/map_graphic_repository.dart';
import '../db/range_line_repository.dart';
import '../db/range_ring_repository.dart';
import '../db/track_repository.dart';
import '../db/waypoint_repository.dart';
import 'geo_import.dart';

/// İçe aktarmanın sonucu (kaç tane eklendi / atlandı).
class ImportReport {
  int waypoints = 0;
  int graphics = 0;
  int tracks = 0;
  int rangeLines = 0;
  int rangeRings = 0;
  int photos = 0;

  /// Kimliği zaten olan (daha önce içe aktarılmış) nesneler.
  int skipped = 0;

  int get added => waypoints + graphics + tracks + rangeLines + rangeRings;

  String get summary => [
    if (waypoints > 0) '$waypoints nokta',
    if (graphics > 0) '$graphics çizim',
    if (tracks > 0) '$tracks iz',
    if (rangeLines > 0) '$rangeLines R&B',
    if (rangeRings > 0) '$rangeRings halka',
    if (photos > 0) '$photos fotoğraf',
  ].join(', ');
}

/// Okunan dosyayı veritabanına yazar. Pusula'dan çıkmış nesnelerin
/// kimliği korunur; aynı kimlik zaten varsa nesne atlanır (aynı dosyayı
/// iki kez açınca kopya oluşmaz). KMZ fotoğrafları noktaya eklenir.
class ImportWriter {
  ImportWriter({
    required this.waypoints,
    required this.graphics,
    required this.tracks,
    required this.rangeLines,
    required this.rangeRings,
    required this.attachments,
    Directory? tempDir,
  }) : _tempDir = tempDir ?? Directory.systemTemp;

  final WaypointRepository waypoints;
  final MapGraphicRepository graphics;
  final TrackRepository tracks;
  final RangeLineRepository rangeLines;
  final RangeRingRepository rangeRings;
  final AttachmentRepository attachments;
  final Directory _tempDir;

  Future<ImportReport> write(ImportBundle b) async {
    final r = b.result;
    final report = ImportReport();

    final wpUids = {for (final w in await waypoints.watchAll().first) w.uid};
    for (final w in r.waypoints) {
      if (w.uid != null && !wpUids.add(w.uid!)) {
        report.skipped++;
        continue;
      }
      final uid = w.uid ?? newUuidV4();
      final id = await waypoints.add(
        name: w.name,
        position: w.position,
        uid: uid,
        note: w.note,
        affiliation: w.affiliation,
        echelon: w.echelon,
        role: w.role,
        cotType: w.cotType,
        hae: w.hae,
      );
      if (w.elevation != null) await waypoints.setElevation(id, w.elevation);
      if (w.fov != null) await waypoints.setFov(id, w.fov);
      report.waypoints++;
      for (final path in w.photos) {
        final bytes = GeoImport.photoFor(b, path);
        if (bytes == null) continue;
        final dot = path.lastIndexOf('.');
        final ext = dot < 0 ? '.jpg' : path.substring(dot).toLowerCase();
        final tmp = File('${_tempDir.path}/ice_aktar_${newUuidV4()}$ext');
        try {
          await tmp.writeAsBytes(bytes, flush: true);
          await attachments.addFile(uid, tmp);
          report.photos++;
        } finally {
          if (await tmp.exists()) await tmp.delete();
        }
      }
    }

    final gUids = {for (final g in await graphics.watchAll().first) g.uid};
    for (final g in r.graphics) {
      if (!gUids.add(g.uid)) {
        report.skipped++;
        continue;
      }
      await graphics.add(
        name: g.name,
        type: g.type,
        points: g.points,
        colorValue: g.colorValue,
        uid: g.uid,
        strokeWidth: g.strokeWidth,
        dashed: g.dashed,
        height: g.height,
        geofence: g.geofence,
      );
      report.graphics++;
    }

    final tUids = {for (final t in await tracks.watchTracks().first) t.uid};
    for (final t in r.tracks) {
      if (t.uid != null && !tUids.add(t.uid!)) {
        report.skipped++;
        continue;
      }
      await tracks.importTrack(t.name, t.points, uid: t.uid);
      report.tracks++;
    }

    final lUids = {for (final l in await rangeLines.watchAll().first) l.uid};
    for (final l in r.rangeLines) {
      if (!lUids.add(l.uid)) {
        report.skipped++;
        continue;
      }
      await rangeLines.add(
        name: l.name,
        start: l.start,
        end: l.end,
        colorValue: l.colorValue,
        uid: l.uid,
      );
      report.rangeLines++;
    }

    final rUids = {for (final x in await rangeRings.watchAll().first) x.uid};
    for (final x in r.rangeRings) {
      if (!rUids.add(x.uid)) {
        report.skipped++;
        continue;
      }
      await rangeRings.add(
        name: x.name,
        center: x.center,
        radii: x.radii,
        colorValue: x.colorValue,
        uid: x.uid,
      );
      report.rangeRings++;
    }
    return report;
  }
}
