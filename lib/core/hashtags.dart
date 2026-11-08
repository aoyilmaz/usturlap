import 'tr_text.dart';

final _hashtag = RegExp(r'#([\p{L}\p{N}_-]+)', unicode: true);

/// Metindeki #etiketler (ATAK Hashtags, kılavuz s.24): `#` olmadan, Türkçe
/// küçük harfle ("#Su #KEŞİF" → {su, keşif}).
Set<String> extractHashtags(String? text) {
  if (text == null || text.isEmpty) return const {};
  return {for (final m in _hashtag.allMatches(text)) lowerTr(m.group(1)!)};
}
