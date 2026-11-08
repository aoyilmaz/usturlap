import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/drop_kind.dart';
import '../symbols/nato_symbol.dart';

export '../../domain/models/drop_kind.dart';

/// ATAK Point Dropper (kılavuz s.9–10): tür seç, haritaya dokun, nokta
/// diyalogsuz ve sıra numaralı adla düşer. Ad sonra radyal menü → Detay →
/// Düzenle'den değiştirilir.
///
/// Türler üç sekmede: Sadakat (APP-6), Görev (nokta, GN, KN, TN, SN) ve
/// Tehlike (mayın, KBRN, bariyer). Açılışta seçili türün sekmesi görünür.
class PointDropperBar extends StatefulWidget {
  const PointDropperBar({
    super.key,
    required this.selected,
    required this.nextName,
    required this.onSelect,
    required this.onClose,
    this.onDropAtCrosshair,
    this.night = false,
  });

  final DropKind selected;

  /// Bir sonraki dokunuşta verilecek ad.
  final String nextName;
  final ValueChanged<DropKind> onSelect;
  final VoidCallback onClose;

  /// Artı imleç açıksa: imlecin altına bırak.
  final VoidCallback? onDropAtCrosshair;
  final bool night;

  @override
  State<PointDropperBar> createState() => _PointDropperBarState();
}

class _PointDropperBarState extends State<PointDropperBar> {
  late DropGroup _group = widget.selected.group;

  @override
  void didUpdateWidget(PointDropperBar old) {
    super.didUpdateWidget(old);
    // Seçim dışarıdan değiştiyse (ör. kayıtlı ayar sonradan yüklendi)
    // onun sekmesine geç.
    if (old.selected.group != widget.selected.group) {
      _group = widget.selected.group;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.night ? Colors.redAccent : Colors.amber;
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
              for (final g in DropGroup.values)
                Expanded(child: _tab(g, accent)),
              IconButton(
                tooltip: 'Nokta bırakmayı kapat',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Dar ekranda sığmazsa yana kaydırılır (sekmede en çok 6 tür).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in DropKind.inGroup(_group))
                  _choice(k, selected: k == widget.selected, accent: accent),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Haritaya dokun → ${widget.nextName}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (widget.onDropAtCrosshair != null)
                  TextButton(
                    onPressed: widget.onDropAtCrosshair,
                    child: const Text('İmlece bırak'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sekme başlığı (eldivenle dokunulabilir: 44 pt yükseklik, tam genişlik).
  Widget _tab(DropGroup g, Color accent) {
    final on = g == _group;
    return Semantics(
      button: true,
      selected: on,
      label: 'Sekme: ${g.label}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _group = g),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            g.label,
            style: TextStyle(
              color: on ? accent : Colors.white70,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(DropKind k, {required bool selected, required Color accent}) {
    return Semantics(
      button: true,
      selected: selected,
      label: k.label,
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
            widget.onSelect(k);
          },
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: PointSymbol(
                affiliation: k.affiliation,
                role: k.role,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
