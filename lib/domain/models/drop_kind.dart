import 'waypoint.dart';

/// Point Dropper paletindeki sekmeler.
enum DropGroup {
  affiliation('Sadakat'),
  mission('Görev'),
  hazard('Tehlike');

  const DropGroup(this.label);
  final String label;
}

/// Point Dropper ön ayarı: bırakılacak noktanın türü, (tehlikelerde) ana
/// ikonu ve sıra numaralı adının öneki (ör. `GN` → GN-1, GN-2…).
///
/// [id] ayarlarda saklanır. Sadakat ve görev ön ayarlarında türün adıdır;
/// böylece eski sürümün kaydettiği değer ("hostile" gibi) aynen çalışır.
class DropKind {
  const DropKind._(
    this.id,
    this.group,
    this.affiliation,
    this.prefix, {
    this.role = SymbolRole.none,
  });

  final String id;
  final DropGroup group;
  final Affiliation affiliation;
  final SymbolRole role;
  final String prefix;

  /// Ekranda görünen ad: tehlikede ikonun, diğerlerinde türün adı.
  String get label => role == SymbolRole.none ? affiliation.label : role.label;

  static const _sadakat = DropGroup.affiliation;
  static const _gorev = DropGroup.mission;
  static const _tehlike = DropGroup.hazard;

  /// Paletteki sırayla bütün ön ayarlar.
  static const all = [
    DropKind._('friend', _sadakat, Affiliation.friend, 'DOST'),
    DropKind._('assumedFriend', _sadakat, Affiliation.assumedFriend, 'V.DOST'),
    DropKind._('hostile', _sadakat, Affiliation.hostile, 'DÜŞMAN'),
    DropKind._('suspect', _sadakat, Affiliation.suspect, 'ŞÜPHELİ'),
    DropKind._('neutral', _sadakat, Affiliation.neutral, 'NÖTR'),
    DropKind._('unknown', _sadakat, Affiliation.unknown, 'BİLİNMEYEN'),
    DropKind._('waypoint', _gorev, Affiliation.waypoint, 'NOKTA'),
    DropKind._('observationPost', _gorev, Affiliation.observationPost, 'GN'),
    DropKind._('checkpoint', _gorev, Affiliation.checkpoint, 'KN'),
    DropKind._('rallyPoint', _gorev, Affiliation.rallyPoint, 'TN'),
    DropKind._('sensor', _gorev, Affiliation.sensor, 'SN'),
    // Tehlikeler düşman olarak düşer (kırmızı = tehlike); sadakat sonra
    // Detay → Düzenle'den değiştirilebilir.
    DropKind._(
      'mine',
      _tehlike,
      Affiliation.hostile,
      'MAYIN',
      role: SymbolRole.mine,
    ),
    DropKind._(
      'cbrn',
      _tehlike,
      Affiliation.hostile,
      'KBRN',
      role: SymbolRole.cbrn,
    ),
    DropKind._(
      'barrier',
      _tehlike,
      Affiliation.hostile,
      'BARİYER',
      role: SymbolRole.barrier,
    ),
  ];

  /// Varsayılan: düşman (ATAK Point Dropper'daki gibi).
  static const DropKind defaultKind = DropKind._(
    'hostile',
    _sadakat,
    Affiliation.hostile,
    'DÜŞMAN',
  );

  static DropKind byId(String? id) {
    for (final k in all) {
      if (k.id == id) return k;
    }
    return defaultKind;
  }

  static List<DropKind> inGroup(DropGroup g) => [
    for (final k in all)
      if (k.group == g) k,
  ];

  @override
  bool operator ==(Object other) => other is DropKind && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
