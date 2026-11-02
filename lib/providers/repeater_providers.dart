import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/repeater.dart';

/// Gömülü telsiz röle verisini (Türkiye) yükler. assets/data/repeaters_tr.json
/// → üst yapı {version, updated, source, relays:[...]}.
final repeatersProvider = FutureProvider<List<Repeater>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/repeaters_tr.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final relays = (json['relays'] as List).cast<Map<String, dynamic>>();
  return relays.map(Repeater.fromJson).toList();
});

/// Band filtresi: null = tümü, ya da 'VHF' / 'UHF'.
class RepeaterBandNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? band) => state = band;
}

final repeaterBandProvider =
    NotifierProvider<RepeaterBandNotifier, String?>(RepeaterBandNotifier.new);

/// Kapsama halkası için seçili röle (tek). null = halka yok.
class SelectedRepeaterNotifier extends Notifier<Repeater?> {
  @override
  Repeater? build() => null;
  void select(Repeater? r) => state = r;
}

final selectedRepeaterProvider =
    NotifierProvider<SelectedRepeaterNotifier, Repeater?>(
        SelectedRepeaterNotifier.new);
