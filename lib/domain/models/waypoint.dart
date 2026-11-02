import 'package:latlong2/latlong.dart';

/// APP-6 / MIL-STD-2525 sadakat (affiliation) — çerçeve şekli + rengini belirler.
/// dost = mavi dikdörtgen, düşman = kırmızı eşkenar dörtgen, nötr = yeşil kare,
/// bilinmeyen = sarı dörtyaprak. `waypoint` = sade kırmızı pin (NATO değil).
enum Affiliation {
  waypoint('Waypoint'),
  friend('Dost'),
  hostile('Düşman'),
  neutral('Nötr'),
  unknown('Bilinmeyen');

  const Affiliation(this.label);
  final String label;

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

/// APP-6 ana ikon / birlik tipi — çerçeve içine çizilen sembol.
/// piyade(✕) / zırhlı(oval) / topçu(●) / keşif(/).
enum SymbolRole {
  none('Yok'),
  infantry('Piyade'),
  armor('Zırhlı'),
  artillery('Topçu'),
  recon('Keşif');

  const SymbolRole(this.label);
  final String label;

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
class Waypoint {
  /// Veritabanı kimliği. Henüz kaydedilmemişse null.
  final int? id;
  final String name;
  final LatLng position;
  final DateTime createdAt;
  final String? note;

  /// APP-6 sadakat; varsayılan sade waypoint (kırmızı pin).
  final Affiliation affiliation;

  /// APP-6 birlik büyüklüğü (çerçeve üstü); yalnızca NATO sembollerinde çizilir.
  final Echelon echelon;

  /// APP-6 ana ikon (çerçeve içi); yalnızca NATO sembollerinde çizilir.
  final SymbolRole role;

  const Waypoint({
    required this.name,
    required this.position,
    required this.createdAt,
    this.id,
    this.note,
    this.affiliation = Affiliation.waypoint,
    this.echelon = Echelon.none,
    this.role = SymbolRole.none,
  });
}
