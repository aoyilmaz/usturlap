import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/sensor_fov.dart';
import '../../domain/models/waypoint.dart';
import 'kerteriz_data.dart';

/// İçe aktarılan tek waypoint (GPX `wpt` / KML `Point` / GeoJSON `Point`).
class ImportedWaypoint {
  final String name;
  final LatLng position;
  final String? note;

  /// Pusula'dan çıkmış dosyada kalıcı kimlik (aynısı varsa atlanır).
  final String? uid;
  final Affiliation affiliation;
  final Echelon echelon;
  final SymbolRole role;
  final String? cotType;
  final double? hae;
  final double? elevation;
  final SensorFov? fov;

  /// Paketteki (KMZ) fotoğraf yolları.
  final List<String> photos;

  const ImportedWaypoint({
    required this.name,
    required this.position,
    this.note,
    this.uid,
    this.affiliation = Affiliation.waypoint,
    this.echelon = Echelon.none,
    this.role = SymbolRole.none,
    this.cotType,
    this.hae,
    this.elevation,
    this.fov,
    this.photos = const [],
  });
}

/// İçe aktarılan iz/rota (GPX `trk`/`rte` / KML `LineString`, `gx:Track`).
class ImportedTrack {
  final String name;
  final List<LatLng> points;
  final String? uid;
  const ImportedTrack({required this.name, required this.points, this.uid});
}

/// Bir dosyadan çıkan nesneler.
class ImportResult {
  final List<ImportedWaypoint> waypoints;
  final List<ImportedTrack> tracks;

  /// Çizimler (KML / GeoJSON alanları; Pusula'dan çıkmışsa daire vb.).
  final List<MapGraphic> graphics;
  final List<RangeLine> rangeLines;
  final List<RangeRing> rangeRings;

  /// Rotalar (Pusula'dan çıkmış KML / GeoJSON, veri paketi CoT'u).
  final List<RoutePlan> routes;

  const ImportResult(
    this.waypoints,
    this.tracks, {
    this.graphics = const [],
    this.rangeLines = const [],
    this.rangeRings = const [],
    this.routes = const [],
  });

  bool get isEmpty => total == 0;
  int get total =>
      waypoints.length +
      tracks.length +
      graphics.length +
      rangeLines.length +
      rangeRings.length +
      routes.length;

  /// Noktalara bağlı fotoğraf sayısı.
  int get photoCount => waypoints.fold(0, (n, w) => n + w.photos.length);
}

/// GPX ve KML metnini saf Dart ile ayrıştırır (Flutter'a bağımsız → test edilebilir).
/// GPX `wpt`/`trk`/`rte`; KML `Placemark` (Point / LineString / Polygon /
/// `gx:Track` / MultiGeometry), stiller (renk, kalınlık) ve Pusula'nın
/// "kerteriz" verisi (bkz. GeoExporter).
class GpxKmlImporter {
  GpxKmlImporter._();

  /// Stili olmayan alanların rengi.
  static const defaultAreaColor = 0xFFE03131;

