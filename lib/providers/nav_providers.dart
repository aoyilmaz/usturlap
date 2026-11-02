import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Navigasyon hedefi (waypoint/röle/serbest nokta) + etiketi.
class NavTarget {
  final LatLng position;
  final String label;
  const NavTarget(this.position, this.label);
}

/// Seçili "Git" hedefi. null = navigasyon kapalı.
class NavTargetNotifier extends Notifier<NavTarget?> {
  @override
  NavTarget? build() => null;

  void set(LatLng position, String label) =>
      state = NavTarget(position, label);
  void clear() => state = null;
}

final navTargetProvider =
    NotifierProvider<NavTargetNotifier, NavTarget?>(NavTargetNotifier.new);
