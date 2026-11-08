import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Navigasyon hedefi (waypoint/röle/serbest nokta) + etiketi.
class NavTarget {
  final LatLng position;
  final String label;

  /// Buluşma saati (E7): bu saatte hedefte olmak için gereken hız
  /// gösterilir. null = yok.
  final DateTime? arriveBy;

  const NavTarget(this.position, this.label, {this.arriveBy});
}

/// Seçili "Git" hedefi. null = navigasyon kapalı.
class NavTargetNotifier extends Notifier<NavTarget?> {
  @override
  NavTarget? build() => null;

  /// Aynı hedef (aynı ad) yeniden verilirse (ör. nokta taşındı) buluşma
  /// saati korunur; yeni hedefte sıfırlanır.
  void set(LatLng position, String label) => state = NavTarget(
    position,
    label,
    arriveBy: state?.label == label ? state?.arriveBy : null,
  );

  void setArriveBy(DateTime? at) {
    final t = state;
    if (t == null) return;
    state = NavTarget(t.position, t.label, arriveBy: at);
  }

  void clear() => state = null;
}

final navTargetProvider = NotifierProvider<NavTargetNotifier, NavTarget?>(
  NavTargetNotifier.new,
);
