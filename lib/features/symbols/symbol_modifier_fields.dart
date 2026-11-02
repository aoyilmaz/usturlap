import 'package:flutter/material.dart';

import '../../domain/models/waypoint.dart';

/// Add/Edit waypoint diyaloglarında ortak kullanılan APP-6 modifier seçicileri:
/// echelon (büyüklük) + rol (ana ikon). Yalnızca NATO sembolünde (sade waypoint
/// dışında) gösterilir; sade waypoint'te [SizedBox.shrink].
class SymbolModifierFields extends StatelessWidget {
  const SymbolModifierFields({
    super.key,
    required this.affiliation,
    required this.echelon,
    required this.role,
    required this.onEchelon,
    required this.onRole,
  });

  final Affiliation affiliation;
  final Echelon echelon;
  final SymbolRole role;
  final ValueChanged<Echelon> onEchelon;
  final ValueChanged<SymbolRole> onRole;

  @override
  Widget build(BuildContext context) {
    if (affiliation == Affiliation.waypoint) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text('Büyüklük (echelon)',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in Echelon.values)
              ChoiceChip(
                label: Text(e.label),
                selected: echelon == e,
                onSelected: (_) => onEchelon(e),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Ana ikon (rol)',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final r in SymbolRole.values)
              ChoiceChip(
                label: Text(r.label),
                selected: role == r,
                onSelected: (_) => onRole(r),
              ),
          ],
        ),
      ],
    );
  }
}
