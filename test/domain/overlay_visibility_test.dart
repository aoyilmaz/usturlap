import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/models/overlay_visibility.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';

Waypoint _wp(String uid, Affiliation a, {String name = 'N', String? note}) =>
    Waypoint(
      uid: uid,
      name: name,
      position: const LatLng(37, 37),
      createdAt: DateTime(2026),
      affiliation: a,
      note: note,
    );

void main() {
  final kuyu = _wp('w1', Affiliation.waypoint, name: 'Kuyu', note: '#Su');
  final tank = _wp('w2', Affiliation.hostile, name: 'Tank #zırh');
  final graphic = MapGraphic(
    uid: 'g1',
    name: 'Hat #su',
    type: GraphicType.line,
    points: const [LatLng(37, 37), LatLng(37.1, 37.1)],
    colorValue: 0xFFFF0000,
    createdAt: DateTime(2026),
  );

  test('varsayılan: her şey görünür', () {
    const v = OverlayVisibility();
    expect(v.isDefault, isTrue);
    expect(v.showsWaypoint(kuyu), isTrue);
    expect(v.showsGraphic(graphic), isTrue);
  });

  test('grup ve tek nesne gizleme', () {
    var v = const OverlayVisibility().toggleGroup(
      OverlayVisibility.waypointGroup(Affiliation.hostile),
    );
    expect(v.showsWaypoint(tank), isFalse);
    expect(v.showsWaypoint(kuyu), isTrue);
    v = v.toggleUid('w1');
    expect(v.showsWaypoint(kuyu), isFalse);
    v = v.toggleUid('w1').toggleGroup(OverlayVisibility.graphicsGroup);
    expect(v.showsWaypoint(kuyu), isTrue);
    expect(v.showsGraphic(graphic), isFalse);
  });

  test('etiket süzgeci: ad ya da nottaki #kelime', () {
    final v = const OverlayVisibility().withTag('su');
    expect(v.showsWaypoint(kuyu), isTrue); // notta #Su
    expect(v.showsWaypoint(tank), isFalse);
    expect(v.showsGraphic(graphic), isTrue); // adda #su
    expect(v.withTag(null).showsWaypoint(tank), isTrue);
  });

  test('hepsini gizle / göster', () {
    final groups = [
      for (final a in Affiliation.values) OverlayVisibility.waypointGroup(a),
    ];
    final hidden = const OverlayVisibility().setGroups(groups, hidden: true);
    expect(hidden.showsWaypoint(kuyu), isFalse);
    expect(hidden.setGroups(groups, hidden: false).isDefault, isTrue);
  });

  test('JSON gidiş-dönüş; bozuk veri varsayılana döner', () {
    final v = const OverlayVisibility()
        .toggleGroup('graphics')
        .toggleUid('w2')
        .withTag('su');
    final back = OverlayVisibility.fromJson(v.toJson());
    expect(back.hiddenGroups, {'graphics'});
    expect(back.hiddenUids, {'w2'});
    expect(back.tag, 'su');
    expect(OverlayVisibility.fromJson('saçma').isDefault, isTrue);
    expect(
      OverlayVisibility.fromJson({
        'groups': 3,
        'uids': [1],
      }).isDefault,
      isTrue,
    );
  });
}
