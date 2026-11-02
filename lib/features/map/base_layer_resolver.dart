import 'dart:io';

import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../data/tiles/mbtiles_asset_loader.dart';
import 'base_layer.dart';
import 'engine/map_types.dart';

/// Bir katman tanımını (BaseLayerDef) çizilmeye hazır hale getirmenin sonucu.
sealed class BaseLayerResolution {
  const BaseLayerResolution();
}

class BaseLayerReady extends BaseLayerResolution {
  const BaseLayerReady(this.layer, {this.bounds});

  final ResolvedBaseLayer layer;

  /// Katmanın kapsadığı alan (biliniyorsa) — seçilince oraya gitmek için.
  final GeoBounds? bounds;
}

/// Katmanın dosyası cihazın Documents dizininde yok (kopyalanmamış).
class BaseLayerFileMissing extends BaseLayerResolution {
  const BaseLayerFileMissing(this.fileName);
  final String fileName;
}

/// Katman tanımı → dosya yolu / adres + kapsama alanı. Motordan bağımsızdır;
/// sağlayıcıları (karo okuyucuları) açmak motorun işidir.
class BaseLayerResolver {
  const BaseLayerResolver();

  static const _osmAttribution = '© OpenStreetMap katkıda bulunanlar';

  /// İnternet katmanları anında çözülür (dosya yok). Dosya tabanlı katman
  /// ya da kullanılamayan katman için null döner → [resolveFile] kullanın.
  ResolvedBaseLayer? resolveOnline(BaseLayerDef def) {
    switch (def.type) {
      case BaseLayerSourceType.onlineSatellite:
        if (AppConstants.mapboxAccessToken.isEmpty) return null;
        // 512px @2x karolar: zoomOffset -1 ile ekrandaki ölçek 256px karolarla
        // aynı kalır ama piksel yoğunluğu 4 kat → retina ekranda keskin.
        return RasterUrlBaseLayer(
          id: def.id,
          urlTemplate: AppConstants.mapboxSatelliteStreetsUrl,
          additionalOptions: const {
            'accessToken': AppConstants.mapboxAccessToken,
          },
          tileDimension: 512,
          zoomOffset: -1,
          maxNativeZoom: def.maxNativeZoom ?? 22,
          attribution: '© Mapbox © OpenStreetMap',
        );
      case BaseLayerSourceType.onlineOsm:
        return RasterUrlBaseLayer(
          id: def.id,
          urlTemplate: AppConstants.osmTileUrl,
          maxNativeZoom: def.maxNativeZoom ?? 19,
          attribution: _osmAttribution,
        );
      case BaseLayerSourceType.onlineTopo:
        return RasterUrlBaseLayer(
          id: def.id,
          urlTemplate: AppConstants.openTopoMapUrl,
          maxNativeZoom: def.maxNativeZoom ?? 17,
          attribution: '$_osmAttribution · © OpenTopoMap (CC-BY-SA)',
        );
      case BaseLayerSourceType.offlineMbtiles:
      case BaseLayerSourceType.vectorPmtiles:
      case BaseLayerSourceType.missing:
        return null;
    }
  }

  /// Dosya tabanlı katmanı çözer: gömülü asset → geçici kopya; içe aktarılmış
  /// / büyük katman → Documents'taki dosya. MBTiles ise kapsama alanını okur.
  Future<BaseLayerResolution> resolveFile(BaseLayerDef def) async {
    final isMbtiles = def.type == BaseLayerSourceType.offlineMbtiles;
    final isVector = def.type == BaseLayerSourceType.vectorPmtiles;
    if (!isMbtiles && !isVector) {
      throw ArgumentError.value(def.type, 'def.type', 'dosya tabanlı değil');
    }

    final String path;
    if (def.fileName != null && (isVector || def.assetPath == null)) {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/${def.fileName}';
      if (!await File(path).exists()) return BaseLayerFileMissing(def.fileName!);
    } else {
      path = await MbtilesAssetLoader.ensureLocalCopy(def.assetPath!);
    }

    if (isVector) {
      return BaseLayerReady(PmtilesBaseLayer(
        id: def.id,
        path: path,
        stylePath: def.stylePath!,
        attribution: _osmAttribution,
      ));
    }

    GeoBounds? bounds;
    MbTiles? db;
    try {
      db = MbTiles(mbtilesPath: path);
      final b = db.getMetadata().bounds;
      if (b != null) {
        bounds =
            GeoBounds(south: b.bottom, west: b.left, north: b.top, east: b.right);
      }
    } catch (_) {
      // metadata eksikse yok say
    } finally {
      db?.dispose();
    }
    return BaseLayerReady(
      MbtilesBaseLayer(
        id: def.id,
        path: path,
        maxNativeZoom: def.maxNativeZoom ?? 19,
        attribution: _osmAttribution,
      ),
      bounds: bounds,
    );
  }
}
