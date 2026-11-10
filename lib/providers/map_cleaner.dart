import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/bloodhound.dart';
import '../domain/models/bullseye.dart';
import '../domain/models/clear_item.dart';
import '../domain/models/map_graphic.dart';
import '../domain/models/overlay_visibility.dart';
import '../domain/models/range_line.dart';
import '../domain/models/range_ring.dart';
import '../domain/models/route_plan.dart';
import '../domain/models/waypoint.dart';
import 'bloodhound_providers.dart';
import 'bullseye_providers.dart';
import 'graphic_providers.dart';
import 'nav_providers.dart';
import 'overlay_providers.dart';
import 'range_line_providers.dart';
import 'route_providers.dart';
import 'tool_providers.dart';
import 'terrain_analysis_providers.dart';
import 'viewshed_providers.dart';
import 'track_providers.dart';
import 'waypoint_providers.dart';

/// Haritada görünen (temizlenebilecek) nesneler, türüne göre.
class MapClearTargets {
  const MapClearTargets({
    required this.tool,
    required this.rangeLines,
    required this.rangeRings,
    required this.bullseye,
    required this.bloodhounds,
    required this.navTarget,
    required this.activeRoute,
    required this.displayedTrackId,
    required this.viewshed,
    required this.terrain,
    required this.waypoints,
    required this.graphics,
  });

  final ToolState tool;
  final List<RangeLine> rangeLines;
  final List<RangeRing> rangeRings;
  final Bullseye? bullseye;
  final List<Bloodhound> bloodhounds;
  final NavTarget? navTarget;
  final RoutePlan? activeRoute;
  final int? displayedTrackId;
  final ViewshedState? viewshed;
  final TerrainAnalysisState? terrain;
  final List<Waypoint> waypoints;
  final List<MapGraphic> graphics;

  int count(ClearItem i) => switch (i) {
    ClearItem.measurement => tool.points.isEmpty ? 0 : 1,
    ClearItem.rangeLines => rangeLines.length,
    ClearItem.rangeRings => rangeRings.length,
    ClearItem.bullseye => bullseye == null ? 0 : 1,
    ClearItem.bloodhounds => bloodhounds.length,
    ClearItem.navTarget => navTarget == null ? 0 : 1,
    ClearItem.activeRoute => activeRoute == null ? 0 : 1,
    ClearItem.displayedTrack => displayedTrackId == null ? 0 : 1,
    ClearItem.viewshed => viewshed?.grid == null ? 0 : 1,
    ClearItem.terrain =>
      (terrain?.contours.isNotEmpty == true ? 1 : 0) +
          (terrain?.image == null ? 0 : 1),
    ClearItem.waypoints => waypoints.length,
    ClearItem.graphics => graphics.length,
  };
}

/// Şu an haritada görünenler (Overlay yöneticisinde gizlenenler hariç).
final mapClearTargetsProvider = Provider<MapClearTargets>((ref) {
  final vis = ref.watch(overlayVisibilityProvider);
  return MapClearTargets(
    tool: ref.watch(toolProvider),
    rangeLines: [
      for (final l
          in ref.watch(rangeLinesProvider).value ?? const <RangeLine>[])
        if (vis.showsRangeLine(l)) l,
    ],
    rangeRings: [
      for (final r
          in ref.watch(rangeRingsProvider).value ?? const <RangeRing>[])
        if (vis.showsRangeRing(r)) r,
    ],
    bullseye: ref.watch(bullseyeProvider),
    bloodhounds: ref.watch(bloodhoundsProvider),
    navTarget: ref.watch(navTargetProvider),
    activeRoute: ref.watch(activeRouteProvider)?.route,
    displayedTrackId: ref.watch(displayedTrackIdProvider),
    viewshed: ref.watch(viewshedProvider),
    terrain: ref.watch(terrainAnalysisProvider),
    waypoints: [
      for (final w in ref.watch(waypointsProvider).value ?? const <Waypoint>[])
        if (vis.showsWaypoint(w)) w,
    ],
    graphics: [
      for (final g
          in ref.watch(mapGraphicsProvider).value ?? const <MapGraphic>[])
        if (vis.showsGraphic(g)) g,
    ],
  );
});

