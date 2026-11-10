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

/// Ara değerli (çift doğrusal) arazi yüksekliği.
final elevationAtProvider = Provider<ElevationAt>((ref) {
  final parser = ref.watch(hgtParserProvider);
  return (p) async {
    final v = await parser.elevationAt(p.latitude, p.longitude);
    // SRTM boşluk değeri: veri yok.
    return v == null || v < -500 ? null : v;
  };
});

/// Eğim rengi: < %10 yeşil, < %20 sarı, üstü kırmızı (çıkış ya da iniş).
Color gradeColor(double grade) {
  final g = grade.abs();
  if (g < 10) return Colors.lightGreenAccent;
  if (g < 20) return Colors.amber;
  return Colors.redAccent;
}

/// "%18" / "−%12" (Türkçede yüzde işareti önde).
String fmtGrade(double grade) =>
    '${grade < 0 ? '−' : ''}%${grade.abs().round()}';

/// Rota boyunca yükseklik profili (noktalar rota adlarıyla).
Future<void> showRouteProfilePanel(BuildContext context, RoutePlan route) =>
    showElevationProfilePanel(
      context,
      id: 'route-profile:${route.uid}',
      title: '${route.name}: yükseklik profili',
      points: route.points,
      pointNames: [
        for (var i = 0; i < route.points.length; i++) route.nameOf(i),
      ],
    );

/// Bir çizgi boyunca yükseklik profili (ATAK Elevation Tools, kılavuz
/// s.48): grafik (eğime göre renkli), toplam çıkış / iniş, en yüksek /
/// en alçak, en dik çıkış / iniş. Veri cihazdaki arazi dosyalarından.
Future<void> showElevationProfilePanel(
  BuildContext context, {
  required String title,
  required List<LatLng> points,
  List<String>? pointNames,
  String? id,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: id ?? 'profile',
    isScrollControlled: true,
    builder: (_) => ElevationProfilePanel(
      title: title,
      points: points,
      pointNames: pointNames,
    ),
  );
}

class ElevationProfilePanel extends ConsumerStatefulWidget {
  const ElevationProfilePanel({
    super.key,
    required this.title,
    required this.points,
    this.pointNames,
  });

  final String title;
  final List<LatLng> points;

  /// Köşe adları (grafikte dikey çizgilerin üstünde); yoksa 1, 2, 3…
  final List<String>? pointNames;

  @override
  ConsumerState<ElevationProfilePanel> createState() =>
      _ElevationProfilePanelState();
}

class _ElevationProfilePanelState extends ConsumerState<ElevationProfilePanel> {
  late final Future<RouteProfile> _profile = RouteProfile.build(
    widget.points,
    ref.read(elevationAtProvider),
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final names =
        widget.pointNames ??
        [for (var i = 0; i < widget.points.length; i++) '${i + 1}'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
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
                  'Bu çizgi için arazi verisi yok. Yükseklik dosyaları '
                  '(≡ → Harita → Yükseklik verisi) yüklenince profil çıkar.',
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
                    'En dik çıkış ${fmtGrade(p.maxClimb)} · '
                    'en dik iniş ${fmtGrade(p.maxDescent)} · '
                    'uzunluk ${GeoMath.fmtDistance(p.length)}',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: RouteProfilePainter(
                        profile: p,
                        pointNames: names,
                        line: Theme.of(context).colorScheme.primary,
                        text: muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Renk eğimi gösterir: yeşil < %10, sarı < %20, '
                    'kırmızı daha dik.',
                    style: TextStyle(color: muted, fontSize: 11),
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
    // Çizgi parça parça, eğime göre renkli.
    RouteProfileSample? prev;
    for (final s in profile.samples) {
      final e = s.elevation;
      final p = prev;
      if (e != null && p != null) {
        final grade =
            (e - p.elevation!) /
            (s.distance - p.distance).clamp(1, double.infinity) *
            100;
        canvas.drawLine(
          at(p.distance, p.elevation!),
          at(s.distance, e),
          Paint()
            ..color = gradeColor(grade)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
      prev = e == null ? null : s;
    }

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
