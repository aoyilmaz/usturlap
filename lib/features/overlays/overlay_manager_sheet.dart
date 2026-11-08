import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/map_graphic.dart';
import '../../domain/models/overlay_visibility.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/overlay_providers.dart';
import '../../providers/route_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';
import '../symbols/nato_symbol.dart';

/// Overlay yöneticisi (ATAK Overlay Manager + Hashtags, kılavuz s.23–24).
/// Panel modal olmadığı için değişiklikler haritada hemen görünür.
Future<void> showOverlayManagerSheet(
  BuildContext context, {
  required ValueChanged<LatLng> onCenter,
  required ValueChanged<RoutePlan> onShowRoute,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'overlays',
    toggle: true,
    isScrollControlled: true,
    builder: (_) =>
        OverlayManager(onCenter: onCenter, onShowRoute: onShowRoute),
  );
}

class OverlayManager extends ConsumerWidget {
  const OverlayManager({
    super.key,
    required this.onCenter,
    required this.onShowRoute,
  });

  final ValueChanged<LatLng> onCenter;
  final ValueChanged<RoutePlan> onShowRoute;

  static String _affLabel(Affiliation a) =>
      a == Affiliation.waypoint ? 'Nokta' : a.label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vis = ref.watch(overlayVisibilityProvider);
    final notifier = ref.read(overlayVisibilityProvider.notifier);
    final waypoints = ref.watch(waypointsProvider).value ?? const <Waypoint>[];
    final graphics =
        ref.watch(mapGraphicsProvider).value ?? const <MapGraphic>[];
    final tracks = ref.watch(tracksProvider).value ?? const [];
    final routes = ref.watch(routesProvider).value ?? const <RoutePlan>[];
    final repeatersOn = ref.watch(showRepeatersProvider);
    final shownTrack = ref.watch(displayedTrackIdProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    // Etiket süzgeci listeyi de daraltır.
    final tag = vis.tag;
    bool tagged(Set<String> tags) => tag == null || tags.contains(tag);
    final tags = <String>{
      for (final w in waypoints) ...OverlayVisibility.tagsOfWaypoint(w),
      for (final g in graphics) ...OverlayVisibility.tagsOfName(g.name),
      for (final t in tracks) ...OverlayVisibility.tagsOfName(t.name),
      for (final r in routes) ...OverlayVisibility.tagsOfName(r.name),
    }.toList()..sort();
    final wps = [
      for (final w in waypoints)
        if (tagged(OverlayVisibility.tagsOfWaypoint(w))) w,
    ];
    final gfx = [
      for (final g in graphics)
        if (tagged(OverlayVisibility.tagsOfName(g.name))) g,
    ];
    final trk = [
      for (final t in tracks)
        if (tagged(OverlayVisibility.tagsOfName(t.name))) t,
    ];
    final rts = [
      for (final r in routes)
        if (tagged(OverlayVisibility.tagsOfName(r.name))) r,
    ];

    final wpGroups = [
      for (final a in Affiliation.values) OverlayVisibility.waypointGroup(a),
    ];
    final allWpVisible = !wpGroups.any(vis.hiddenGroups.contains);

    Widget eye({
      required bool visible,
      required String name,
      required VoidCallback onPressed,
    }) => IconButton(
      tooltip: visible ? 'Gizle: $name' : 'Göster: $name',
      icon: Icon(
        visible ? Icons.visibility : Icons.visibility_off,
        color: visible ? null : muted,
      ),
      onPressed: onPressed,
    );

    Widget header(String title, int count, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title ($count)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    Widget item({
      required Widget leading,
      required String name,
      required Set<String> itemTags,
      required bool onMap,
      VoidCallback? onTap,
      Widget? trailing,
      bool selected = false,
    }) => ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: leading,
      selected: selected,
      title: Text(name, style: TextStyle(color: onMap ? null : muted)),
      subtitle: itemTags.isEmpty
          ? null
          : Text(
              itemTags.map((t) => '#$t').join(' '),
              style: const TextStyle(fontSize: 12),
            ),
      trailing: trailing,
      onTap: onTap,
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text(
          'Overlay yöneticisi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Göz düğmesi haritada gösterir/gizler. Ad ya da nottaki #kelimeler '
          'etiket olur; bir etikete dokununca haritada yalnız onlar kalır.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags)
                FilterChip(
                  label: Text('#$t'),
                  selected: tag == t,
                  onSelected: (on) =>
                      notifier.update((v) => v.withTag(on ? t : null)),
                ),
            ],
          ),
        ],
        if (tag != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Haritada yalnız #$tag etiketli noktalar ve çizimler görünüyor.',
              style: const TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ),

