import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/usecases/route_profile.dart';
import '../../providers/elevation_providers.dart';
import '../shell/adaptive_sheet.dart';

/// Arazi yüksekliği kaynağı (testte sahtesi takılır). null = veri yok.
typedef ElevationAt = Future<double?> Function(LatLng p);

final routeElevationAtProvider = Provider<ElevationAt>((ref) {
  final parser = ref.watch(hgtParserProvider);
  return (p) async {
    final v = await parser.getElevation(p.latitude, p.longitude);
    // SRTM boşluk değeri (-32768): veri yok.
    return v == null || v < -500 ? null : v.toDouble();
  };
});

/// Rota boyunca yükseklik profili: grafik, kontrol noktaları, toplam çıkış /
/// iniş, en yüksek / en alçak. Veri cihazdaki arazi dosyalarından.
Future<void> showRouteProfilePanel(BuildContext context, RoutePlan route) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'route-profile:${route.uid}',
    isScrollControlled: true,
    builder: (_) => RouteProfilePanel(route: route),
  );
}

class RouteProfilePanel extends ConsumerStatefulWidget {
  const RouteProfilePanel({super.key, required this.route});

  final RoutePlan route;

  @override
  ConsumerState<RouteProfilePanel> createState() => _RouteProfilePanelState();
}

class _RouteProfilePanelState extends ConsumerState<RouteProfilePanel> {
  late final Future<RouteProfile> _profile = RouteProfile.build(
    widget.route.points,
    ref.read(routeElevationAtProvider),
  );

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.name}: yükseklik profili',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FutureBuilder<RouteProfile>(
            future: _profile,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  'Profil hesaplanamadı: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                );
              }
              final p = snap.data;
              if (p == null) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!p.hasData) {
                return Text(
                  'Bu rota için arazi verisi yok. Yükseklik dosyaları '
                  '(HGT) cihaza yüklenince profil çıkar.',
                  style: TextStyle(color: muted),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '↗ ${p.ascent.round()} m · ↘ ${p.descent.round()} m · '
                    'en yüksek ${p.maxElevation!.round()} m · '
                    'en alçak ${p.minElevation!.round()} m',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Uzunluk ${GeoMath.fmtDistance(p.length)}',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: RouteProfilePainter(
                        profile: p,
                        pointNames: [
                          for (var i = 0; i < r.points.length; i++) r.nameOf(i),
                        ],
                        line: Theme.of(context).colorScheme.primary,
                        text: muted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Mesafe (yatay) – yükseklik (dikey) grafiği; noktalar dikey çizgi + ad.
class RouteProfilePainter extends CustomPainter {
  RouteProfilePainter({
    required this.profile,
    required this.pointNames,
    required this.line,
    required this.text,
  });

  final RouteProfile profile;
  final List<String> pointNames;
  final Color line;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = profile.minElevation, hi = profile.maxElevation;
    if (lo == null || hi == null || profile.length <= 0) return;
    // Üstte nokta adları, solda yükseklik etiketleri için pay.
    const top = 16.0, left = 40.0, bottom = 4.0;
    final w = size.width - left, h = size.height - top - bottom;
    final range = (hi - lo).clamp(10.0, double.infinity);
    final y0 = lo - range * 0.1, y1 = hi + range * 0.1;
    Offset at(double d, double e) => Offset(
      left + d / profile.length * w,
      top + h - (e - y0) / (y1 - y0) * h,
    );

    // Eğri (veri boşluklarında kopar) + altı dolgu.
    final curve = ui.Path();
    var open = false;
    for (final s in profile.samples) {
      final e = s.elevation;
      if (e == null) {
        open = false;
        continue;
      }
      final o = at(s.distance, e);
      if (open) {
        curve.lineTo(o.dx, o.dy);
      } else {
        curve.moveTo(o.dx, o.dy);
        open = true;
      }
    }
    final fill = ui.Path.from(curve)
      ..lineTo(left + w, top + h)
      ..lineTo(left, top + h)
      ..close();
    canvas.drawPath(fill, Paint()..color = line.withValues(alpha: 0.15));
    canvas.drawPath(
      curve,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    void label(String s, Offset o, {bool center = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(color: text, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(center ? tp.width / 2 : 0, 0));
      tp.dispose();
    }

    // Yükseklik etiketleri.
    label('${hi.round()} m', Offset(0, at(0, hi).dy - 6));
    label('${lo.round()} m', Offset(0, at(0, lo).dy - 6));

    // Kontrol noktaları: kesikli dikey çizgi + ad (sığmıyorsa atlanır).
    final dash = Paint()
      ..color = text.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    var lastX = -100.0;
    for (var i = 0; i < profile.pointDistances.length; i++) {
      final x = at(profile.pointDistances[i], lo).dx;
      for (var y = top; y < top + h; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 3), dash);
      }
      if (x - lastX >= 44 && i < pointNames.length) {
        label(pointNames[i], Offset(x, 0), center: true);
        lastX = x;
      }
    }
  }

  @override
  bool shouldRepaint(RouteProfilePainter old) =>
      old.profile != profile || old.line != line || old.text != text;
}
