import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_math.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/route_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import 'adaptive_sheet.dart';

/// Rota: yeni rota planla, kayıtlı rotaları takip et, tek noktaya "Git".
Future<void> showRouteSheet(
  BuildContext context, {
  required VoidCallback onPlanNew,
  required void Function(RoutePlan r) onShowRoute,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _RouteSheet(onPlanNew: onPlanNew, onShowRoute: onShowRoute),
  );
}

class _RouteSheet extends ConsumerWidget {
  const _RouteSheet({required this.onPlanNew, required this.onShowRoute});

  final VoidCallback onPlanNew;
  final void Function(RoutePlan r) onShowRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(navTargetProvider);
    final active = ref.watch(activeRouteProvider);
    final routes = ref.watch(routesProvider).value ?? const <RoutePlan>[];
    final self = ref.watch(selfContactProvider);
    final waypoints = [...?ref.watch(waypointsProvider).value];
    final fmt = ref.watch(bearingFormatterProvider);
    if (self != null) {
      waypoints.sort((a, b) => GeoMath.distance(self.position, a.position)
          .compareTo(GeoMath.distance(self.position, b.position)));
    }

    String rel(Waypoint w) {
      if (self == null) return '';
      final d = GeoMath.distance(self.position, w.position);
      final b = GeoMath.bearing(self.position, w.position);
      return '${GeoMath.fmtDistance(d)} · ${fmt.format(b, self.position)}';
    }

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(t,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white70)),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Rota',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPlanNew();
                },
                icon: const Icon(Icons.add_road),
                label: const Text('Yeni rota planla'),
              ),
            ),
            if (active != null)
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: ListTile(
                  leading: const Icon(Icons.alt_route, color: Colors.amber),
                  title: Text('Takip: ${active.route.name}'),
                  subtitle: Text(GeoMath.fmtDistance(active.route.length)),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(activeRouteProvider.notifier).stop(),
                    child: const Text('Bitir'),
                  ),
                ),
              ),
            if (target != null)
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: ListTile(
                  leading: const Icon(Icons.navigation, color: Colors.amber),
                  title: Text('Hedef: ${target.label}'),
                  subtitle: self == null
                      ? const Text('Konum bekleniyor…')
                      : Text(
                          '${GeoMath.fmtDistance(GeoMath.distance(self.position, target.position))} · '
                          '${fmt.format(GeoMath.bearing(self.position, target.position), self.position)}'),
                  trailing: TextButton(
                    onPressed: () => ref.read(navTargetProvider.notifier).clear(),
                    child: const Text('Bırak'),
                  ),
                ),
              ),
            header('Kayıtlı rotalar'),
            if (routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Henüz rota yok.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              for (final r in routes)
                ListTile(
                  leading: const Icon(Icons.route),
                  title: Text(r.name),
                  subtitle: Text(
                      '${GeoMath.fmtDistance(r.length)} · ${r.points.length} nokta'
                      '${self == null ? '' : ' · başlangıca ${GeoMath.fmtDistance(GeoMath.distance(self.position, r.points.first))}'}'),
                  onTap: () {
                    ref.read(activeRouteProvider.notifier).start(r);
                    Navigator.of(context).pop();
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'show') {
                        Navigator.of(context).pop();
                        onShowRoute(r);
                      } else if (v == 'delete') {
                        if (active?.route.id == r.id) {
                          ref.read(activeRouteProvider.notifier).stop();
                        }
                        await ref.read(routeRepositoryProvider).delete(r.id!);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'show', child: Text('Haritada göster')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
                ),
            header('Noktaya git'),
            if (waypoints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Kayıtlı nokta yok.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              for (final w in waypoints)
                ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(w.name),
                  subtitle: Text(rel(w)),
                  trailing: const Icon(Icons.navigation_outlined),
                  onTap: () {
                    ref.read(activeRouteProvider.notifier).stop();
                    ref.read(navTargetProvider.notifier).set(w.position, w.name);
                    Navigator.of(context).pop();
                  },
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
