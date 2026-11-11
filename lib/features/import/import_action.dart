import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/import/geo_import.dart';
import '../../data/import/import_writer.dart';
import '../../providers/graphic_providers.dart';
import '../../providers/range_line_providers.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';

/// Dosyalar'dan bir KMZ / KML / GPX / GeoJSON seçtirir, okur, önizletir
/// ve onaylanınca ekler (G7). İçe aktarma düğmelerinin ortak eylemi.
///
/// Seçici bütün dosyaları gösterir: iOS KMZ / GeoJSON'u tanımıyor
/// (file_picker tanınmayan uzantıyı seçilemez yapar); biçim içerikten
/// anlaşılır, tanınmayan dosya Türkçe hatayla reddedilir.
Future<void> runImport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final res = await FilePicker.pickFiles(
      type: FileType.any,
      // Büyük dosya belleğe alınmasın: önce boyutu denetlenir.
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.single;
    final path = file.path;
    if (path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Dosya okunamadı.')));
      return;
    }
    final f = File(path);
    if (await f.length() > GeoImport.maxFileBytes) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Dosya çok büyük (en çok 50 MB).')),
      );
      return;
    }
    final Uint8List bytes = await f.readAsBytes();
    // Büyük dosya arayüzü dondurmasın: ayrıştırma ayrı iş parçacığında.
    final bundle = await Isolate.run(() => GeoImport.parse(bytes));
    if (!context.mounted) return;
    await importBundle(context, ref, bundle, fileName: file.name);
  } on FormatException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Geçersiz dosya: ${e.message}')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('İçe aktarma hatası: $e')));
  }
}

/// Okunmuş dosyayı önizletir; onaylanınca yazar ve sonucu bildirir.
Future<ImportReport?> importBundle(
  BuildContext context,
  WidgetRef ref,
  ImportBundle bundle, {
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final r = bundle.result;
  if (r.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('İçe aktarılacak veri bulunamadı.')),
    );
    return null;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      Widget row(IconData icon, String label, int n, [String? extra]) => n == 0
          ? const SizedBox.shrink()
          : ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(label),
              trailing: Text(
                extra == null ? '$n' : '$n · $extra',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
      final photos = bundle.files.length;
      return AlertDialog(
        title: const Text('İçe aktar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$fileName (${bundle.format})',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              row(
                Icons.place_outlined,
                'Noktalar',
                r.waypoints.length,
                photos > 0 ? '$photos fotoğraf' : null,
              ),
              row(Icons.draw_outlined, 'Çizimler', r.graphics.length),
              row(Icons.timeline, 'İzler', r.tracks.length),
              row(Icons.straighten, 'R&B çizgileri', r.rangeLines.length),
              row(Icons.radar, 'Menzil halkaları', r.rangeRings.length),
              const SizedBox(height: 8),
              const Text(
                'Daha önce içe aktarılmış olanlar (aynı kimlik) atlanır.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('İçe aktar (${r.total})'),
          ),
        ],
      );
    },
  );
  if (ok != true) return null;
  final report = await ImportWriter(
    waypoints: ref.read(waypointRepositoryProvider),
    graphics: ref.read(mapGraphicRepositoryProvider),
    tracks: ref.read(trackRepositoryProvider),
    rangeLines: ref.read(rangeLineRepositoryProvider),
    rangeRings: ref.read(rangeRingRepositoryProvider),
    attachments: ref.read(attachmentRepositoryProvider),
  ).write(bundle);
  final skipped = report.skipped > 0
      ? ' (${report.skipped} tanesi zaten vardı)'
      : '';
  // Önceki sonuç şeridi beklemesin: yenisi yerine geçer.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          report.added == 0
              ? 'Yeni nesne yok$skipped.'
              : 'İçe aktarıldı: ${report.summary}$skipped.',
        ),
      ),
    );
  return report;
}
