import 'package:latlong2/latlong.dart';

import 'cot_type.dart';
import 'map_item.dart';
import 'sensor_fov.dart';

/// Noktanın türü: sade nokta, Pusula'ya özgü görev noktaları ve APP-6 /
/// MIL-STD-2525 sadakatleri (çerçeve şekli + rengi).
///
/// Sadakat: dost = mavi dikdörtgen, düşman = kırmızı eşkenar dörtgen,
/// nötr = yeşil kare, bilinmeyen = sarı dörtyaprak. "Varsayılan dost" ve
/// "şüpheli" kesinleşmemiş kimliktir: dost / düşman çerçevesi kesik çizgiyle.
///
/// Görev noktaları (gözetleme, kontrol, toplanma, sensör) NATO sembolü
/// değildir; ATAK'ın güncel CoT kataloğunda karşılıkları olmadığı için
/// ATAK'a adıyla sade işaretçi olarak gider (bkz. `CotType.forSymbol`).
///
/// Veritabanında `.name` ile saklanır: sırayı değiştirmek güvenli, adları
/// değiştirmek değil.
enum Affiliation {
  waypoint('Nokta'),
  observationPost('Gözetleme noktası'),
  checkpoint('Kontrol noktası'),
  rallyPoint('Toplanma noktası'),
  sensor('Sensör'),
  friend('Dost'),
  assumedFriend('Varsayılan dost'),
  hostile('Düşman'),
  suspect('Şüpheli'),
  neutral('Nötr'),
  unknown('Bilinmeyen');

  const Affiliation(this.label);
  final String label;

  /// APP-6 sadakat çerçeveli NATO sembolü mü (büyüklük / ana ikon alır).
  bool get isNato => switch (this) {
    friend || assumedFriend || hostile || suspect || neutral || unknown => true,
    _ => false,
  };

  /// Pusula'ya özgü görev noktası mı.
  bool get isMission => switch (this) {
    observationPost || checkpoint || rallyPoint || sensor => true,
    _ => false,
  };

  /// Kimlik kesinleşmemiş (çerçeve kesik çizgi).
  bool get isUncertain => this == assumedFriend || this == suspect;

  static Affiliation fromName(String? name) {
    for (final a in Affiliation.values) {
      if (a.name == name) return a;
    }
    return Affiliation.waypoint;
  }
}

/// APP-6 birlik büyüklüğü (echelon) — çerçeve üstüne çizilen amplifikatör.
/// Sadeleştirilmiş set: takım(Ø) / manga(•••) / bölük(I) / tabur(II).
enum Echelon {
  none('Yok'),
  team('Takım'),
  squad('Manga'),
  company('Bölük'),
  battalion('Tabur');

  const Echelon(this.label);
  final String label;

  static Echelon fromName(String? name) {
    for (final e in Echelon.values) {
      if (e.name == name) return e;
    }
    return Echelon.none;
  }
}

/// APP-6 ana ikon — çerçeve içine çizilen sembol.
/// Birlik: piyade(✕) / zırhlı(oval) / topçu(●) / keşif(/).
/// Tehlike: mayın / KBRN / bariyer (CoT kodları `CotType`'ta).
enum SymbolRole {
  none('Yok'),
  infantry('Piyade'),
  armor('Zırhlı'),
  artillery('Topçu'),
  recon('Keşif'),
  mine('Mayın'),
  cbrn('KBRN'),
  barrier('Bariyer');

  const SymbolRole(this.label);
  final String label;

  /// Tehlike ikonu (birlik değil): büyüklük (echelon) anlamsızdır.
  bool get isHazard => this == mine || this == cbrn || this == barrier;

  static SymbolRole fromName(String? name) {
    for (final r in SymbolRole.values) {
      if (r.name == name) return r;
    }
    return SymbolRole.none;
  }
}

/// Kullanıcının haritada işaretlediği kalıcı bir nokta.
///
/// Saf Dart modeli (drift'e bağımlı değil); data katmanı drift satırlarını
/// bu modele çevirir (§4.3 katmanlama).
class Waypoint implements MapItem {
  /// Veritabanı kimliği (yalnızca bu cihazda). Henüz kaydedilmemişse null.
  final int? id;

  @override
  final String uid;

  final String name;
  final LatLng position;

  @override
  final DateTime createdAt;

  final String? note;

  /// APP-6 sadakat; varsayılan sade waypoint (kırmızı pin).
  final Affiliation affiliation;

  /// APP-6 birlik büyüklüğü (çerçeve üstü); yalnızca NATO sembollerinde çizilir.
  final Echelon echelon;

  /// APP-6 ana ikon (çerçeve içi); yalnızca NATO sembollerinde çizilir.
  final SymbolRole role;

  /// Dışarıdan (ör. ATAK'tan) gelen ham CoT tipi. Pusula'nın sembol setinde
  /// karşılığı olmayan ayrıntıyı korur (ör. `a-h-G-U-C-A-W`). null ise tip
  /// sembolden türetilir.
  final String? typeCode;

  /// Elipsoit üstü yükseklik (m) — CoT `hae`. Bilinmiyorsa null.
  final double? hae;

  /// Deniz seviyesinden yükseklik (m), kullanıcının girdiği. null ise
  /// arayüz arazi verisinden (HGT) okur.
  final double? elevation;

  /// Görüş konisi (sensör / gözetleme); yoksa null.
  final SensorFov? fov;

  const Waypoint({
    required this.uid,
    required this.name,
    required this.position,
    required this.createdAt,
    this.id,
    this.note,
    this.affiliation = Affiliation.waypoint,
    this.echelon = Echelon.none,
    this.role = SymbolRole.none,
    this.typeCode,
    this.hae,
    this.elevation,
    this.fov,
  });

  @override
  String get cotType => typeCode ?? CotType.forSymbol(affiliation, role);

  @override
  String get title => name;
}
