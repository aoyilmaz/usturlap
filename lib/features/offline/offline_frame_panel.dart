import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/offline_region.dart';
import '../../providers/offline_providers.dart';
import '../map/engine/map_types.dart';
import 'offline_regions_sheet.dart' show fmtBytes;

/// Çerçeve modunda ekranın neresinin indirileceği (harita alanına göre).
/// [rightPanel] > 0 → yatay ekran: panel sağda, çerçeve solda kalan alanda.
Rect offlineFrameRect(Size size, EdgeInsets safe, {double rightPanel = 0}) {
  if (rightPanel > 0) {
    const m = 24.0;
    final left = safe.left + m;
    final top = safe.top + m;
    final right = size.width - rightPanel - m;
    final bottom = size.height - safe.bottom - m;
    return Rect.fromLTRB(
      left,
      top,
      math.max(left + 120, right),
      math.max(top + 120, bottom),
    );
  }
  const side = 24.0;
  final top = safe.top + 120;
  final bottom = safe.bottom + 300; // alt panel
  final h = math.max(120.0, size.height - top - bottom);
  return Rect.fromLTWH(side, top, size.width - 2 * side, h);
}

/// Çerçevenin dışını karartır (dokunmaları haritaya geçirir).
class OfflineFrameMask extends StatelessWidget {
  const OfflineFrameMask({super.key, required this.frame});
  final Rect frame;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _MaskPainter(frame)),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter(this.frame);
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(6)));
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.amber,
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.frame != frame;
}

/// Alt panel: ad, detay seviyesi, boyut tahmini, İndir / Vazgeç.
class OfflineFramePanel extends ConsumerStatefulWidget {
  const OfflineFramePanel({
    super.key,
    required this.defaultName,
    required this.frameBounds,
    required this.cameraTick,
    required this.onClose,
    this.sideways = false,
    this.initialTypes = const [OfflineMapType.satellite],
  });

  /// Başlangıçta seçili harita türleri (seçili katmanın türü).
  final List<OfflineMapType> initialTypes;

  /// true → yatay ekranda sağ yan panel (tam yükseklik, kaydırılabilir).
  final bool sideways;

  final String defaultName;

  /// Çerçevenin şu anki coğrafi sınırı (harita hazır değilse null).
  final Future<GeoBounds?> Function() frameBounds;

  /// Harita her hareket ettiğinde artar → tahmin yenilenir.
  final ValueListenable<int> cameraTick;

  final VoidCallback onClose;

  @override
  ConsumerState<OfflineFramePanel> createState() => _OfflineFramePanelState();
}

class _OfflineFramePanelState extends ConsumerState<OfflineFramePanel> {
  late final TextEditingController _name = TextEditingController(
    text: widget.defaultName,
  );
  OfflineDetail _detail = OfflineDetail.terrain;
  late final Set<OfflineMapType> _types = {
    ...(widget.initialTypes.isEmpty
        ? const [OfflineMapType.satellite]
        : widget.initialTypes),
  };
  GeoBounds? _bounds;
  int? _estimate;
  bool _estimating = false;
  String? _estimateError;
  Timer? _debounce;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    widget.cameraTick.addListener(_scheduleEstimate);
    _scheduleEstimate();
  }

  @override
  void dispose() {
    widget.cameraTick.removeListener(_scheduleEstimate);
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _scheduleEstimate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _estimateNow);
  }

  OfflineRegionSpec? _spec() {
    final b = _bounds;
    if (b == null) return null;
    final name = _name.text.trim();
    return OfflineRegionSpec(
      name: name.isEmpty ? widget.defaultName : name,
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
      maxZoom: _detail.maxZoom,
      // Sabit sırayla (Uydu, Sokak, Topografik).
      types: [
        for (final t in OfflineMapType.values)
          if (_types.contains(t)) t,
      ],
    );
  }

  Future<void> _estimateNow() async {
    final req = ++_req;
    final b = await widget.frameBounds();
    if (!mounted || req != _req) return;
    setState(() {
      _bounds = b;
      _estimating = b != null;
      _estimateError = null;
    });
    final spec = _spec();
    if (spec == null) return;
    try {
      final bytes = await ref.read(offlineStoreProvider).estimateBytes(spec);
      if (!mounted || req != _req) return;
      setState(() {
        _estimate = bytes;
        _estimating = false;
      });
    } catch (e) {
      if (!mounted || req != _req) return;
      setState(() {
        _estimate = null;
        _estimating = false;
        _estimateError = 'tahmin yapılamadı (ağ?)';
      });
    }
  }

  /// Yaklaşık alan (km²) — çerçeve boyutu hakkında fikir vermek için.
  static double _areaKm2(GeoBounds b) {
    const r = 6371.0;
    final lat = (b.south + b.north) / 2 * math.pi / 180;
    final h = (b.north - b.south) * math.pi / 180 * r;
    final w = (b.east - b.west) * math.pi / 180 * r * math.cos(lat);
    return (h * w).abs();
  }

  void _start() {
    final spec = _spec();
    if (spec == null) return;
    final ok = ref.read(offlineDownloadProvider.notifier).start(spec);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaten bir indirme sürüyor.')),
      );
      return;
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _bounds;
    final big = (_estimate ?? 0) > 500 * 1024 * 1024; // > 500 MB
    String estimateText;
    if (b == null) {
      estimateText = 'Harita hazırlanıyor…';
    } else if (_estimating) {
      estimateText =
          '~${_areaKm2(b).toStringAsFixed(1)} km² · boyut hesaplanıyor…';
    } else if (_estimateError != null) {
      estimateText = '~${_areaKm2(b).toStringAsFixed(1)} km² · $_estimateError';
    } else {
      estimateText =
          '~${_areaKm2(b).toStringAsFixed(1)} km² · '
          'tahmini ${_estimate == null ? '—' : fmtBytes(_estimate!)}';
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: widget.sideways
          ? const BorderRadius.horizontal(left: Radius.circular(16))
          : const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: widget.sideways,
        left: !widget.sideways,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bölge indir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Haritayı kaydırıp yakınlaştırarak alanı çerçeveye yerleştirin.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Bölge adı',
                    isDense: true,
                  ),
                  onChanged: (_) {}, // ad tahmini etkilemez
                ),
                const SizedBox(height: 10),
                const Text(
                  'Harita türü',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in OfflineMapType.values)
                      FilterChip(
                        label: Text(t.label),
                        selected: _types.contains(t),
                        // En az bir tür seçili kalır.
                        onSelected: (on) {
                          if (!on && _types.length == 1) return;
                          setState(() => on ? _types.add(t) : _types.remove(t));
                          _scheduleEstimate();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Detay',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in OfflineDetail.values)
                      ChoiceChip(
                        label: Text('${d.label} (z${d.maxZoom})'),
                        selected: _detail == d,
                        onSelected: (_) {
                          setState(() => _detail = d);
                          _scheduleEstimate();
                        },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _detail.hint,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  estimateText,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: big ? Colors.orangeAccent : null,
                  ),
                ),
                if (big)
                  const Text(
                    'Büyük alan: indirme uzun sürer. Yakınlaşarak '
                    'alanı küçültebilir ya da detayı düşürebilirsiniz.',
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onClose,
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: b == null ? null : _start,
                        icon: const Icon(Icons.download),
                        label: const Text('İndir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
