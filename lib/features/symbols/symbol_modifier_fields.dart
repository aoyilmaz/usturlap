import 'package:flutter/material.dart';

import '../../domain/models/waypoint.dart';
import 'nato_symbol.dart';

const _caption = TextStyle(fontSize: 12, color: Colors.grey);

/// Ekle / Düzenle diyaloglarında nokta türü: önce sade nokta ve görev
/// noktaları, sonra APP-6 sadakatleri.
class PointKindChips extends StatelessWidget {
  const PointKindChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Affiliation selected;
  final ValueChanged<Affiliation> onSelected;

  Widget _chips(Iterable<Affiliation> kinds) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final a in kinds)
        ChoiceChip(
          avatar: PointSymbol(affiliation: a, size: 20),
          label: Text(a.label),
          selected: selected == a,
          onSelected: (_) => onSelected(a),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text('Nokta / görev', style: _caption),
        const SizedBox(height: 6),
        _chips(Affiliation.values.where((a) => !a.isNato)),
        const SizedBox(height: 14),
        const Text('Sadakat (APP-6)', style: _caption),
        const SizedBox(height: 6),
        _chips(Affiliation.values.where((a) => a.isNato)),
      ],
    );
  }
}

/// Add/Edit waypoint diyaloglarında ortak kullanılan APP-6 modifier seçicileri:
/// echelon (büyüklük) + ana ikon (birlik ya da tehlike). Yalnızca NATO
/// sembolünde gösterilir; sade nokta ve görev noktasında [SizedBox.shrink].
/// Tehlike ikonunda büyüklük anlamsız olduğu için gizlenir.
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

  /// Kaydedilecek büyüklük: NATO dışı türde ve tehlike ikonunda yok.
  static Echelon echelonToSave(Affiliation a, Echelon e, SymbolRole r) =>
      a.isNato && !r.isHazard ? e : Echelon.none;

  /// Kaydedilecek ana ikon: NATO dışı türde yok.
  static SymbolRole roleToSave(Affiliation a, SymbolRole r) =>
      a.isNato ? r : SymbolRole.none;

  @override
  Widget build(BuildContext context) {
    if (!affiliation.isNato) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text('Ana ikon', style: _caption),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final r in SymbolRole.values)
              ChoiceChip(
                avatar: r == SymbolRole.none
                    ? null
                    : NatoSymbol(affiliation: affiliation, role: r, size: 20),
                label: Text(r.label),
                selected: role == r,
                onSelected: (_) => onRole(r),
              ),
          ],
        ),
        if (!role.isHazard) ...[
          const SizedBox(height: 14),
          const Text('Büyüklük (echelon)', style: _caption),
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
        ],
      ],
    );
  }
}
