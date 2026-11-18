import 'dart:io';

import '../../core/uuid.dart';
import '../db/app_database.dart';
import '../db/attachment_repository.dart';
import '../db/map_graphic_repository.dart';
import '../db/range_line_repository.dart';
import '../db/range_ring_repository.dart';
import '../db/route_repository.dart';
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
  int routes = 0;
  int photos = 0;

  /// Kimliği zaten olan (daha önce içe aktarılmış) nesneler.
  int skipped = 0;

  int get added =>
      waypoints + graphics + tracks + rangeLines + rangeRings + routes;

  String get summary => [
    if (waypoints > 0) '$waypoints nokta',
    if (graphics > 0) '$graphics çizim',
    if (tracks > 0) '$tracks iz',
    if (rangeLines > 0) '$rangeLines R&B',
    if (rangeRings > 0) '$rangeRings halka',
    if (routes > 0) '$routes rota',
    if (photos > 0) '$photos fotoğraf',
  ].join(', ');
}

/// Okunan dosyayı veritabanına yazar. Usturlap'tan çıkmış nesnelerin
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
    this.routes,
    this.db,
    Directory? tempDir,
  }) : _tempDir = tempDir ?? Directory.systemTemp;

  /// Verilirse bütün yazma tek veritabanı işleminde yapılır: ortada bir hata
  /// olursa hiçbir nesne eklenmez (yarım içe aktarma kalmaz; yeniden
  /// denemede "zaten var" diye atlanan nesne olmaz).
  final AppDatabase? db;

  /// Veritabanındaki ad sütunlarının sınırı (1–80 karakter).
  static const maxNameLength = 80;

  /// Adı sütun sınırına uydurur: boşsa [fallback], uzunsa kırpılır. Dış
  /// dosyalarda 80 karakterden uzun adlar olağan; kırpılmazsa ekleme hata
  /// verip içe aktarmayı yarıda kesiyordu.
  static String safeName(String raw, String fallback) {
    final t = raw.trim();
    if (t.isEmpty) return fallback;
    if (t.length <= maxNameLength) return t;
    // Vekil çifti (emoji vb.) ortadan bölünmesin: rune rune ekle.
    final b = StringBuffer();
    for (final r in t.runes) {
      final ch = String.fromCharCode(r);
      if (b.length + ch.length > maxNameLength) break;
      b.write(ch);
    }
    return b.toString().trimRight();
  }

  final WaypointRepository waypoints;
  final MapGraphicRepository graphics;
  final TrackRepository tracks;
  final RangeLineRepository rangeLines;
  final RangeRingRepository rangeRings;
  final AttachmentRepository attachments;

  /// Rotalar (verilmezse rota içe aktarılmaz).
  final RouteRepository? routes;
  final Directory _tempDir;

  Future<ImportReport> write(ImportBundle b) async {
    // Var olan kimlikler işlemden önce okunur (akış sorguları işlem dışında).
    final existing = _Existing(
      waypoints: {for (final w in await waypoints.watchAll().first) w.uid},
      graphics: {for (final g in await graphics.watchAll().first) g.uid},
      tracks: {for (final t in await tracks.watchTracks().first) t.uid},
      rangeLines: {for (final l in await rangeLines.watchAll().first) l.uid},
      rangeRings: {for (final x in await rangeRings.watchAll().first) x.uid},
      routes: routes == null
          ? <String>{}
          : {for (final x in await routes!.watchAll().first) x.uid},
    );
    // Hata olursa silinecek fotoğraf klasörleri (dosyalar işleme girmez).
    final photoUids = <String>{};
    final database = db;
    try {
      return database == null
          ? await _write(b, existing, photoUids)
          : await database.transaction(() => _write(b, existing, photoUids));
    } catch (_) {
      for (final uid in photoUids) {
        try {
          await attachments.deleteAllFor(uid);
        } catch (_) {
          // Temizlik elinden geleni yapar; asıl hata yükseltilir.
        }
      }
      rethrow;
    }
  }

  Future<ImportReport> _write(
    ImportBundle b,
    _Existing existing,
    Set<String> photoUids,
  ) async {
    final r = b.result;
    final report = ImportReport();

    final wpUids = existing.waypoints;
    for (final w in r.waypoints) {
      if (w.uid != null && !wpUids.add(w.uid!)) {
        report.skipped++;
        continue;
      }
      final uid = w.uid ?? newUuidV4();
      final id = await waypoints.add(
        name: safeName(w.name, 'NOKTA'),
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
          photoUids.add(uid);
          await attachments.addFile(uid, tmp);
          report.photos++;
        } finally {
          if (await tmp.exists()) await tmp.delete();
        }
      }
    }

    final gUids = existing.graphics;
    for (final g in r.graphics) {
      if (!gUids.add(g.uid)) {
        report.skipped++;
        continue;
      }
      await graphics.add(
        name: safeName(g.name, 'ÇİZİM'),
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

    final tUids = existing.tracks;
    for (final t in r.tracks) {
      if (t.uid != null && !tUids.add(t.uid!)) {
        report.skipped++;
        continue;
      }
      await tracks.importTrack(
        safeName(t.name, 'İZ'),
        t.points,
        uid: t.uid,
        times: t.detail?.times,
        altitudes: t.detail?.altitudes,
        speeds: t.detail?.speeds,
      );
      report.tracks++;
    }

    final lUids = existing.rangeLines;
    for (final l in r.rangeLines) {
      if (!lUids.add(l.uid)) {
        report.skipped++;
        continue;
      }
      await rangeLines.add(
        name: safeName(l.name, 'R&B'),
        start: l.start,
        end: l.end,
        colorValue: l.colorValue,
        uid: l.uid,
      );
      report.rangeLines++;
    }

    final rUids = existing.rangeRings;
    for (final x in r.rangeRings) {
      if (!rUids.add(x.uid)) {
        report.skipped++;
        continue;
      }
      await rangeRings.add(
        name: safeName(x.name, 'HALKA'),
        center: x.center,
        radii: x.radii,
        colorValue: x.colorValue,
        uid: x.uid,
      );
      report.rangeRings++;
    }

    final routeRepo = routes;
    if (routeRepo != null && r.routes.isNotEmpty) {
      final uids = existing.routes;
      for (final x in r.routes) {
        if (!uids.add(x.uid)) {
          report.skipped++;
          continue;
        }
        await routeRepo.add(
          name: safeName(x.name, 'ROTA'),
          points: x.points,
          pointNames: x.pointNames,
          uid: x.uid,
        );
        report.routes++;
      }
    }
    return report;
  }
}

/// İçe aktarmadan önce veritabanında bulunan kimlikler (tür başına).
class _Existing {
  _Existing({
    required this.waypoints,
    required this.graphics,
    required this.tracks,
    required this.rangeLines,
    required this.rangeRings,
    required this.routes,
  });
  final Set<String?> waypoints;
  final Set<String?> graphics;
  final Set<String?> tracks;
  final Set<String?> rangeLines;
  final Set<String?> rangeRings;
  final Set<String?> routes;
}
