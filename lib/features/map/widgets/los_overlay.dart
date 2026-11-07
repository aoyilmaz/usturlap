import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/elevation/hgt_parser.dart';
import '../../../domain/usecases/line_of_sight_calculator.dart';
import '../../../providers/tool_providers.dart';
import 'los_profile_panel.dart';

final hgtParserProvider = Provider<HgtParser>((ref) {
  final parser = HgtParser();
  // Arka planda init edilir
  parser.init();
  return parser;
});

final losCalculatorProvider = Provider<LineOfSightCalculator>((ref) {
  return LineOfSightCalculator(ref.watch(hgtParserProvider));
});

class LosOverlay extends ConsumerStatefulWidget {
  const LosOverlay({super.key});

  @override
  ConsumerState<LosOverlay> createState() => _LosOverlayState();
}

class _LosOverlayState extends ConsumerState<LosOverlay> {
  Future<LineOfSightResult>? _losFuture;

  @override
  Widget build(BuildContext context) {
    final tool = ref.watch(toolProvider);

    if (tool.mode != ToolMode.lineOfSight || tool.points.length < 2) {
      _losFuture = null;
      return const SizedBox.shrink();
    }

    if (_losFuture == null) {
      final calc = ref.read(losCalculatorProvider);
      _losFuture = calc.calculate(source: tool.points[0], target: tool.points[1]);
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FutureBuilder<LineOfSightResult>(
        future: _losFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Container(
              color: Colors.red.withValues(alpha: 0.8),
              padding: const EdgeInsets.all(16),
              child: Text('Görüş hattı hesabı hatası: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
            );
          }
          if (snapshot.hasData) {
            return LosProfilePanel(
              result: snapshot.data!,
              onClose: () {
                ref.read(toolProvider.notifier).reset();
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
