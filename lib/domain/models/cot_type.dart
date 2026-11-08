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

  // Sadakat harfi (2525: f/h/n/u + a/s/j/k/p/…). Görev noktaları ve sade
  // nokta burada yok → sade işaretçi olarak gider.
  static const _affiliationCode = {
    Affiliation.friend: 'f',
    Affiliation.assumedFriend: 'a',
    Affiliation.hostile: 'h',
    Affiliation.suspect: 's',
    Affiliation.neutral: 'n',
    Affiliation.unknown: 'u',
  };

  // Ana ikonun işlev kodu (boyut G'den sonrası). Birlikler 2525B muharebe
  // birliği altında; tehlikeler TAK CoT kataloğundan (CoTtypes.xml):
  // `a-.-G-E-X-M` Land Mines, `a-.-G-E-X-N` NBC Equipment,
  // `a-.-G-I-c-bar` Fence/Wall/Barrier.
  static const _roleCode = {
    SymbolRole.infantry: 'U-C-I',
    SymbolRole.armor: 'U-C-A',
    SymbolRole.artillery: 'U-C-F',
    SymbolRole.recon: 'U-C-R',
    SymbolRole.mine: 'E-X-M',
    SymbolRole.cbrn: 'E-X-N',
    SymbolRole.barrier: 'I-c-bar',
  };

  // Okurken aynı ikona düşen başka kodlar: KBRN tesisi (`I-R-N`, alt
  // tipleri kimyasal `-C` / biyolojik `-B`). Dikkat: `I-R-M` "maden ocağı"
  // yapısıdır, kara mayını değil.
  static const _roleAliases = {SymbolRole.cbrn: 'I-R-N'};

  /// Pusula sembolünden CoT tipi. Sade nokta ve görev noktaları →
  /// [spotMarker]. Rolsüz NATO sembolü → genel kara nesnesi (ör. `a-h-G`).
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
      'f' => Affiliation.friend,
      'a' => Affiliation.assumedFriend,
      'h' ||
      'j' ||
      'k' => Affiliation.hostile, // joker, faker: tatbikat düşmanı
      's' => Affiliation.suspect,
      'n' => Affiliation.neutral,
      _ => Affiliation.unknown, // u, p (beklemede), o (yok), x (egzersiz)…
    };
    var role = SymbolRole.none;
    // Boyuttan sonraki işlev kodu: "U-C-I" ile başlayan her alt tip piyadedir.
    if (parts.length >= 3 && parts[2] == 'G') {
      final fn = parts.skip(3).join('-');
      bool matches(String code) => fn == code || fn.startsWith('$code-');
      for (final r in SymbolRole.values) {
        final code = _roleCode[r];
        final alias = _roleAliases[r];
        if ((code != null && matches(code)) ||
            (alias != null && matches(alias))) {
          role = r;
          break;
        }
      }
    }
    return (affiliation: affiliation, role: role);
  }

  /// `a-…` (2525 atom) tipi mi.
  static bool isAtom(String type) => type.startsWith('a-');
}
