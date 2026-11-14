import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/uuid.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/waypoint.dart';
import '../cot/cot_event.dart';
import '../cot/cot_mapper.dart';
import '../cot/cot_xml.dart';
import '../export/geo_exporter.dart';
import '../import/gpx_kml_importer.dart';
import '../import/kerteriz_data.dart';

/// Paketten alınmayan bir dosya ve nedeni (önizlemede gösterilir).
class SkippedEntry {
  const SkippedEntry(this.name, this.reason);

  final String name;
  final String reason;
}

/// ATAK uyumlu veri paketi (Mission Package v2, G8): zip içinde
/// `MANIFEST/manifest.xml` + her nesne için `<uid>/<uid>.cot` + ekler
/// (`<uid>/…jpg`; manifestte `uid` parametresi CoT'un uid'i).
///
/// Biçim kamuya açık örneklerden (TAK belgeleri, açık kaynak araçlar)
/// doğrulandı; ATAK kodu kullanılmadı.
///
/// Güvenlik (ATAK zaafları §3.3'ün tersi): paket onaysız uygulanmaz;
/// `.pref` (ayar), `.apk` ve tanınmayan dosyalar atlanır; manifestteki
/// `onReceiveAction` / `onReceiveImport` / `onReceiveDelete` yok sayılır.
class DataPackage {
  DataPackage._();

  static const manifestPath = 'MANIFEST/manifest.xml';

  /// Usturlap'a özgü ayrıntı (daire, 3B, geofence, yükseklik, koni…):
  /// CoT `<detail>` içinde JSON; ATAK tanımadığı öğeyi yok sayar.
  static const kerterizTag = '__kerteriz';

  /// R&B, halka ve izler CoT'ta yok: paket içinde KML olarak.
  static const extrasPath = 'usturlap/ekler.kml';

  static const _images = {'.jpg', '.jpeg', '.png', '.heic', '.gif'};
  static const _geoFiles = {'.kml', '.kmz', '.gpx', '.geojson', '.json'};

  static String _ext(String name) {
    final slash = name.lastIndexOf('/');
    final dot = name.lastIndexOf('.');
    return dot <= slash ? '' : name.substring(dot).toLowerCase();
  }

  static String _folder(String name) {
    final i = name.lastIndexOf('/');
    return i < 0 ? '' : name.substring(0, i);
  }

  static String _safe(String s) {
    final r = s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return r.isEmpty || r == '.' || r == '..' ? '_' : r;
  }

  // ---------------------------------------------------------------- yazma

  /// Paketi kurar. [creatorUid] / [creatorCallsign]: paketi yapan cihaz
  /// (CoT `link`). [photos]: nokta uid'i → fotoğrafları.
  static Uint8List build(
    ExportSet s, {
    required String name,
    required String creatorUid,
    required String creatorCallsign,
    Map<String, List<KmzPhoto>> photos = const {},
    String? packageUid,
  }) {
    final mapper = CotMapper(
      creatorUid: creatorUid,
      creatorCallsign: creatorCallsign,
    );
    final archive = Archive();
    final contents = <XmlElement>[];

    XmlElement param(String n, String v) => XmlElement(XmlName('Parameter'), [
      XmlAttribute(XmlName('name'), n),
      XmlAttribute(XmlName('value'), v),
    ]);
    void add(String path, List<int> bytes, Map<String, String> params) {
      archive.addFile(ArchiveFile.bytes(path, bytes));
      contents.add(
        XmlElement(
          XmlName('Content'),
          [
            XmlAttribute(XmlName('ignore'), 'false'),
            XmlAttribute(XmlName('zipEntry'), path),
          ],
          [for (final e in params.entries) param(e.key, e.value)],
        ),
      );
    }

    void addEvent(CotEvent e, String name, Map<String, Object?>? data) {
      if (data != null) {
        e.detail.children.add(
          XmlElement(XmlName(kerterizTag), [], [XmlText(jsonEncode(data))]),
        );
      }
      final folder = _safe(e.uid);
      add('$folder/$folder.cot', utf8.encode(CotXml.encode(e)), {
        'uid': e.uid,
        'name': name,
      });
    }

    for (final w in s.waypoints) {
      addEvent(mapper.fromWaypoint(w), w.name, GeoExporter.waypointData(w));
      var n = 0;
      for (final p in photos[w.uid] ?? const <KmzPhoto>[]) {
        n++;
        final file = 'foto_$n${_imageExt(p.extension)}';
        add('${_safe(w.uid)}/$file', p.bytes, {'uid': w.uid, 'name': file});
      }
    }
    for (final g in s.graphics) {
      addEvent(mapper.fromGraphic(g), g.name, GeoExporter.graphicData(g));
    }
    for (final r in s.routes) {
      addEvent(mapper.fromRoute(r), r.name, null);
    }
    final extras = ExportSet(
      rangeLines: s.rangeLines,
      rangeRings: s.rangeRings,
      tracks: s.tracks,
    );
    if (!extras.isEmpty) {
      add(
        extrasPath,
        utf8.encode(
          GeoExporter.toKml(extras, name: '$name: ölçümler ve izler'),
        ),
        {'name': 'ekler.kml'},
      );
    }

    final manifest = XmlElement(
      XmlName('MissionPackageManifest'),
      [XmlAttribute(XmlName('version'), '2')],
      [
        XmlElement(XmlName('Configuration'), [], [
          param('uid', packageUid ?? newUuidV4()),
          param('name', name),
          // Alan cihaz paketi kalıcı olarak alsın (geçici paket değil).
          param('onReceiveImport', 'true'),
          param('onReceiveDelete', 'false'),
        ]),
        XmlElement(XmlName('Contents'), [], contents),
      ],
    );
    final out = Archive()
      ..addFile(
        ArchiveFile.bytes(
          manifestPath,
          utf8.encode(manifest.toXmlString(pretty: true, indent: '  ')),
        ),
      );
    for (final f in archive.files) {
      out.addFile(f);
    }
    return ZipEncoder().encodeBytes(out);
  }

