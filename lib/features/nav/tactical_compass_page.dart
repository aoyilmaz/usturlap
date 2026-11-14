import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/bearing_format.dart';
import '../../core/nav_math.dart';
import '../../domain/models/contact.dart';
import '../../providers/location_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/settings_providers.dart';

/// Kilitli kerterize göre sapma bandı: ±[onCourseDeg] içinde "DOĞRU".
const onCourseDeg = 3.0;

/// Sapmanın sözü: "DOĞRU", "SAĞA 12°", "SOLA 5°".
String deviationText(double dev) {
  if (dev.abs() <= onCourseDeg) return 'DOĞRU';
  final a = dev.abs().round();
  return dev > 0 ? 'SAĞA $a°' : 'SOLA $a°';
}

/// Taktik pusula (Usturlap / ATAK): büyük pusula gülü, kerteriz kilidi ve
/// sapma göstergesi. Telefonu yatay tut, üst kenarı hedefe çevir.
Future<void> showTacticalCompass(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const TacticalCompassPage(),
    ),
  );
}

class TacticalCompassPage extends ConsumerStatefulWidget {
  const TacticalCompassPage({super.key});

  @override
  ConsumerState<TacticalCompassPage> createState() =>
      _TacticalCompassPageState();
}

class _TacticalCompassPageState extends ConsumerState<TacticalCompassPage> {
  /// Kilitli kerteriz (coğrafi); null = kilit yok.
  double? _locked;

  /// Kilit "Git" hedefine: kerteriz yürüdükçe yeniden hesaplanır.
  bool _toTarget = false;
  bool _onCourse = false;

  double? _lockedNow(Contact? self, NavTarget? target) {
    if (_toTarget && self != null && target != null) {
      return NavMath.bearing(self.position, target.position);
    }
    return _locked;
  }

