import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coord_format.dart';
import '../../core/sequential_name.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../symbols/symbol_modifier_fields.dart';

/// Haritaya uzun basınca açılan "işaret ekle" diyaloğu. İsim, isteğe bağlı
/// not ve tür alır: sade nokta, görev noktası ya da APP-6 sadakati.
Future<void> showAddWaypointDialog(
  BuildContext context,
  WidgetRef ref,
  LatLng point,
) async {
  final format = ref.read(coordFormatProvider);
  // Point Dropper'daki gibi Türkçe sıra numaralı ad: NOKTA-1, NOKTA-2…
  final defaultName = nextSequentialName('NOKTA', [
    for (final w in ref.read(waypointsProvider).value ?? const <Waypoint>[])
      w.name,
  ]);
  final nameCtrl = TextEditingController(text: defaultName);
  final noteCtrl = TextEditingController();
  var selected = Affiliation.waypoint;
  var echelon = Echelon.none;
  var role = SymbolRole.none;
  var saving = false; // çift dokunuş iki nokta eklemesin

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('İşaret ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(CoordFormat.format(point, format),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(CoordFormat.wgs84(point),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'İsim'),
                  ),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Not (isteğe bağlı)'),
                  ),
                  PointKindChips(
                    selected: selected,
                    onSelected: (a) => setLocal(() => selected = a),
                  ),
                  SymbolModifierFields(
                    affiliation: selected,
                    echelon: echelon,
                    role: role,
                    onEchelon: (e) => setLocal(() => echelon = e),
                    onRole: (r) => setLocal(() => role = r),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () async {
                  if (saving) return;
                  saving = true;
                  final name = nameCtrl.text.trim().isEmpty
                      ? defaultName
                      : nameCtrl.text.trim();
                  await ref.read(waypointRepositoryProvider).add(
                        name: name,
                        position: point,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        affiliation: selected,
                        echelon: SymbolModifierFields.echelonToSave(
                          selected, echelon, role),
                        role: SymbolModifierFields.roleToSave(selected, role),
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
    },
  );
}
