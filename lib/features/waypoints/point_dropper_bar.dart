import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/waypoint.dart';
import '../symbols/nato_symbol.dart';

/// Point Dropper türleri, paletteki sırayla.
const kDropAffiliations = [
  Affiliation.friend,
  Affiliation.hostile,
  Affiliation.neutral,
  Affiliation.unknown,
  Affiliation.waypoint,
];

/// Bırakılan noktanın ad öneki (sıra numarası eklenir: DÜŞMAN-3).
String dropPrefix(Affiliation a) => switch (a) {
  Affiliation.friend => 'DOST',
  Affiliation.hostile => 'DÜŞMAN',
  Affiliation.neutral => 'NÖTR',
  Affiliation.unknown => 'BİLİNMEYEN',
  Affiliation.waypoint => 'NOKTA',
};

/// ATAK Point Dropper (kılavuz s.9–10): tür seç, haritaya dokun, nokta
/// diyalogsuz ve sıra numaralı adla düşer. Ad sonra radyal menü → Detay →
/// Düzenle'den değiştirilir.
class PointDropperBar extends StatelessWidget {
  const PointDropperBar({
    super.key,
    required this.selected,
    required this.nextName,
    required this.onSelect,
    required this.onClose,
    this.onDropAtCrosshair,
    this.night = false,
  });

  final Affiliation selected;

  /// Bir sonraki dokunuşta verilecek ad.
  final String nextName;
  final ValueChanged<Affiliation> onSelect;
  final VoidCallback onClose;

  /// Artı imleç açıksa: imlecin altına bırak.
  final VoidCallback? onDropAtCrosshair;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final a in kDropAffiliations)
                _choice(a, selected: a == selected, accent: accent),
              const Spacer(),
              IconButton(
                tooltip: 'Nokta bırakmayı kapat',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Haritaya dokun → $nextName',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (onDropAtCrosshair != null)
                  TextButton(
                    onPressed: onDropAtCrosshair,
                    child: const Text('İmlece bırak'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(
    Affiliation a, {
    required bool selected,
    required Color accent,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: a == Affiliation.waypoint ? 'Nokta' : a.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.35) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(a);
          },
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: a == Affiliation.waypoint
                  ? const Icon(
                      Icons.location_on,
                      color: Colors.redAccent,
                      size: 32,
                    )
                  : NatoSymbol(affiliation: a, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}
