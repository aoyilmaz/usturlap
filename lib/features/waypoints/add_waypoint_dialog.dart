import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coord_format.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../symbols/nato_symbol.dart';
import '../symbols/symbol_modifier_fields.dart';

/// Haritaya uzun basınca açılan "waypoint / NATO sembolü ekle" diyaloğu.
/// İsim, isteğe bağlı not ve APP-6 sadakati (dost/düşman/nötr/bilinmeyen) alır.
Future<void> showAddWaypointDialog(
  BuildContext context,
  WidgetRef ref,
  LatLng point,
) async {
  final count = ref.read(waypointsProvider).value?.length ?? 0;
  final format = ref.read(coordFormatProvider);
  final nameCtrl = TextEditingController(text: 'WP-${count + 1}');
  final noteCtrl = TextEditingController();
  var selected = Affiliation.waypoint;
  var echelon = Echelon.none;
  var role = SymbolRole.none;

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
                  const SizedBox(height: 14),
                  const Text('Sadakat (APP-6)',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final a in Affiliation.values)
                        ChoiceChip(
                          avatar: a == Affiliation.waypoint
                              ? const Icon(Icons.location_on,
                                  color: Colors.redAccent, size: 18)
                              : SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      NatoSymbol(affiliation: a, size: 20)),
                          label: Text(a.label),
                          selected: selected == a,
                          onSelected: (_) => setLocal(() => selected = a),
                        ),
                    ],
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
                  final name = nameCtrl.text.trim().isEmpty
                      ? 'WP-${count + 1}'
                      : nameCtrl.text.trim();
                  // Sade waypoint'te modifier saklamayalım.
                  final isNato = selected != Affiliation.waypoint;
                  await ref.read(waypointRepositoryProvider).add(
                        name: name,
                        position: point,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        affiliation: selected,
                        echelon: isNato ? echelon : Echelon.none,
                        role: isNato ? role : SymbolRole.none,
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
