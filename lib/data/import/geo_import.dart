import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../package/data_package.dart';
import 'geojson_importer.dart';
import 'gpx_kml_importer.dart';

/// İçe aktarılan dosyanın tamamı: nesneler + (KMZ / veri paketinde)
/// fotoğraf dosyaları + atlananlar.
class ImportBundle {
  const ImportBundle(
    this.result, {
    this.files = const {},
    this.format = '',
    this.skipped = const [],
    this.packageName,
  });

  final ImportResult result;

  /// Paketteki fotoğraflar: yol ("files/a.jpg") → içerik. Yalnız noktaların
  /// başvurduğu resimler.
  final Map<String, Uint8List> files;

  /// Saptanan biçim (Veri paketi, KMZ, KML, GPX, GeoJSON).
  final String format;

  /// Paketten alınmayan dosyalar ve nedenleri (önizlemede gösterilir).
  final List<SkippedEntry> skipped;

  /// Veri paketinin manifestteki adı.
  final String? packageName;
}

/// Dosyanın biçimini içeriğinden saptayıp okur: ATAK veri paketi (zip +
/// manifest / .cot), KMZ (zip + KML), GPX / KML (XML), GeoJSON. Dışarıdan gelen dosya: boyut ve zip sınırları denetlenir;
/// sorun [FormatException] (Türkçe) olarak yükseltilir. Saf Dart.
class GeoImport {
  GeoImport._();

  /// Dosya boyutu sınırı.
  static const maxFileBytes = 50 * 1024 * 1024;

  /// KMZ sınırları: girdi sayısı, girdi başına ve toplam açılmış boyut.
  static const maxEntries = 1000;
  static const maxEntryBytes = 30 * 1024 * 1024;
  static const maxTotalBytes = 150 * 1024 * 1024;

  static const _images = {'.jpg', '.jpeg', '.png', '.heic', '.gif'};

  /// [allowPackage]: paket içindeki dosyalar okunurken false (iç içe
  /// paket açılmaz).
  static ImportBundle parse(Uint8List bytes, {bool allowPackage = true}) {
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Dosya çok büyük (en çok 50 MB).');
    }
    // Zip imzası "PK\x03\x04".
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return _zip(bytes, allowPackage: allowPackage);
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final start = text.trimLeft();
    if (start.startsWith('{')) {
      return ImportBundle(GeoJsonImporter.parse(text), format: 'GeoJSON');
    }
    final r = GpxKmlImporter.parse(_stripBom(text));
    return ImportBundle(
      r,
      format: start.contains('<gpx') || start.contains(':gpx') ? 'GPX' : 'KML',
    );
  }

  static String _stripBom(String s) => s.startsWith('﻿') ? s.substring(1) : s;

  /// Zip içi yol güvenli mi: mutlak değil, ".." yok, ters bölü yok.
  static bool safePath(String name) {
    if (name.isEmpty || name.startsWith('/') || name.contains('\\')) {
      return false;
    }
    if (name.contains(':')) return false;
    return !name.split('/').any((s) => s == '..');
  }

  static String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot).toLowerCase();
  }

  static ImportBundle _zip(Uint8List bytes, {required bool allowPackage}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, throwOnError: true);
    } on ArchivePasswordException {
      throw const FormatException('Şifreli paket açılamaz.');
    } on Exception catch (e) {
      throw FormatException('Paket açılamadı: $e');
    }
    final entries = [
      for (final f in archive.files)
        if (f.isFile && safePath(f.name)) f,
    ];
    if (archive.files.length > maxEntries) {
      throw const FormatException('Pakette çok fazla dosya var.');
    }
    // Açmadan önce bildirilen boyutlar (açıcı da bu boyutu aşmaz).
    var total = 0;
    for (final f in entries) {
      if (f.size > maxEntryBytes) {
        throw FormatException('Paketteki bir dosya çok büyük: ${f.name}');
      }
      total += f.size;
    }
    if (total > maxTotalBytes) {
      throw const FormatException('Paket açılınca çok büyük.');
    }

    if (allowPackage && DataPackage.looksLike(entries)) {
      final p = DataPackage.read(
        entries,
        readGeo: (b) => parse(b, allowPackage: false).result,
      );
      return ImportBundle(
        p.result,
        files: p.files,
        format: 'Veri paketi',
        skipped: [
          for (final f in archive.files)
            if (f.isFile && !safePath(f.name))
              SkippedEntry(f.name, 'güvensiz yol (klasör dışı)'),
          ...p.skipped,
        ],
        packageName: p.name,
      );
    }

    // Ana belge: kökteki doc.kml, yoksa en kısa yollu .kml.
    final kmls = [
      for (final f in entries)
        if (_ext(f.name) == '.kml') f,
    ]..sort((a, b) => a.name.length.compareTo(b.name.length));
    if (kmls.isEmpty) {
      throw const FormatException('Pakette KML belgesi yok.');
    }
    final main = kmls.firstWhere(
      (f) => f.name.toLowerCase() == 'doc.kml',
      orElse: () => kmls.first,
    );
    final ImportResult result;
    try {
      result = GpxKmlImporter.parse(
        _stripBom(utf8.decode(main.readBytes() ?? [], allowMalformed: true)),
      );
    } on ArchiveException catch (e) {
      throw FormatException('Paket bozuk: ${e.message}');
    }

    // Yalnız noktaların başvurduğu resimler okunur.
    final wanted = {
      for (final w in result.waypoints)
        for (final p in w.photos) _normalize(p),
    };
    final files = <String, Uint8List>{};
    for (final f in entries) {
      final n = _normalize(f.name);
      if (!wanted.contains(n) || !_images.contains(_ext(n))) continue;
      try {
        final data = f.readBytes();
        if (data != null) files[n] = data;
      } on ArchiveException {
        // Bozuk resim atlanır; nokta yine gelir.
      }
    }
    return ImportBundle(result, files: files, format: 'KMZ');
  }

  /// KML'deki resim yolu ile zip girdisi aynı biçimde karşılaştırılsın
  /// ("./files/a.jpg" = "files/a.jpg").
  static String _normalize(String p) {
    var s = p.trim();
    try {
      s = Uri.decodeFull(s);
    } on ArgumentError {
      // Bozuk % kodlaması: olduğu gibi karşılaştırılır.
    }
    while (s.startsWith('./')) {
      s = s.substring(2);
    }
    return s;
  }

  /// Bir noktanın fotoğrafının pakette karşılığı.
  static Uint8List? photoFor(ImportBundle b, String path) =>
      b.files[_normalize(path)];
}
