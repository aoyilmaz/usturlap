import 'package:latlong2/latlong.dart';

/// Bir telsiz/amatör röle (repeater) — koordinat + frekans/ton özellikleri.
/// Veri: assets/data/repeaters_tr.json (telsiz-iletisim projesinden).
class Repeater {
  final String id;
  final String name;
  final LatLng position;
  final String? band; // VHF / UHF
  final double? listenFreq; // röle çıkışı (radyoda RX) MHz
  final double? sendFreq; // röle girişi (radyoda TX) MHz
  final double? offset; // shift (MHz)
  final double? ctcss; // CTCSS tonu (Hz)
  final String? operator; // callsign
  final String? region;
  final String? type; // analog / digital
  final String? notes;

  const Repeater({
    required this.id,
    required this.name,
    required this.position,
    this.band,
    this.listenFreq,
    this.sendFreq,
    this.offset,
    this.ctcss,
    this.operator,
    this.region,
    this.type,
    this.notes,
  });

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory Repeater.fromJson(Map<String, dynamic> j) => Repeater(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Röle').toString(),
        position: LatLng(_d(j['lat']) ?? 0, _d(j['lon']) ?? 0),
        band: j['band'] as String?,
        listenFreq: _d(j['listen_freq']),
        sendFreq: _d(j['send_freq']),
        offset: _d(j['offset']),
        ctcss: _d(j['ctcss']),
        operator: j['operator'] as String?,
        region: j['region'] as String?,
        type: j['type'] as String?,
        notes: j['notes'] as String?,
      );
}
