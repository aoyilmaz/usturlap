import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo_math.dart';
import '../engine/map_types.dart';

/// Kendi konumun etrafında pusula gülü (ATAK self-marker, kılavuz s.8).
/// Harita katmanı olarak çizilir: haritayla birlikte döner ve kayar.
/// 10°'de bir çentik (30°'de uzun, ana yönlerde en uzun), kuzey kırmızı,
/// N/E/S/W harfleri.
List<MapOverlay> compassRoseOverlays(
  LatLng center,
  double radiusMeters, {
  bool night = false,
}) {
  final base = night ? Colors.red.shade200 : Colors.white;
  final north = night ? Colors.redAccent : Colors.red;
  final out = <MapOverlay>[
    MapCircle(
      center: center,
      radiusMeters: radiusMeters,
      fillColor: Colors.transparent,
      strokeColor: base.withValues(alpha: 0.75),
      strokeWidth: 1.5,
    ),
  ];
  for (var deg = 0; deg < 360; deg += 10) {
    final inner = deg % 90 == 0
        ? 0.72
        : deg % 30 == 0
        ? 0.82
        : 0.9;
    out.add(
      MapLine(
        points: [
          GeoMath.destination(center, radiusMeters * inner, deg.toDouble()),
          GeoMath.destination(center, radiusMeters, deg.toDouble()),
        ],
        width: deg % 90 == 0 ? 3 : 1.5,
        color: deg == 0 ? north : base.withValues(alpha: 0.85),
      ),
    );
  }
  const letters = {'N': 0.0, 'E': 90.0, 'S': 180.0, 'W': 270.0};
  for (final MapEntry(key: letter, value: deg) in letters.entries) {
    final color = deg == 0 ? north : base;
    out.add(
      MapMarker(
        id: 'rose:$letter',
        imageKey: 'rose:$letter:${night ? 'n' : 'd'}',
        point: GeoMath.destination(center, radiusMeters * 1.18, deg),
        width: 22,
        height: 22,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
  return out;
}

/// Ekranda yaklaşık [pixels] büyüklüğünde görünen yarıçap (metre).
/// Mapbox 512 px karo kullanır: m/px = çevre · cos(enlem) / (512 · 2^zoom).
double roseRadiusMeters(double zoom, double latitude, {double pixels = 110}) {
  const earthCircumference = 40075016.686;
  final mpp =
      earthCircumference *
      math.cos(latitude * math.pi / 180) /
      (512 * math.pow(2, zoom));
  return pixels * mpp;
}
