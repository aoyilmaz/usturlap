import 'package:flutter/material.dart';

import '../../domain/models/map_graphic.dart';
import '../../domain/usecases/shape_edit.dart';
import '../map/engine/map_engine.dart';

/// Şekil düzenlemede haritadaki tutamaçlar: köşeler (dokun → seç), kenar
/// ortaları (+, dokun → köşe ekle) ve bütün şekli taşıma tutamacı.
/// Eldiven için 44 pt dokunma alanı.
List<MapMarker> shapeEditHandles(
  ShapeEditState s, {
  required ValueChanged<int> onVertex,
  required ValueChanged<int> onMidpoint,
  required VoidCallback onMoveAll,
  bool night = false,
}) {
  final accent = night ? Colors.redAccent : Colors.amber;
  final circle = s.type == GraphicType.circle;
  final mids = s.midpoints;
  return [
    for (var i = 0; i < mids.length; i++)
      MapMarker(
        id: 'edit:m:$i',
        imageKey: night ? 'edit:mid:n' : 'edit:mid',
        point: mids[i],
        width: 44,
        height: 44,
        onTap: () => onMidpoint(i),
        child: _Handle(
          size: 18,
          fill: Colors.black54,
          border: accent,
          icon: Icons.add,
        ),
      ),
    for (var i = 0; i < s.points.length; i++)
      MapMarker(
        id: 'edit:v:$i',
        imageKey:
            'edit:${circle && i == 0 ? 'c' : 'v'}'
            '${s.selected == i ? ':sel' : ''}${night ? ':n' : ''}',
        point: s.points[i],
        width: 44,
        height: 44,
        onTap: () => onVertex(i),
        child: _Handle(
          size: s.selected == i ? 30 : 24,
          fill: s.selected == i ? accent : Colors.white,
          border: s.selected == i ? Colors.white : accent,
          icon: circle && i == 0 ? Icons.open_with : null,
        ),
      ),
    // Dairede merkez köşesi zaten bütün şekli taşır.
    if (!circle)
      MapMarker(
        id: 'edit:all',
        imageKey:
            'edit:all${s.selected == ShapeEditState.moveAll ? ':sel' : ''}'
            '${night ? ':n' : ''}',
        point: s.center,
        width: 44,
        height: 44,
        onTap: onMoveAll,
        child: _Handle(
          size: 32,
          fill: s.selected == ShapeEditState.moveAll ? accent : Colors.black87,
          border: s.selected == ShapeEditState.moveAll ? Colors.white : accent,
          icon: Icons.open_with,
        ),
      ),
  ];
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.size,
    required this.fill,
    required this.border,
    this.icon,
  });

  final double size;
  final Color fill;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
      ),
      child: icon == null
          ? null
          : Icon(
              icon,
              size: size * 0.6,
              color: fill == Colors.white ? Colors.black : Colors.white,
            ),
    ),
  );
}

/// Şekil düzenleme çubuğu: ne yapılacağını söyler; Geri al, Köşeyi sil,
/// İptal, Kaydet.
class ShapeEditBar extends StatelessWidget {
  const ShapeEditBar({
    super.key,
    required this.state,
    required this.onUndo,
    required this.onRemove,
    required this.onCancel,
    required this.onSave,
    this.night = false,
  });

  final ShapeEditState state;
  final VoidCallback onUndo;
  final VoidCallback onRemove;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool night;

  String get _hint {
    final s = state.selected;
    final name = state.graphic.name;
    if (s == ShapeEditState.moveAll) return '$name: yeni merkezine dokun';
    if (s != null) {
      if (state.type == GraphicType.circle) {
        return s == 0
            ? '$name: yeni merkezine dokun'
            : '$name: yeni kenarına dokun (yarıçap)';
      }
      return '$name: köşe ${s + 1} — yeni yerine dokun';
    }
    return switch (state.type) {
      GraphicType.circle => '$name: merkeze ya da kenara dokun',
      GraphicType.rectangle => '$name: köşeye ya da ortadakine dokun',
      _ => '$name: köşeye, + ya da ortadakine dokun',
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = night ? Colors.redAccent : Colors.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_location_alt_outlined, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hint,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Geri al',
            icon: const Icon(Icons.undo),
            color: Colors.white,
            disabledColor: Colors.white24,
            onPressed: state.canUndo ? onUndo : null,
          ),
          if (state.type == GraphicType.line || state.type == GraphicType.area)
            IconButton(
              tooltip: 'Köşeyi sil',
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.white,
              disabledColor: Colors.white24,
              onPressed: state.canRemoveSelected ? onRemove : null,
            ),
          IconButton(
            tooltip: 'Şekil düzenlemeyi iptal et',
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onCancel,
          ),
          IconButton(
            tooltip: 'Şekli kaydet',
            icon: Icon(Icons.check, color: accent),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
