import 'waypoint.dart';

/// CoT (Cursor on Target) tip kodları — ATAK'ın nesne sınıflandırması.
///
/// `a-…` atomlar (birlik/nesne, MIL-STD-2525 tabanlı): `a-<sadakat>-<boyut>-<işlev>`
/// ör. `a-f-G-U-C-I` = dost (f) kara (G) birliği (U), muharebe (C), piyade (I).
/// `b-m-p-…` harita noktaları, `b-m-r` rota, `u-d-f` serbest çizim.
/// Kaynak: ATAK-CIV takcot örnekleri ve MIL-STD-2525B işlev kodları.
class CotType {
  CotType._();

  /// Sade işaretçi ("spot marker"), ATAK'ta renkli nokta.
  static const spotMarker = 'b-m-p-s-m';

  /// Rota kontrol noktası (adlı) / ara noktası (adsız).
  static const routeWaypoint = 'b-m-p-w';
  static const routeControlPoint = 'b-m-p-c';

  /// Rota.
  static const route = 'b-m-r';

  /// Serbest çizim: çizgi ya da (ilk = son nokta) kapalı alan.
  static const freeform = 'u-d-f';

  // Sadakat harfi (2525: f/h/n/u + a/s/j/k/p/…).
  static const _affiliationCode = {
    Affiliation.friend: 'f',
    Affiliation.hostile: 'h',
    Affiliation.neutral: 'n',
    Affiliation.unknown: 'u',
  };

  // Kara birliği işlev kodları (2525B): muharebe birliği altında.
  static const _roleCode = {
    SymbolRole.infantry: 'U-C-I',
    SymbolRole.armor: 'U-C-A',
    SymbolRole.artillery: 'U-C-F',
    SymbolRole.recon: 'U-C-R',
  };

  /// Pusula sembolünden CoT tipi. Sade waypoint → [spotMarker].
  /// Rolsüz NATO sembolü → genel kara nesnesi (ör. `a-h-G`).
  static String forSymbol(Affiliation affiliation, SymbolRole role) {
    final a = _affiliationCode[affiliation];
    if (a == null) return spotMarker;
    final fn = _roleCode[role];
    return fn == null ? 'a-$a-G' : 'a-$a-G-$fn';
  }

  /// CoT tipinden Pusula sembolü (en yakın karşılık). Bilinmeyen işlev
  /// kodlarında yalnızca sadakat çerçevesi kullanılır; ham tip ayrıca saklanır.
  static ({Affiliation affiliation, SymbolRole role}) parse(String type) {
    final parts = type.split('-');
    if (parts.length < 2 || parts[0] != 'a') {
      return (affiliation: Affiliation.waypoint, role: SymbolRole.none);
    }
    final affiliation = switch (parts[1]) {
      'f' || 'a' => Affiliation.friend, // a = varsayılan dost
      'h' || 's' || 'j' || 'k' => Affiliation.hostile, // şüpheli, joker, faker
      'n' => Affiliation.neutral,
      _ => Affiliation.unknown, // u, p (beklemede), o (yok), x (egzersiz)…
    };
    var role = SymbolRole.none;
    // Boyuttan sonraki işlev kodu: "U-C-I" ile başlayan her alt tip piyadedir.
    if (parts.length >= 3 && parts[2] == 'G') {
      final fn = parts.skip(3).join('-');
      for (final e in _roleCode.entries) {
        if (fn == e.value || fn.startsWith('${e.value}-')) {
          role = e.key;
          break;
        }
      }
    }
    return (affiliation: affiliation, role: role);
  }

  /// `a-…` (2525 atom) tipi mi.
  static bool isAtom(String type) => type.startsWith('a-');
}