  @override
  Widget build(BuildContext context) {
    final self = ref.watch(selfContactProvider);
    final target = ref.watch(navTargetProvider);
    final fmt = ref.watch(bearingFormatterProvider);
    final night = ref.watch(nightModeProvider);
    final heading = self?.headingDeg;
    final at = self?.position ?? const LatLng(0, 0);
    final locked = _lockedNow(self, target);

    // Rotaya girince bir kez titret (eldivenle ekrana bakmadan).
    ref.listen<Contact?>(selfContactProvider, (_, next) {
      final h = next?.headingDeg;
      final l = _lockedNow(next, ref.read(navTargetProvider));
      final on =
          h != null &&
          l != null &&
          NavMath.relativeBearing(l, h).abs() <= onCourseDeg;
      if (on && !_onCourse) HapticFeedback.mediumImpact();
      _onCourse = on;
    });

    final fg = night ? Colors.redAccent : Colors.white;
    final dim = night ? Colors.red.shade900 : Colors.white38;
    final dev = heading != null && locked != null
        ? NavMath.relativeBearing(locked, heading)
        : null;
    final devColor = dev == null
        ? fg
        : dev.abs() <= onCourseDeg
        ? (night ? Colors.redAccent : Colors.lightGreenAccent)
        : dev.abs() <= 15
        ? Colors.amber
        : Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  iconSize: 32,
                  tooltip: 'Kapat',
                  icon: Icon(Icons.close, color: fg),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    'Taktik pusula · ${fmt.ref.label}',
                    style: TextStyle(color: fg, fontSize: 16),
                  ),
                ),
              ],
            ),
            Expanded(
              child: heading == null
                  ? Center(
                      child: Text(
                        'Pusula verisi yok.\nKonum izni ve pusulayı kontrol et.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fg, fontSize: 18),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        final size = math.min(c.maxWidth, c.maxHeight) - 24;
                        return Center(
                          child: SizedBox.square(
                            dimension: size,
                            child: CustomPaint(
                              painter: _RosePainter(
                                heading: heading,
                                locked: locked,
                                at: at,
                                fmt: fmt,
                                fg: fg,
                                dim: dim,
                                lockColor: devColor,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      fmt.format(heading, at),
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: size * 0.13,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Ters ${fmt.format((heading + 180) % 360, at)}',
                                      style: TextStyle(
                                        color: dim,
                                        fontSize: size * 0.05,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (locked != null && dev != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Text(
                      deviationText(dev),
                      style: TextStyle(
                        color: devColor,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _toTarget && target != null
                          ? 'Hedef ${target.label}: ${fmt.format(locked, at)}'
                          : 'Kilit: ${fmt.format(locked, at)}',
                      style: TextStyle(color: fg, fontSize: 16),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (locked == null)
                    FilledButton.icon(
                      style: _big,
                      onPressed: heading == null
                          ? null
                          : () => setState(() {
                              _locked = heading;
                              _toTarget = false;
                            }),
                      icon: const Icon(Icons.lock),
                      label: const Text('Kerterizi kilitle'),
                    )
                  else
                    FilledButton.icon(
                      style: _big,
                      onPressed: () => setState(() {
                        _locked = null;
                        _toTarget = false;
                      }),
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Kilidi aç'),
                    ),
                  OutlinedButton.icon(
                    style: _big,
                    onPressed: () => _enterBearing(fmt, at),
                    icon: const Icon(Icons.edit),
                    label: const Text('Kerteriz gir'),
                  ),
                  if (target != null && self != null)
                    OutlinedButton.icon(
                      style: _big,
                      onPressed: () => setState(() => _toTarget = true),
                      icon: const Icon(Icons.flag),
                      label: Text('Hedefe kilitle (${target.label})'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _big = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(64, 56)),
  );

  Future<void> _enterBearing(BearingFormatter fmt, LatLng at) async {
    final ctrl = TextEditingController();
    String? error;
    final unit = fmt.unit == AngleUnit.mils ? 'mil' : '°';
    final v = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          void submit() {
            final t = fmt.parseToTrue(ctrl.text, at);
            if (t == null) {
              setLocal(
                () => error = fmt.unit == AngleUnit.mils ? '0–6400' : '0–360',
              );
              return;
            }
            Navigator.of(context).pop(t);
          }

          return AlertDialog(
            title: const Text('Kerteriz gir'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Kerteriz ($unit, ${fmt.ref.label})',
                errorText: error,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(onPressed: submit, child: const Text('Kilitle')),
            ],
          );
        },
      ),
    );
    if (v != null && mounted) {
      setState(() {
        _locked = v;
        _toTarget = false;
      });
    }
  }
}

/// Pusula gülü: üstte sabit çizgi (telefonun baktığı yön), gül ters yönde
/// döner. 5°'de bir çentik, 30°'de bir etiket (seçili kuzey ve birimle);
/// kilitli kerteriz gül üstünde üçgen.
class _RosePainter extends CustomPainter {
  _RosePainter({
    required this.heading,
    required this.locked,
    required this.at,
    required this.fmt,
    required this.fg,
    required this.dim,
    required this.lockColor,
  });

  final double heading;
  final double? locked;
  final LatLng at;
  final BearingFormatter fmt;
  final Color fg;
  final Color dim;
  final Color lockColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final stroke = Paint()
      ..color = dim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r * 0.98, stroke);

    // Gülün açısı: seçili kuzeyin 0'ı. Ekranda (heading → yukarı).
    double screenAngle(double trueDeg) =>
        (trueDeg - heading) * math.pi / 180 - math.pi / 2;

    // Seçili kuzeyin 0°'si coğrafide nerede.
    final zero = NorthMath.toTrue(0, at, fmt.ref);
    for (var d = 0; d < 360; d += 5) {
      final a = screenAngle(zero + d);
      final major = d % 30 == 0;
      final inner = r * (major ? 0.82 : 0.9);
      final u = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + u * inner,
        c + u * (r * 0.98),
        Paint()
          ..color = major ? fg : dim
          ..strokeWidth = major ? 3 : 1.5,
      );
      if (major) {
        final label = switch (d) {
          0 => 'K',
          90 => 'D',
          180 => 'G',
          270 => 'B',
          // Kısa sayı (gerçek pusula gibi): derece ya da mil.
          _ =>
            fmt.unit == AngleUnit.mils ? '${(d * 6400 / 360).round()}' : '$d',
        };
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: d == 0 ? Colors.redAccent : fg,
              fontSize: r * (d % 90 == 0 ? 0.13 : 0.075),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          c + u * (r * 0.68) - Offset(tp.width / 2, tp.height / 2),
        );
        tp.dispose();
      }
    }

    // Kilitli kerteriz: gülün kenarında üçgen.
    final l = locked;
    if (l != null) {
      final a = screenAngle(l);
      final u = Offset(math.cos(a), math.sin(a));
      final side = Offset(-u.dy, u.dx);
      final tip = c + u * (r * 0.8);
      final path = ui.Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (c + u * (r * 0.98) + side * (r * 0.06)).dx,
          (c + u * (r * 0.98) + side * (r * 0.06)).dy,
        )
        ..lineTo(
          (c + u * (r * 0.98) - side * (r * 0.06)).dx,
          (c + u * (r * 0.98) - side * (r * 0.06)).dy,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = lockColor);
    }

    // Sabit çizgi (lubber line): telefonun üst kenarının baktığı yön.
    canvas.drawLine(
      c + Offset(0, -r * 1.0),
      c + Offset(0, -r * 0.78),
      Paint()
        ..color = Colors.amber
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RosePainter old) =>
      old.heading != heading ||
      old.locked != locked ||
      old.fmt.ref != fmt.ref ||
      old.fmt.unit != fmt.unit ||
      old.lockColor != lockColor ||
      old.fg != fg;
}
