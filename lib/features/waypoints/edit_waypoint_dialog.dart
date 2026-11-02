import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/waypoint.dart';
import '../../providers/waypoint_providers.dart';
import '../symbols/nato_symbol.dart';
import '../symbols/symbol_modifier_fields.dart';

/// Var olan bir waypoint'i düzenler (ad / not / APP-6 sadakat).
Future<void> showEditWaypointDialog(
  BuildContext context,
  WidgetRef ref,
  Waypoint wp,
) async {
  final nameCtrl = TextEditingController(text: wp.name);
  final noteCtrl = TextEditingController(text: wp.note ?? '');
  var selected = wp.affiliation;
  var echelon = wp.echelon;
  var role = wp.role;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('İşareti düzenle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      ? wp.name
                      : nameCtrl.text.trim();
                  final isNato = selected != Affiliation.waypoint;
                  await ref.read(waypointRepositoryProvider).updateDetails(
                        wp.id!,
                        name: name,
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
