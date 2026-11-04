import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pmtiles/pmtiles.dart';

import '../../domain/models/imported_layer.dart';
import '../../providers/layer_providers.dart';

const _defaultVectorStyle = 'assets/style/protomaps_light.json';

/// Dosyalar'dan bir .pmtiles/.mbtiles seçtirir, Documents'a kopyalar, metadata'sını
/// okur ve katman olarak kaydeder. Başarılıysa oluşturulan [ImportedLayer]'ı döndürür
/// (çağıran onu seçip haritada gösterebilir). İptal/hata → null.
Future<ImportedLayer?> pickAndImportLayer(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    // FileType.any: iOS seçicisi uzantıyı değil UTI'yi tanır; .pmtiles/.mbtiles
    // için sistem UTI'si olmadığından custom filtre dosyaları gri (seçilemez)
    // gösterir. Uzantı aşağıda elle doğrulanır.
    final res = await FilePicker.pickFiles(
      type: FileType.any,
      // Büyük (~GB) dosyalar → belleğe ALMA; path'ten kopyala.
      withData: false,
    );
    if (res == null || res.files.isEmpty) return null;
    final picked = res.files.single;
    final srcPath = picked.path;
    if (srcPath == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Dosya okunamadı.')));
      return null;
    }

    final name = picked.name; // ör. turkey.pmtiles
    final ext = name.split('.').last.toLowerCase();
    final isPmtiles = ext == 'pmtiles';
    if (ext != 'pmtiles' && ext != 'mbtiles') {
      messenger.showSnackBar(
          const SnackBar(content: Text('Yalnızca .pmtiles / .mbtiles.')));
      return null;
    }

    // Documents'a kopyala (stream — belleğe yüklenmez).
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/$name';
    if (srcPath != destPath) {
      await File(srcPath).copy(destPath);
    }

    // Metadata oku (zoom + merkez).
    int? minZoom, maxZoom;
    double? centerLat, centerLon;
    if (isPmtiles) {
      // Arşiv dosyadan aralık okur → büyük dosya belleğe yüklenmez.
      final a = await PmTilesArchive.from(destPath);
      try {
        minZoom = a.header.minZoom;
        maxZoom = a.header.maxZoom;
        final c = a.centerPosition;
        if (c.latitude != 0 || c.longitude != 0) {
          centerLat = c.latitude;
          centerLon = c.longitude;
        }
      } finally {
        await a.close();
      }
    } else {
      final mp = MbTiles(mbtilesPath: destPath);
      final md = mp.getMetadata();
      minZoom = md.minZoom?.round();
      maxZoom = md.maxZoom?.round();
      final c = md.defaultCenter;
      final b = md.bounds;
      if (c != null) {
        centerLat = c.latitude;
        centerLon = c.longitude;
      } else if (b != null) {
        centerLat = (b.top + b.bottom) / 2;
        centerLon = (b.left + b.right) / 2;
      }
      mp.dispose();
    }

    final layer = ImportedLayer(
      id: name, // dosya adı benzersiz kabul edilir (aynı ad → üzerine yaz)
      label: name.replaceAll(RegExp(r'\.(pmtiles|mbtiles)$'), ''),
      fileName: name,
      sourceType: isPmtiles ? 'pmtiles' : 'mbtiles',
      stylePath: isPmtiles ? _defaultVectorStyle : null,
      minZoom: minZoom,
      maxZoom: maxZoom,
      centerLat: centerLat,
      centerLon: centerLon,
    );
    await ref.read(importedLayerRepositoryProvider).upsert(layer);

    messenger.showSnackBar(
        SnackBar(content: Text('Harita paketi eklendi: ${layer.label}')));
    return layer;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('İçe aktarma hatası: $e')));
    return null;
  }
}
