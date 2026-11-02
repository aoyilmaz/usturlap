import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// İçe aktarılan tek waypoint (GPX `wpt` / KML `Point`).
class ImportedWaypoint {
  final String name;
  final LatLng position;
  final String? note;
  const ImportedWaypoint({
    required this.name,
    required this.position,
    this.note,
  });
}

/// İçe aktarılan iz/rota (GPX `trk`/`rte` / KML `LineString`).
class ImportedTrack {
  final String name;
  final List<LatLng> points;
  const ImportedTrack({required this.name, required this.points});
}

/// Bir GPX/KML dosyasından çıkan waypoint + iz kümesi.
class ImportResult {
  final List<ImportedWaypoint> waypoints;
  final List<ImportedTrack> tracks;
  const ImportResult(this.waypoints, this.tracks);

  bool get isEmpty => waypoints.isEmpty && tracks.isEmpty;
  int get total => waypoints.length + tracks.length;
}

/// GPX ve KML metnini saf Dart ile ayrıştırır (Flutter'a bağımsız → test edilebilir).
/// v1 kapsamı: GPX `wpt`/`trk`/`rte`, KML `Placemark` (Point/LineString).
class GpxKmlImporter {
  GpxKmlImporter._();

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
        'Desteklenmeyen dosya. GPX veya KML bekleniyor.');
  }

  // ---- GPX ----

  static ImportResult _parseGpx(XmlElement root) {
    final waypoints = <ImportedWaypoint>[];
    final tracks = <ImportedTrack>[];

    // <wpt lat lon> → waypoint
    for (final w in root.findAllElements('wpt')) {
      final p = _latLonAttr(w);
      if (p == null) continue;
      waypoints.add(ImportedWaypoint(
        name: _childText(w, 'name') ?? 'WPT',
        position: p,
        note: _childText(w, 'desc') ?? _childText(w, 'cmt'),
      ));
    }

    // <trk> … <trkpt> → iz
    for (final trk in root.findAllElements('trk')) {
      final pts = [
        for (final tp in trk.findAllElements('trkpt')) ?_latLonAttr(tp),
      ];
      if (pts.isNotEmpty) {
        tracks.add(ImportedTrack(
          name: _childText(trk, 'name') ?? 'İZ',
          points: pts,
        ));
      }
    }

    // <rte> … <rtept> → rota (iz gibi içe al)
    for (final rte in root.findAllElements('rte')) {
      final pts = [
        for (final rp in rte.findAllElements('rtept')) ?_latLonAttr(rp),
      ];
      if (pts.isNotEmpty) {
        tracks.add(ImportedTrack(
          name: _childText(rte, 'name') ?? 'ROTA',
          points: pts,
        ));
      }
    }

    return ImportResult(waypoints, tracks);
  }

  // ---- KML ----

  static ImportResult _parseKml(XmlElement root) {
    final waypoints = <ImportedWaypoint>[];
    final tracks = <ImportedTrack>[];

    for (final pm in root.findAllElements('Placemark')) {
      final name = _childText(pm, 'name') ?? 'KML';
      final note = _childText(pm, 'description');

      final point = _first(pm.findAllElements('Point'));
      if (point != null) {
        final coords = _parseKmlCoords(_childText(point, 'coordinates'));
        if (coords.isNotEmpty) {
          waypoints.add(ImportedWaypoint(
              name: name, position: coords.first, note: note));
        }
        continue;
      }

      // LineString veya (gx:Track yerine) basitçe LineString
      final line = _first(pm.findAllElements('LineString'));
      if (line != null) {
        final coords = _parseKmlCoords(_childText(line, 'coordinates'));
        if (coords.isNotEmpty) {
          tracks.add(ImportedTrack(name: name, points: coords));
        }
      }
    }

    return ImportResult(waypoints, tracks);
  }

  /// KML `coordinates`: boşlukla ayrılmış `lon,lat[,ele]` üçlüleri.
  static List<LatLng> _parseKmlCoords(String? raw) {
    if (raw == null) return const [];
    final out = <LatLng>[];
    for (final tuple in raw.trim().split(RegExp(r'\s+'))) {
      final parts = tuple.split(',');
      if (parts.length < 2) continue;
      final lon = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lat != null && lon != null) out.add(LatLng(lat, lon));
    }
    return out;
  }

  // ---- ortak ----

  /// `lat`/`lon` özniteliklerinden LatLng (ikisi de geçerliyse).
  static LatLng? _latLonAttr(XmlElement e) {
    final lat = double.tryParse(e.getAttribute('lat') ?? '');
    final lon = double.tryParse(e.getAttribute('lon') ?? '');
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  /// Doğrudan alt elemanın metni (boşsa null).
  static String? _childText(XmlElement e, String name) {
    final c = _first(e.findElements(name));
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
