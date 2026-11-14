import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pmtiles/pmtiles.dart';

import '../../data/tiles/gpkg_reader.dart';
import '../../domain/models/imported_layer.dart';
import '../map/base_layer.dart';
import '../../providers/layer_providers.dart';

const _defaultVectorStyle = 'assets/style/protomaps_light.json';

/// İçe aktarmanın sonucu: yeni katman ya da dosyası gelen yerleşik katman
/// (ör. turkey.pmtiles → "Vektör — Türkiye"; ayrı kayıt oluşmaz).
class LayerImportResult {
  const LayerImportResult.imported(ImportedLayer this.imported)
    : builtInId = null;
  const LayerImportResult.builtIn(String this.builtInId) : imported = null;

  final ImportedLayer? imported;
  final String? builtInId;
}

/// Dosyalar'dan bir .pmtiles / .mbtiles / .gpkg seçtirir, Documents'a
/// kopyalar, metadata'sını okur ve katman olarak kaydeder. İptal/hata → null.
Future<LayerImportResult?> pickAndImportLayer(
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
    final isGpkg = ext == 'gpkg';
    if (ext != 'pmtiles' && ext != 'mbtiles' && !isGpkg) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Yalnızca .pmtiles / .mbtiles / .gpkg.')));
      return null;
    }

    // Documents'a kopyala (stream — belleğe yüklenmez).
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/$name';
    if (srcPath != destPath) {
      await File(srcPath).copy(destPath);
    }

    // Yerleşik katmanın dosyası (ör. turkey.pmtiles): o katman etkinleşir.
    for (final b in kBaseLayers) {
      if (b.fileName == name) {
        messenger.showSnackBar(
            SnackBar(content: Text('${b.label} etkinleşti.')));
        return LayerImportResult.builtIn(b.id);
      }
    }

    // Metadata oku (zoom + merkez).
    int? minZoom, maxZoom;
    double? centerLat, centerLon;
    if (isGpkg) {
      // Yalnız Web Mercator raster; uymazsa kopya silinir, Türkçe hata.
      try {
        final r = GpkgReader.open(destPath);
        try {
          minZoom = r.grid.minZoom;
          maxZoom = r.grid.maxZoom;
          final b = r.grid.boundsWgs84;
          centerLat = (b[1] + b[3]) / 2;
          centerLon = (b[0] + b[2]) / 2;
        } finally {
          r.close();
        }
      } on FormatException catch (e) {
        if (srcPath != destPath) await File(destPath).delete();
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return null;
      }
    } else if (isPmtiles) {
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
      label: name.replaceAll(RegExp(r'\.(pmtiles|mbtiles|gpkg)$'), ''),
      fileName: name,
      sourceType: isGpkg ? 'gpkg' : isPmtiles ? 'pmtiles' : 'mbtiles',
      stylePath: isPmtiles ? _defaultVectorStyle : null,
      minZoom: minZoom,
      maxZoom: maxZoom,
      centerLat: centerLat,
      centerLon: centerLon,
    );
    await ref.read(importedLayerRepositoryProvider).upsert(layer);

    messenger.showSnackBar(
        SnackBar(content: Text('Harita paketi eklendi: ${layer.label}')));
    return LayerImportResult.imported(layer);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('İçe aktarma hatası: $e')));
    return null;
  }
}
