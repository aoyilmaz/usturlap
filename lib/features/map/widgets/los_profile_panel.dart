import 'package:flutter/material.dart';

import '../../../domain/usecases/line_of_sight_calculator.dart';

/// Ekranın alt kısmında açılan 2D Yükseklik Profili Grafiği bileşeni.
class LosProfilePanel extends StatelessWidget {
  final LineOfSightResult result;
  final VoidCallback onClose;

  const LosProfilePanel({
    super.key,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Görüş Hattı: ${result.isVisible ? 'AÇIK (Görüş Var)' : 'KAPALI (Engel Var)'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.isVisible ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: ProfilePainter(result: result),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePainter extends CustomPainter {
  final LineOfSightResult result;

  ProfilePainter({required this.result});

  @override
  void paint(Canvas canvas, Size size) {
    if (result.profile.isEmpty) return;

    final terrainPaint = Paint()
      ..color = Colors.brown.shade300
      ..style = PaintingStyle.fill;
      
    final terrainStroke = Paint()
      ..color = Colors.brown.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final losPaint = Paint()
      ..color = result.isVisible ? Colors.green : Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double maxDist = result.profile.last.distanceMeters;
    if (maxDist <= 0) maxDist = 1;

    double maxElev = 0;
    double minElev = double.infinity;

    for (var p in result.profile) {
      if (p.elevationWithCurvature > maxElev) maxElev = p.elevationWithCurvature;
      if (p.lineOfSightHeight > maxElev) maxElev = p.lineOfSightHeight;
      if (p.elevationWithCurvature < minElev) minElev = p.elevationWithCurvature;
      if (p.lineOfSightHeight < minElev) minElev = p.lineOfSightHeight;
    }

    // Min/Max değerlerine grafiksel dolgu (padding) ekle
    maxElev += 50;
    if (minElev > 50) {
      minElev -= 50;
    } else {
      minElev = 0;
    }

    double elevRange = maxElev - minElev;
    if (elevRange <= 0) elevRange = 1;

    Path terrainPath = Path();
    terrainPath.moveTo(0, size.height);

    for (var p in result.profile) {
      double x = (p.distanceMeters / maxDist) * size.width;
      double y = size.height - ((p.elevationWithCurvature - minElev) / elevRange) * size.height;
      terrainPath.lineTo(x, y);
    }
    
    // Araziyi boya (Fill)
    Path filledTerrain = Path.from(terrainPath);
    filledTerrain.lineTo(size.width, size.height);
    filledTerrain.close();
    canvas.drawPath(filledTerrain, terrainPaint);
    
    // Arazi dış çizgisini çiz (Stroke)
    canvas.drawPath(terrainPath, terrainStroke);

    // RF/Optik Işını Çiz (Line of Sight Ray)
    double startY = size.height - ((result.profile.first.lineOfSightHeight - minElev) / elevRange) * size.height;
    double endY = size.height - ((result.profile.last.lineOfSightHeight - minElev) / elevRange) * size.height;
    canvas.drawLine(Offset(0, startY), Offset(size.width, endY), losPaint);
  }

  @override
  bool shouldRepaint(covariant ProfilePainter oldDelegate) {
    return oldDelegate.result != result;
  }
}
