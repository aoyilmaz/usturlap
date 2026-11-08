import '../../core/hashtags.dart';
import 'map_graphic.dart';
import 'range_line.dart';
import 'range_ring.dart';
import 'waypoint.dart';

/// Haritada hangi nesnelerin görüneceği (ATAK Overlay Manager + Hashtags,
/// kılavuz s.23–24). Saf Dart; ayarlarda JSON olarak saklanır.
///
/// - [hiddenGroups]: gizli gruplar (nokta türleri `wp:<tür>`, `graphics`,
///   `rb` R&B çizgileri, `rings` menzil halkaları).
/// - [hiddenUids]: tek tek gizlenen nesneler.
/// - [tag]: doluysa yalnız bu #etiketi taşıyan noktalar/çizimler görünür.
class OverlayVisibility {
  const OverlayVisibility({
    this.hiddenGroups = const {},
    this.hiddenUids = const {},
    this.tag,
  });

  final Set<String> hiddenGroups;
  final Set<String> hiddenUids;
  final String? tag;

  static String waypointGroup(Affiliation a) => 'wp:${a.name}';
  static const graphicsGroup = 'graphics';
  static const rangeLinesGroup = 'rb';
  static const rangeRingsGroup = 'rings';

  /// Noktanın etiketleri: adında ve notunda geçen #kelimeler.
  static Set<String> tagsOfWaypoint(Waypoint w) => {
    ...extractHashtags(w.name),
    ...extractHashtags(w.note),
  };

  static Set<String> tagsOfName(String name) => extractHashtags(name);

  bool get isDefault =>
      hiddenGroups.isEmpty && hiddenUids.isEmpty && tag == null;

  bool showsWaypoint(Waypoint w) =>
      !hiddenGroups.contains(waypointGroup(w.affiliation)) &&
      !hiddenUids.contains(w.uid) &&
      (tag == null || tagsOfWaypoint(w).contains(tag));

  bool showsGraphic(MapGraphic g) =>
      !hiddenGroups.contains(graphicsGroup) &&
      !hiddenUids.contains(g.uid) &&
      (tag == null || tagsOfName(g.name).contains(tag));

  bool showsRangeLine(RangeLine l) =>
      !hiddenGroups.contains(rangeLinesGroup) &&
      !hiddenUids.contains(l.uid) &&
      (tag == null || tagsOfName(l.name).contains(tag));

  bool showsRangeRing(RangeRing r) =>
      !hiddenGroups.contains(rangeRingsGroup) &&
      !hiddenUids.contains(r.uid) &&
      (tag == null || tagsOfName(r.name).contains(tag));

  OverlayVisibility toggleGroup(String group) => _with(
    hiddenGroups: hiddenGroups.contains(group)
        ? (Set.of(hiddenGroups)..remove(group))
        : {...hiddenGroups, group},
  );

  /// [groups]'un hepsini gizle ya da hepsini göster.
  OverlayVisibility setGroups(
    Iterable<String> groups, {
    required bool hidden,
  }) => _with(
    hiddenGroups: hidden
        ? {...hiddenGroups, ...groups}
        : (Set.of(hiddenGroups)..removeAll(groups)),
  );

  OverlayVisibility toggleUid(String uid) => _with(
    hiddenUids: hiddenUids.contains(uid)
        ? (Set.of(hiddenUids)..remove(uid))
        : {...hiddenUids, uid},
  );

  OverlayVisibility withTag(String? tag) => OverlayVisibility(
    hiddenGroups: hiddenGroups,
    hiddenUids: hiddenUids,
    tag: tag,
  );

  OverlayVisibility _with({
    Set<String>? hiddenGroups,
    Set<String>? hiddenUids,
  }) => OverlayVisibility(
    hiddenGroups: hiddenGroups ?? this.hiddenGroups,
    hiddenUids: hiddenUids ?? this.hiddenUids,
    tag: tag,
  );

  Map<String, Object?> toJson() => {
    'groups': hiddenGroups.toList()..sort(),
    'uids': hiddenUids.toList()..sort(),
    'tag': ?tag,
  };

  /// Bozuk/eksik veri varsayılana döner (her şey görünür).
  factory OverlayVisibility.fromJson(Object? json) {
    if (json is! Map) return const OverlayVisibility();
    Set<String> strings(Object? v) => v is List
        ? {
            for (final e in v)
              if (e is String) e,
          }
        : const {};
    final tag = json['tag'];
    return OverlayVisibility(
      hiddenGroups: strings(json['groups']),
      hiddenUids: strings(json['uids']),
      tag: tag is String && tag.isNotEmpty ? tag : null,
    );
  }
}