  static String _imageExt(String ext) {
    final e = ext.toLowerCase();
    return _images.contains(e) ? e : '.jpg';
  }

  // ---------------------------------------------------------------- okuma

  /// Zip bir veri paketi mi (manifest ya da .cot içeriyor).
  static bool looksLike(Iterable<ArchiveFile> entries) => entries.any(
    (f) =>
        f.name.toLowerCase() == manifestPath.toLowerCase() ||
        _ext(f.name) == '.cot',
  );

  /// Paketin içeriği. [entries]: güvenli yollu, boyutu denetlenmiş
  /// girdiler. [readGeo]: paketteki KML / GPX / GeoJSON / KMZ dosyasını
  /// okur (iç içe paket açılmaz).
  static ({
    ImportResult result,
    Map<String, Uint8List> files,
    List<SkippedEntry> skipped,
    String? name,
  })
  read(
    List<ArchiveFile> entries, {
    required ImportResult Function(Uint8List bytes) readGeo,
  }) {
    final skipped = <SkippedEntry>[];
    final byName = {for (final f in entries) f.name: f};

    // Manifest: paket adı, "yok say" işaretliler, eklerin hangi CoT'a ait
    // olduğu (Parameter uid). Komut parametreleri okunmaz.
    String? packageName;
    final ignored = <String>{};
    final owner = <String, String>{}; // zipEntry → uid
    final manifest = byName.entries
        .where((e) => e.key.toLowerCase() == manifestPath.toLowerCase())
        .map((e) => e.value)
        .firstOrNull;
    if (manifest != null) {
      try {
        final doc = XmlDocument.parse(
          utf8.decode(manifest.readBytes() ?? [], allowMalformed: true),
        );
        for (final p in doc.findAllElements('Parameter', namespace: '*')) {
          final parent = p.parentElement;
          if (parent?.name.local == 'Configuration' &&
              p.getAttribute('name') == 'name') {
            packageName = p.getAttribute('value');
          }
        }
        for (final c in doc.findAllElements('Content', namespace: '*')) {
          final entry = c.getAttribute('zipEntry');
          if (entry == null) continue;
          if (c.getAttribute('ignore') == 'true') ignored.add(entry);
          for (final p in c.findElements('Parameter', namespace: '*')) {
            if (p.getAttribute('name') == 'uid') {
              final v = p.getAttribute('value');
              if (v != null && v.isNotEmpty) owner[entry] = v;
            }
          }
        }
      } on XmlException {
        skipped.add(
          const SkippedEntry('manifest.xml', 'bozuk; dosyalar yine okundu'),
        );
      } on FormatException {
        skipped.add(
          const SkippedEntry('manifest.xml', 'bozuk; dosyalar yine okundu'),
        );
      }
    }

    final waypoints = <ImportedWaypoint>[];
    final graphics = <MapGraphic>[];
    final routes = <RoutePlan>[];
    final tracks = <ImportedTrack>[];
    final extras = <ImportResult>[];
    final files = <String, Uint8List>{};
    final mapper = CotMapper();
    // CoT uid'i → klasörü (manifestsiz paketlerde ek eşlemesi için).
    final cotFolders = <String, String>{};
    final cotUids = <String>{};

    for (final f in entries) {
      if (f.name.toLowerCase() == manifestPath.toLowerCase()) continue;
      final short = f.name.split('/').last;
      if (ignored.contains(f.name)) {
        skipped.add(SkippedEntry(short, 'pakette "yok say" işaretli'));
        continue;
      }
      final ext = _ext(f.name);
      if (ext != '.cot') continue;
      final CotEvent e;
      try {
        e = CotXml.decode(
          utf8.decode(f.readBytes() ?? [], allowMalformed: true),
        );
      } on FormatException catch (err) {
        skipped.add(SkippedEntry(short, 'bozuk CoT (${err.message})'));
        continue;
      }
      final item = mapper.toItem(e);
      final data = _kerteriz(e);
      switch (item) {
        case Waypoint w:
          waypoints.add(
            data?['kind'] == 'waypoint'
                ? KerterizData.waypoint(
                    data!,
                    name: w.name,
                    position: w.position,
                    fallbackNote: w.note,
                  )
                : ImportedWaypoint(
                    name: w.name,
                    position: w.position,
                    note: w.note,
                    uid: w.uid,
                    affiliation: w.affiliation,
                    echelon: w.echelon,
                    role: w.role,
                    cotType: w.typeCode,
                    hae: w.hae,
                  ),
          );
        case MapGraphic g:
          graphics.add(
            (data?['kind'] == 'graphic'
                    ? KerterizData.graphic(data!, name: g.name)
                    : null) ??
                g,
          );
        case RoutePlan r:
          routes.add(r);
        default:
          skipped.add(
            SkippedEntry(short, 'desteklenmeyen CoT türü: ${e.type}'),
          );
          continue;
      }
      cotUids.add(e.uid);
      cotFolders[_folder(f.name)] = e.uid;
    }

    // Ekler (fotoğraf) ve diğer dosyalar.
    final photos = <String, List<String>>{};
    for (final f in entries) {
      final lower = f.name.toLowerCase();
      if (lower == manifestPath.toLowerCase() || ignored.contains(f.name)) {
        continue;
      }
      final ext = _ext(f.name);
      final short = f.name.split('/').last;
      if (ext == '.cot') continue;
      if (_images.contains(ext)) {
        final uid = owner[f.name] ?? cotFolders[_folder(f.name)];
        if (uid == null || !cotUids.contains(uid)) {
          skipped.add(SkippedEntry(short, 'bir nesneye bağlı olmayan resim'));
          continue;
        }
        try {
          final bytes = f.readBytes();
          if (bytes == null) continue;
          files[f.name] = bytes;
          (photos[uid] ??= []).add(f.name);
        } on ArchiveException {
          skipped.add(SkippedEntry(short, 'bozuk resim'));
        }
        continue;
      }
      if (_geoFiles.contains(ext)) {
        try {
          final bytes = f.readBytes();
          if (bytes != null) extras.add(readGeo(bytes));
        } on FormatException catch (err) {
          skipped.add(SkippedEntry(short, err.message));
        }
        continue;
      }
      skipped.add(
        SkippedEntry(short, switch (ext) {
          '.pref' => 'ayar dosyası (güvenlik için uygulanmaz)',
          '.apk' => 'uygulama (yüklenmez)',
          _ => 'tanınmayan dosya',
        }),
      );
    }

    // Noktalara fotoğraflarını bağla.
    final withPhotos = [
      for (final w in waypoints)
        w.uid != null && photos.containsKey(w.uid)
            ? ImportedWaypoint(
                name: w.name,
                position: w.position,
                note: w.note,
                uid: w.uid,
                affiliation: w.affiliation,
                echelon: w.echelon,
                role: w.role,
                cotType: w.cotType,
                hae: w.hae,
                elevation: w.elevation,
                fov: w.fov,
                photos: photos[w.uid]!,
              )
            : w,
    ];

    return (
      result: ImportResult(
        [...withPhotos, for (final x in extras) ...x.waypoints],
        [...tracks, for (final x in extras) ...x.tracks],
        graphics: [...graphics, for (final x in extras) ...x.graphics],
        rangeLines: [for (final x in extras) ...x.rangeLines],
        rangeRings: [for (final x in extras) ...x.rangeRings],
        routes: [...routes, for (final x in extras) ...x.routes],
      ),
      files: files,
      skipped: skipped,
      name: packageName,
    );
  }

  /// CoT'taki Usturlap ayrıntısı (yoksa / bozuksa null).
  static Map<String, dynamic>? _kerteriz(CotEvent e) {
    final el = e.detail.getElement(kerterizTag);
    if (el == null) return null;
    try {
      final j = jsonDecode(el.innerText);
      return j is Map<String, dynamic> ? j : null;
    } on FormatException {
      return null;
    }
  }
}