/// Bir temizliğin geri alınabilmesi için gerekenler.
class ClearSnapshot {
  ClearSnapshot(this.items, this.targets, {required this.hideOnly});

  final Set<ClearItem> items;
  final MapClearTargets targets;
  final bool hideOnly;

  /// "Yalnız gizle"de önceki görünürlük.
  OverlayVisibility? visibilityBefore;

  bool clears(ClearItem i) => items.contains(i) && targets.count(i) > 0;

  /// Silinmiş (gizlenmemiş) mi.
  bool deletes(ClearItem i) => clears(i) && !(hideOnly && i.canHide);
}

/// Haritayı temizle (D4b): seçilen türleri siler ya da gizler; "Geri al"
/// ile aynı kimlikleriyle geri yükler. Silinen noktaların fotoğrafları
/// ancak geri alma süresi dolunca ([finalize]) silinir.
class MapCleaner {
  MapCleaner(this._ref);

  final Ref _ref;

  Future<ClearSnapshot> clear(
    Set<ClearItem> items, {
    bool hideOnly = false,
  }) async {
    final t = _ref.read(mapClearTargetsProvider);
    final s = ClearSnapshot(items, t, hideOnly: hideOnly);

    // Gizlenebilenler: "yalnız gizle"de görünürlükten.
    if (hideOnly) {
      final groups = <String>{
        if (s.clears(ClearItem.waypoints))
          for (final a in Affiliation.values)
            OverlayVisibility.waypointGroup(a),
        if (s.clears(ClearItem.graphics)) OverlayVisibility.graphicsGroup,
        if (s.clears(ClearItem.rangeLines)) OverlayVisibility.rangeLinesGroup,
        if (s.clears(ClearItem.rangeRings)) OverlayVisibility.rangeRingsGroup,
      };
      if (groups.isNotEmpty) {
        final vis = _ref.read(overlayVisibilityProvider.notifier);
        s.visibilityBefore = _ref.read(overlayVisibilityProvider);
        vis.update((v) => v.setGroups(groups, hidden: true));
      }
    }

    if (s.clears(ClearItem.measurement)) {
      _ref.read(toolProvider.notifier).reset();
    }
    if (s.clears(ClearItem.bullseye)) {
      _ref.read(bullseyeProvider.notifier).set(null);
    }
    if (s.clears(ClearItem.bloodhounds)) {
      _ref.read(bloodhoundsProvider.notifier).clear();
    }
    if (s.clears(ClearItem.navTarget)) {
      _ref.read(navTargetProvider.notifier).clear();
    }
    if (s.clears(ClearItem.activeRoute)) {
      _ref.read(activeRouteProvider.notifier).stop();
    }
    if (s.clears(ClearItem.displayedTrack)) {
      _ref.read(displayedTrackIdProvider.notifier).show(null);
    }
    if (s.clears(ClearItem.viewshed)) {
      _ref.read(viewshedProvider.notifier).clear();
    }
    if (s.clears(ClearItem.terrain)) {
      _ref.read(terrainAnalysisProvider.notifier).clear();
    }
    if (s.deletes(ClearItem.rangeLines)) {
      final repo = _ref.read(rangeLineRepositoryProvider);
      for (final l in t.rangeLines) {
        await repo.delete(l.id!);
      }
    }
    if (s.deletes(ClearItem.rangeRings)) {
      final repo = _ref.read(rangeRingRepositoryProvider);
      for (final r in t.rangeRings) {
        await repo.delete(r.id!);
      }
    }
    if (s.deletes(ClearItem.waypoints)) {
      final repo = _ref.read(waypointRepositoryProvider);
      for (final w in t.waypoints) {
        await repo.delete(w.id!);
      }
    }
    if (s.deletes(ClearItem.graphics)) {
      final repo = _ref.read(mapGraphicRepositoryProvider);
      for (final g in t.graphics) {
        await repo.delete(g.id!);
      }
    }
    return s;
  }

