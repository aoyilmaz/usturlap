import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coord_format.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/waypoint.dart';

/// Kalıcı ölçüm nesnelerinin (R&B çizgisi, menzil halkası) ortak parçaları.

/// Bağlı ya da sabit bir ucun açıklaması: "Kendi konumum (canlı)",
/// "OP-1 (bağlı)", koordinat ya da "… (nokta silinmiş)".
String anchorDescription(
  RbEnd e,
  LatLng at,
  Map<String, Waypoint> waypointsByUid,
  CoordFormatType format,
) {
  if (e.isSelf) return 'Kendi konumum (canlı)';
  final wp = waypointsByUid[e.waypointUid];
  if (wp != null) return '${wp.name} (bağlı)';
  if (e.waypointUid != null) {
    return '${CoordFormat.format(at, format)} (nokta silinmiş)';
  }
  return CoordFormat.format(at, format);
}

/// Silme onayı (eldivenle yanlış düğmeye basılabilir).
Future<bool> confirmDeleteNamed(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$name silinsin mi?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Yeni ad sorar. Vazgeçilirse, boşsa ya da değişmediyse null.
Future<String?> promptRename(BuildContext context, String current) async {
  final ctrl = TextEditingController(text: current);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Yeniden adlandır'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'İsim'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty || trimmed == current ? null : trimmed;
}

/// Detay panellerinde "etiket — değer" satırı.
class MeasureRow extends StatelessWidget {
  const MeasureRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