        // --- Noktalar (türe göre)
        header(
          'Noktalar',
          wps.length,
          trailing: eye(
            visible: allWpVisible,
            name: 'Noktalar',
            onPressed: () => notifier.update(
              (v) => v.setGroups(wpGroups, hidden: allWpVisible),
            ),
          ),
        ),
        for (final a in Affiliation.values)
          if (wps.any((w) => w.affiliation == a))
            _Group(
              title:
                  '${_affLabel(a)} (${wps.where((w) => w.affiliation == a).length})',
              leading: _waypointIcon(a),
              trailing: eye(
                visible: !vis.hiddenGroups.contains(
                  OverlayVisibility.waypointGroup(a),
                ),
                name: _affLabel(a),
                onPressed: () => notifier.update(
                  (v) => v.toggleGroup(OverlayVisibility.waypointGroup(a)),
                ),
              ),
              children: [
                for (final w in wps.where((w) => w.affiliation == a))
                  item(
                    leading: const SizedBox(width: 8),
                    name: w.name,
                    itemTags: OverlayVisibility.tagsOfWaypoint(w),
                    onMap: vis.showsWaypoint(w),
                    onTap: () => onCenter(w.position),
                    trailing: eye(
                      visible: !vis.hiddenUids.contains(w.uid),
                      name: w.name,
                      onPressed: () =>
                          notifier.update((v) => v.toggleUid(w.uid)),
                    ),
                  ),
              ],
            ),

        // --- Çizimler
        header(
          'Çizimler',
          gfx.length,
          trailing: eye(
            visible: !vis.hiddenGroups.contains(
              OverlayVisibility.graphicsGroup,
            ),
            name: 'Çizimler',
            onPressed: () => notifier.update(
              (v) => v.toggleGroup(OverlayVisibility.graphicsGroup),
            ),
          ),
        ),
        for (final g in gfx)
          item(
            leading: Icon(
              g.type == GraphicType.area
                  ? Icons.pentagon_outlined
                  : Icons.timeline,
              color: Color(g.colorValue),
            ),
            name: g.name,
            itemTags: OverlayVisibility.tagsOfName(g.name),
            onMap: vis.showsGraphic(g),
            onTap: g.points.isEmpty ? null : () => onCenter(_middle(g.points)),
            trailing: eye(
              visible: !vis.hiddenUids.contains(g.uid),
              name: g.name,
              onPressed: () => notifier.update((v) => v.toggleUid(g.uid)),
            ),
          ),

        // --- İzler: haritada bir seferde biri gösterilir.
        header('İzler', trk.length),
        for (final t in trk)
          item(
            leading: const Icon(Icons.route_outlined),
            name: t.name,
            itemTags: OverlayVisibility.tagsOfName(t.name),
            onMap: shownTrack == t.id,
            selected: shownTrack == t.id,
            onTap: () => ref
                .read(displayedTrackIdProvider.notifier)
                .show(shownTrack == t.id ? null : t.id),
            trailing: Text(
              shownTrack == t.id ? 'haritada' : 'göster',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),

        // --- Rotalar: dokununca önizlenir.
        header('Rotalar', rts.length),
        for (final r in rts)
          item(
            leading: const Icon(Icons.alt_route),
            name: r.name,
            itemTags: OverlayVisibility.tagsOfName(r.name),
            onMap: true,
            onTap: r.points.isEmpty ? null : () => onShowRoute(r),
          ),

        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.cell_tower),
          title: const Text('Telsiz röleleri'),
          value: repeatersOn,
          onChanged: (_) => ref.read(showRepeatersProvider.notifier).toggle(),
        ),
        if (!vis.isDefault)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text('Hepsini göster'),
              onPressed: notifier.reset,
            ),
          ),
      ],
    );
  }

  static Widget _waypointIcon(Affiliation a) => a == Affiliation.waypoint
      ? const Icon(Icons.location_on, color: Colors.redAccent)
      : SizedBox(
          width: 24,
          height: 24,
          child: NatoSymbol(affiliation: a, size: 22),
        );

  static LatLng _middle(List<LatLng> pts) {
    var lat = 0.0, lon = 0.0;
    for (final p in pts) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / pts.length, lon / pts.length);
  }
}

/// Açılır-kapanır grup (ör. Düşman noktaları); başlıkta göz düğmesi.
class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.leading,
    required this.trailing,
    required this.children,
  });

  final String title;
  final Widget leading;
  final Widget trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.only(left: 0, right: 4),
      controlAffinity: ListTileControlAffinity.leading,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      trailing: trailing,
      children: children,
    );
  }
}
