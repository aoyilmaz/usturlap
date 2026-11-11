import 'package:latlong2/latlong.dart';

import '../models/map_graphic.dart';

/// Kayıtlı bir çizimin şeklini düzenleme durumu (ATAK çizim düzenleme):
/// köşeye dokun → seçilir; sonraki dokunuş köşeyi oraya taşır. Merkez
/// tutamacı ([moveAll]) bütün şekli taşır. Değişmez: her işlem yeni durum
/// döndürür; [undo] bir önceki şekle döner.
class ShapeEditState {
  ShapeEditState(this.graphic)
    : points = List.unmodifiable(graphic.points),
      selected = null,
      _history = const [];

  const ShapeEditState._(
    this.graphic,
    this.points,
    this.selected,
    this._history,
  );

  /// Bütün şekli taşıyan tutamacın "köşe" numarası.
  static const moveAll = -1;

  final MapGraphic graphic;

  /// Düzenlenen noktalar (dairede [merkez, kenar], dikdörtgende 4 köşe).
  final List<LatLng> points;

  /// Seçili köşe (null = yok, [moveAll] = bütün şekil).
  final int? selected;

  final List<List<LatLng>> _history;

  GraphicType get type => graphic.type;

  bool get canUndo => _history.isNotEmpty;

  /// Kaydedilecek bir değişiklik var mı.
  bool get changed {
    final a = graphic.points;
    if (a.length != points.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != points[i]) return true;
    }
    return false;
  }

  /// Düzenlenen hâliyle çizim (haritada önizleme).
  MapGraphic get preview => MapGraphic(
    id: graphic.id,
    uid: graphic.uid,
    name: graphic.name,
    type: graphic.type,
    points: points,
    colorValue: graphic.colorValue,
    createdAt: graphic.createdAt,
    strokeWidth: graphic.strokeWidth,
    dashed: graphic.dashed,
    height: graphic.height,
    geofence: graphic.geofence,
  );

  /// Bütün şekli taşıma tutamacının yeri: dairede merkez, diğerlerinde
  /// köşelerin ortalaması.
  LatLng get center {
    if (type == GraphicType.circle) return points.first;
    var lat = 0.0, lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
  }

  /// Ara noktası eklenebilen kenarlar (çizgi ve alanda): [i] → [i+1].
  /// Ara tutamaç kenarın ortasında durur.
  List<LatLng> get midpoints {
    if (type != GraphicType.line && type != GraphicType.area) return const [];
    final n = type == GraphicType.area ? points.length : points.length - 1;
    return [
      for (var i = 0; i < n; i++)
        _mid(points[i], points[(i + 1) % points.length]),
    ];
  }

  /// Seçili köşe silinebilir mi (çizgide en az 2, alanda en az 3 kalır).
  bool get canRemoveSelected {
    final s = selected;
    if (s == null || s < 0) return false;
    return switch (type) {
      GraphicType.line => points.length > 2,
      GraphicType.area => points.length > 3,
      _ => false,
    };
  }

  ShapeEditState select(int? i) =>
      ShapeEditState._(graphic, points, i, _history);

  /// Seçili köşeyi (ya da bütün şekli) [p]'ye taşır; seçim biter.
  ShapeEditState moveSelectedTo(LatLng p) {
    final s = selected;
    if (s == null) return this;
    final next = s == moveAll ? _translated(p) : _vertexMoved(s, p);
    return ShapeEditState._(graphic, next, null, [..._history, points]);
  }

  /// [edge] kenarının ortasına köşe ekler ve onu seçer (sonraki dokunuş
  /// yerini verir).
  ShapeEditState insertMidpoint(int edge) {
    final mids = midpoints;
    if (edge < 0 || edge >= mids.length) return this;
    final next = [...points]..insert(edge + 1, mids[edge]);
    return ShapeEditState._(graphic, List.unmodifiable(next), edge + 1, [
      ..._history,
      points,
    ]);
  }

  ShapeEditState removeSelected() {
    if (!canRemoveSelected) return this;
    final next = [...points]..removeAt(selected!);
    return ShapeEditState._(graphic, List.unmodifiable(next), null, [
      ..._history,
      points,
    ]);
  }

  ShapeEditState undo() {
    if (_history.isEmpty) return this;
    return ShapeEditState._(
      graphic,
      _history.last,
      null,
      _history.sublist(0, _history.length - 1),
    );
  }

  List<LatLng> _vertexMoved(int i, LatLng p) {
    if (i < 0 || i >= points.length) return points;
    switch (type) {
      case GraphicType.circle:
        // Merkez taşınınca yarıçap korunur; kenar taşınınca yarıçap değişir.
        if (i == 0) {
          return List.unmodifiable([
            p,
            _geo.offset(
              p,
              _geo.distance(points[0], points[1]),
              _geo.bearing(points[0], points[1]),
            ),
          ]);
        }
        return List.unmodifiable([points[0], p]);
      case GraphicType.rectangle:
        // Karşı köşe sabit; eksenli dikdörtgen yeniden kurulur. Köşe sırası
        // ve komşuluk korunur (enlemi paylaşan komşu yine enlemi paylaşır).
        if (points.length != 4) return points;
        final o = points[(i + 2) % 4];
        final n1 = points[(i + 1) % 4], pi = points[i];
        final sameLat =
            (n1.latitude - pi.latitude).abs() <=
            (n1.longitude - pi.longitude).abs();
        final a = LatLng(p.latitude, o.longitude);
        final b = LatLng(o.latitude, p.longitude);
        final out = [...points];
        out[i] = p;
        out[(i + 1) % 4] = sameLat ? a : b;
        out[(i + 3) % 4] = sameLat ? b : a;
        return List.unmodifiable(out);
      case GraphicType.line:
      case GraphicType.area:
        return List.unmodifiable([...points]..[i] = p);
    }
  }

  /// Bütün şekil: her nokta merkezden aynı uzaklık ve kerterizle yeni
  /// merkeze göre yerleşir (şekil ve boyut korunur). Dikdörtgen enlem /
  /// boylam farkıyla kaydırılır (eksenli kalsın).
  List<LatLng> _translated(LatLng to) {
    final from = center;
    if (type == GraphicType.rectangle) {
      final dLat = to.latitude - from.latitude;
      final dLon = to.longitude - from.longitude;
      return List.unmodifiable([
        for (final q in points) LatLng(q.latitude + dLat, q.longitude + dLon),
      ]);
    }
    return List.unmodifiable([
      for (final q in points)
        q == from
            ? to
            : _geo.offset(to, _geo.distance(from, q), _geo.bearing(from, q)),
    ]);
  }

  /// Taşımada uzaklık, kerteriz ve hedef nokta aynı küre modeliyle
  /// (latlong2 kerterizi küreseldir; Vincenty uzaklıkla karışınca ~0,1°
  /// sapar) ve yuvarlamasız (GeoMath tam metreye yuvarlar): taşınan şeklin
  /// boyutu ve yönü korunur.
  static const _geo = Distance(roundResult: false, calculator: Haversine());

  static LatLng _mid(LatLng a, LatLng b) =>
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
}
