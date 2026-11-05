import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_math.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/waypoint_providers.dart';

/// Rota: etkin hedef (mesafe/kerteriz) + kayıtlı noktalardan birine "Git".
/// (Çok noktalı rota planlama sonraki aşamada bu sekmeye eklenecek.)
Future<void> showRouteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _RouteSheet(),
  );
}

class _RouteSheet extends ConsumerWidget {
  const _RouteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(navTargetProvider);
    final self = ref.watch(selfContactProvider);
    final waypoints = [...?ref.watch(waypointsProvider).value];
    if (self != null) {
      waypoints.sort((a, b) => GeoMath.distance(self.position, a.position)
          .compareTo(GeoMath.distance(self.position, b.position)));
    }

    String rel(Waypoint w) {
      if (self == null) return '';
      final d = GeoMath.distance(self.position, w.position);
      final b = GeoMath.bearing(self.position, w.position);
      return '${GeoMath.fmtDistance(d)} · ${GeoMath.fmtBearing((b + 360) % 360)}';
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Rota',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (target != null)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ListTile(
                  leading: const Icon(Icons.navigation, color: Colors.amber),
                  title: Text('Hedef: ${target.label}'),
                  subtitle: self == null
                      ? const Text('Konum bekleniyor…')
                      : Text(
                          '${GeoMath.fmtDistance(GeoMath.distance(self.position, target.position))} · '
                          '${GeoMath.fmtBearing((GeoMath.bearing(self.position, target.position) + 360) % 360)}'),
                  trailing: TextButton(
                    onPressed: () => ref.read(navTargetProvider.notifier).clear(),
                    child: const Text('Bırak'),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Etkin hedef yok. Bir noktaya "Git" deyin ya da Koordinat '
                  'sekmesinden artı imleçteki yere gidin.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Noktaya git',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
            if (waypoints.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kayıtlı nokta yok.'),
              )
            else
              for (final w in waypoints)
                ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(w.name),
                  subtitle: Text(rel(w)),
                  trailing: const Icon(Icons.navigation_outlined),
                  onTap: () {
                    ref.read(navTargetProvider.notifier).set(w.position, w.name);
                    Navigator.of(context).pop();
                  },
                ),
          ],
        ),
      ),
    );
  }
}