  /// Format dosya içeriğinden saptanır. Bozuk XML veya tanınmayan kök
  /// [FormatException] olarak yükseltilir (import_action tek noktada yakalar).
  static ImportResult parse(String content) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(content);
    } on XmlException catch (e) {
      throw FormatException('XML ayrıştırılamadı: ${e.message}');
    }
    final root = doc.rootElement;
    final tag = root.name.local.toLowerCase();
    if (tag == 'gpx') return _parseGpx(root);
    if (tag == 'kml') return _parseKml(root);
    throw const FormatException(
      'Desteklenmeyen dosya. GPX veya KML bekleniyor.',
    );
  }

  // ---- GPX ----

  static ImportResult _parseGpx(XmlElement root) {
    final waypoints = <ImportedWaypoint>[];
    final tracks = <ImportedTrack>[];

    // <wpt lat lon> → waypoint
    for (final w in root.findAllElements('wpt', namespace: '*')) {
      final p = _latLonAttr(w);
      if (p == null) continue;
      waypoints.add(
        ImportedWaypoint(
          name: _childText(w, 'name') ?? 'WPT',
          position: p,
          note: _childText(w, 'desc') ?? _childText(w, 'cmt'),
          elevation: double.tryParse(_childText(w, 'ele') ?? ''),
        ),
      );
    }

    // <trk> … <trkpt> → iz
    for (final trk in root.findAllElements('trk', namespace: '*')) {
      final pts = [
        for (final tp in trk.findAllElements('trkpt', namespace: '*'))
          ?_latLonAttr(tp),
      ];
      if (pts.isNotEmpty) {
        tracks.add(
          ImportedTrack(name: _childText(trk, 'name') ?? 'İZ', points: pts),
        );
      }
    }

    // <rte> … <rtept> → rota (iz gibi içe al)
    for (final rte in root.findAllElements('rte', namespace: '*')) {
      final pts = [
        for (final rp in rte.findAllElements('rtept', namespace: '*'))
          ?_latLonAttr(rp),
      ];
      if (pts.isNotEmpty) {
        tracks.add(
          ImportedTrack(name: _childText(rte, 'name') ?? 'ROTA', points: pts),
        );
      }
    }

    return ImportResult(waypoints, tracks);
  }

  // ---- KML ----

  static ImportResult _parseKml(XmlElement root) {
    final waypoints = <ImportedWaypoint>[];
    final tracks = <ImportedTrack>[];
    final graphics = <MapGraphic>[];
    final rangeLines = <RangeLine>[];
    final rangeRings = <RangeRing>[];
    final routes = <RoutePlan>[];
    final styles = _KmlStyles(root);

    for (final pm in _all(root, 'Placemark')) {
      final name = _childText(pm, 'name') ?? 'KML';
      final description = _childText(pm, 'description');
      final data = _kerterizData(pm);

      // Pusula'dan çıkmış nesne: ayrıntısıyla geri kurulur.
      switch (data?['kind']) {
        case 'graphic':
          final g = KerterizData.graphic(data!, name: name);
          if (g != null) {
            graphics.add(g);
            continue;
          }
        case 'rangeLine':
          final l = KerterizData.rangeLine(data!, name: name);
          if (l != null) {
            rangeLines.add(l);
            continue;
          }
        case 'rangeRing':
          final r = KerterizData.rangeRing(data!, name: name);
          if (r != null) {
            rangeRings.add(r);
            continue;
          }
        case 'route':
          final r = KerterizData.route(data!, name: name);
          if (r != null) {
            routes.add(r);
            continue;
          }
      }

      // Noktalar (MultiGeometry'de birden çok olabilir).
      for (final point in _all(pm, 'Point')) {
        final coords = _parseKmlCoords(_childText(point, 'coordinates'));
        if (coords.isEmpty) continue;
        if (data?['kind'] == 'waypoint') {
          waypoints.add(
            KerterizData.waypoint(
              data!,
              name: name,
              position: coords.first,
              fallbackNote: htmlToNote(description),
            ),
          );
        } else {
          waypoints.add(
            ImportedWaypoint(
              name: name,
              position: coords.first,
              note: htmlToNote(description),
              photos: imageSources(description),
            ),
          );
        }
      }

      final trackUid = data?['kind'] == 'track'
          ? data!['uid'] as String?
          : null;
      // Çizgiler → iz.
      for (final line in _all(pm, 'LineString')) {
        final coords = _parseKmlCoords(_childText(line, 'coordinates'));
        if (coords.isNotEmpty) {
          tracks.add(ImportedTrack(name: name, points: coords, uid: trackUid));
        }
      }
      // gx:Track → iz ("boylam enlem yükseklik").
      for (final t in _all(pm, 'Track')) {
        final coords = [
          for (final c in t.findElements('coord', namespace: '*'))
            ?_parseSpaceCoord(c.innerText),
        ];
        if (coords.isNotEmpty) {
          tracks.add(ImportedTrack(name: name, points: coords, uid: trackUid));
        }
      }
      // Alanlar → çizim (dış sınır; stil rengi ve kalınlığıyla).
      for (final poly in _all(pm, 'Polygon')) {
        final outer = _first(_all(poly, 'outerBoundaryIs'));
        final ring = outer == null ? null : _first(_all(outer, 'coordinates'));
        var coords = _parseKmlCoords(ring?.innerText);
        if (coords.length >= 2 && coords.first == coords.last) {
          coords = coords.sublist(0, coords.length - 1);
        }
        if (coords.length < 3) continue;
        final style = styles.of(pm);
        graphics.add(
          KerterizData.newGraphic(
            name: name,
            type: GraphicType.area,
            points: coords,
            colorValue: style.color ?? defaultAreaColor,
            strokeWidth: style.width,
          ),
        );
      }
    }

    return ImportResult(
      waypoints,
      tracks,
      graphics: graphics,
      rangeLines: rangeLines,
      rangeRings: rangeRings,
      routes: routes,
    );
  }

  /// Placemark'ın "kerteriz" verisi (ExtendedData/Data[name=kerteriz]).
  static Map<String, dynamic>? _kerterizData(XmlElement pm) {
    for (final d in _all(pm, 'Data')) {
      if (d.getAttribute('name') != KerterizData.key) continue;
      final v = _first(d.findElements('value', namespace: '*'))?.innerText;
      if (v == null) return null;
      try {
        final j = jsonDecode(v);
        return j is Map<String, dynamic> ? j : null;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// KML açıklamasındaki resim kaynakları (`<img src="…">`; KMZ içi yollar).
  static List<String> imageSources(String? html) {
    if (html == null) return const [];
    return [
      for (final m in RegExp(
        r'''<img[^>]*?src\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).allMatches(html))
        m.group(1)!,
    ];
  }

  /// HTML açıklamayı nota çevirir: resimler çıkar, `<br>` satır olur,
  /// diğer etiketler atılır. Boşsa null.
  static String? htmlToNote(String? html) {
    if (html == null) return null;
    final t = html
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    return t.isEmpty ? null : t;
  }

  /// KML `coordinates`: boşlukla ayrılmış `lon,lat[,ele]` üçlüleri.
  static List<LatLng> _parseKmlCoords(String? raw) {
    if (raw == null) return const [];
    final out = <LatLng>[];
    for (final tuple in raw.trim().split(RegExp(r'\s+'))) {
      final parts = tuple.split(',');
      if (parts.length < 2) continue;
      final p = KerterizData.latLng(
        double.tryParse(parts[1]),
        double.tryParse(parts[0]),
      );
      if (p != null) out.add(p);
    }
    return out;
  }

  /// `gx:coord`: "boylam enlem [yükseklik]".
  static LatLng? _parseSpaceCoord(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return KerterizData.latLng(
      double.tryParse(parts[1]),
      double.tryParse(parts[0]),
    );
  }

  // ---- ortak ----

  static Iterable<XmlElement> _all(XmlElement e, String name) =>
      e.findAllElements(name, namespace: '*');

  /// `lat`/`lon` özniteliklerinden LatLng (ikisi de geçerliyse).
  static LatLng? _latLonAttr(XmlElement e) => KerterizData.latLng(
    double.tryParse(e.getAttribute('lat') ?? ''),
    double.tryParse(e.getAttribute('lon') ?? ''),
  );

  /// Doğrudan alt elemanın metni (boşsa null).
  static String? _childText(XmlElement e, String name) {
    final c = _first(e.findElements(name, namespace: '*'));
    if (c == null) return null;
    final t = c.innerText.trim();
    return t.isEmpty ? null : t;
  }

  /// Iterable'ın ilk elemanı, yoksa null (package:collection'a bağımlı olmadan).
  static XmlElement? _first(Iterable<XmlElement> els) {
    for (final e in els) {
      return e;
    }
    return null;
  }
}

/// KML stilleri: belge düzeyindeki `Style` / `StyleMap` (normal) ve
/// Placemark içindeki satır içi stil.
class _KmlStyles {
  _KmlStyles(XmlElement root) {
    for (final s in root.findAllElements('Style', namespace: '*')) {
      final id = s.getAttribute('id');
      if (id != null) _styles[id] = s;
    }
    for (final m in root.findAllElements('StyleMap', namespace: '*')) {
      final id = m.getAttribute('id');
      if (id == null) continue;
      for (final pair in m.findElements('Pair', namespace: '*')) {
        final key = GpxKmlImporter._childText(pair, 'key');
        final url = GpxKmlImporter._childText(pair, 'styleUrl');
        if (key == 'normal' && url != null) _maps[id] = url;
      }
    }
  }

  final _styles = <String, XmlElement>{};
  final _maps = <String, String>{};

  ({int? color, double width}) of(XmlElement pm) {
    var style = GpxKmlImporter._first(pm.findElements('Style', namespace: '*'));
    if (style == null) {
      var url = GpxKmlImporter._childText(pm, 'styleUrl');
      if (url != null && url.startsWith('#')) {
        final mapped = _maps[url.substring(1)];
        if (mapped != null) url = mapped;
        if (url.startsWith('#')) style = _styles[url.substring(1)];
      }
    }
    if (style == null) {
      return (color: null, width: MapGraphic.defaultStrokeWidth);
    }
    final line = GpxKmlImporter._first(
      style.findElements('LineStyle', namespace: '*'),
    );
    final poly = GpxKmlImporter._first(
      style.findElements('PolyStyle', namespace: '*'),
    );
    final color =
        _kmlColor(
          line == null ? null : GpxKmlImporter._childText(line, 'color'),
        ) ??
        _kmlColor(
          poly == null ? null : GpxKmlImporter._childText(poly, 'color'),
        );
    final width = double.tryParse(
      line == null ? '' : GpxKmlImporter._childText(line, 'width') ?? '',
    );
    return (
      color: color,
      width: (width ?? MapGraphic.defaultStrokeWidth).clamp(1.0, 12.0),
    );
  }

  /// KML rengi (aabbggrr) → opak ARGB.
  static int? _kmlColor(String? s) {
    if (s == null) return null;
    final v = int.tryParse(s.trim(), radix: 16);
    if (v == null || s.trim().length != 8) return null;
    final b = (v >> 16) & 0xFF, g = (v >> 8) & 0xFF, r = v & 0xFF;
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }
}
