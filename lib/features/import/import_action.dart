import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/import/gpx_kml_importer.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';

/// Dosyalar'dan bir GPX/KML seçtirir, waypoint + izleri drift'e ekler ve
/// sonucu SnackBar ile bildirir. İçe-aktarma butonlarının ortak eylemi.
Future<void> runGpxKmlImport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'kml'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.single;

    // iOS'ta withData bytes'ı doldurur; yedek olarak path'ten oku.
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Dosya okunamadı.')));
      return;
    }

    final parsed = GpxKmlImporter.parse(content);
    if (parsed.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('İçe aktarılacak veri bulunamadı.')));
      return;
    }

    final wpRepo = ref.read(waypointRepositoryProvider);
    for (final w in parsed.waypoints) {
      await wpRepo.add(name: w.name, position: w.position, note: w.note);
    }
    final trRepo = ref.read(trackRepositoryProvider);
    for (final t in parsed.tracks) {
      await trRepo.importTrack(t.name, t.points);
    }

    messenger.showSnackBar(SnackBar(
      content: Text('İçe aktarıldı: '
          '${parsed.waypoints.length} waypoint, ${parsed.tracks.length} iz.'),
    ));
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Geçersiz dosya: ${e.message}')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('İçe aktarma hatası: $e')));
  }
}