  /// Temizliği geri alır: silinenler aynı uid'lerle geri eklenir.
  Future<void> undo(ClearSnapshot s) async {
    final t = s.targets;
    final before = s.visibilityBefore;
    if (before != null) {
      _ref.read(overlayVisibilityProvider.notifier).update((_) => before);
    }
    if (s.clears(ClearItem.measurement)) {
      _ref.read(toolProvider.notifier).restore(t.tool);
    }
    if (s.clears(ClearItem.bullseye)) {
      _ref.read(bullseyeProvider.notifier).set(t.bullseye);
    }
    if (s.clears(ClearItem.bloodhounds)) {
      final n = _ref.read(bloodhoundsProvider.notifier);
      for (final b in t.bloodhounds) {
        n.add(b.from, b.to);
      }
    }
    final nav = t.navTarget;
    if (s.clears(ClearItem.navTarget) && nav != null) {
      final n = _ref.read(navTargetProvider.notifier);
      n.set(nav.position, nav.label);
      n.setArriveBy(nav.arriveBy);
    }
    final route = t.activeRoute;
    if (s.clears(ClearItem.activeRoute) && route != null) {
      _ref.read(activeRouteProvider.notifier).start(route);
    }
    if (s.clears(ClearItem.displayedTrack)) {
      _ref.read(displayedTrackIdProvider.notifier).show(t.displayedTrackId);
    }
    if (s.clears(ClearItem.viewshed)) {
      _ref.read(viewshedProvider.notifier).restore(t.viewshed);
    }
    if (s.clears(ClearItem.terrain)) {
      _ref.read(terrainAnalysisProvider.notifier).restore(t.terrain);
    }
    if (s.deletes(ClearItem.rangeLines)) {
      final repo = _ref.read(rangeLineRepositoryProvider);
      for (final l in t.rangeLines) {
        await repo.add(
          name: l.name,
          start: l.start,
          end: l.end,
          colorValue: l.colorValue,
          uid: l.uid,
        );
      }
    }
    if (s.deletes(ClearItem.rangeRings)) {
      final repo = _ref.read(rangeRingRepositoryProvider);
      for (final r in t.rangeRings) {
        await repo.add(
          name: r.name,
          center: r.center,
          radii: r.radii,
          colorValue: r.colorValue,
          uid: r.uid,
        );
      }
    }
    if (s.deletes(ClearItem.waypoints)) {
      final repo = _ref.read(waypointRepositoryProvider);
      for (final w in t.waypoints) {
        final id = await repo.add(
          name: w.name,
          position: w.position,
          uid: w.uid,
          note: w.note,
          affiliation: w.affiliation,
          echelon: w.echelon,
          role: w.role,
          cotType: w.typeCode,
          hae: w.hae,
        );
        if (w.elevation != null) await repo.setElevation(id, w.elevation);
        if (w.fov != null) await repo.setFov(id, w.fov);
      }
    }
    if (s.deletes(ClearItem.graphics)) {
      final repo = _ref.read(mapGraphicRepositoryProvider);
      for (final g in t.graphics) {
        await repo.add(
          name: g.name,
          type: g.type,
          points: g.points,
          colorValue: g.colorValue,
          uid: g.uid,
          strokeWidth: g.strokeWidth,
          dashed: g.dashed,
          height: g.height,
        );
      }
    }
  }

  /// Geri alma süresi doldu: silinen noktaların fotoğraflarını da sil.
  Future<void> finalize(ClearSnapshot s) async {
    if (!s.deletes(ClearItem.waypoints)) return;
    final attachments = _ref.read(attachmentRepositoryProvider);
    for (final w in s.targets.waypoints) {
      await attachments.deleteAllFor(w.uid);
    }
  }
}

final mapCleanerProvider = Provider<MapCleaner>(MapCleaner.new);
