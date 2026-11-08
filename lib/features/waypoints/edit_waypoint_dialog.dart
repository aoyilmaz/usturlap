import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/waypoint.dart';
import '../../providers/waypoint_providers.dart';
import '../symbols/symbol_modifier_fields.dart';

/// Var olan bir waypoint'i düzenler (ad / not / yükseklik / APP-6 sadakat).
Future<void> showEditWaypointDialog(
  BuildContext context,
  WidgetRef ref,
  Waypoint wp,
) async {
  final nameCtrl = TextEditingController(text: wp.name);
  final noteCtrl = TextEditingController(text: wp.note ?? '');
  final elevCtrl = TextEditingController(
    text: wp.elevation == null ? '' : wp.elevation!.round().toString(),
  );
  String? elevError;
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
                  TextField(
                    controller: elevCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Yükseklik (m, MSL)',
                      helperText: 'Boş bırakılırsa arazi verisinden okunur',
                      errorText: elevError,
                    ),
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
                  // Yükseklik: boş = arazi verisi; geçersizse kaydetme.
                  final elevText =
                      elevCtrl.text.trim().replaceAll(',', '.');
                  final elev =
                      elevText.isEmpty ? null : double.tryParse(elevText);
                  if (elevText.isNotEmpty &&
                      (elev == null || elev < -500 || elev > 9000)) {
                    setLocal(() =>
                        elevError = '-500 ile 9000 arasında bir sayı girin');
                    return;
                  }
                  final repo = ref.read(waypointRepositoryProvider);
                  final name = nameCtrl.text.trim().isEmpty
                      ? wp.name
                      : nameCtrl.text.trim();
                  await repo.updateDetails(
                        wp.id!,
                        name: name,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        affiliation: selected,
                        echelon: SymbolModifierFields.echelonToSave(
                          selected, echelon, role),
                        role: SymbolModifierFields.roleToSave(selected, role),
                      );
                  await repo.setElevation(wp.id!, elev);
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
