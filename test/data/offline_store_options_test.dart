import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/offline/mapbox_offline_store.dart';
import 'package:usturlap/domain/models/offline_region.dart';
import 'package:usturlap/features/map/base_layer.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Aşama H: çevrimdışı bölgede harita türleri.
void main() {
  const spec = OfflineRegionSpec(
    name: 'Tatbikat',
    south: 39.9,
    west: 32.8,
    north: 40.0,
    east: 32.9,
    maxZoom: 16,
    types: [OfflineMapType.satellite, OfflineMapType.outdoors],
  );

  test('tür başına bir stil tanımı; 3B arazi verisi bir kez', () {
    final o = MapboxOfflineStore.loadOptions(spec);
    final d = o.descriptorsOptions!;
    expect(d.map((x) => x!.styleURI), [
      MapboxStyles.SATELLITE_STREETS,
      MapboxStyles.OUTDOORS,
    ]);
    expect(d[0]!.tilesets, ['mapbox://mapbox.mapbox-terrain-dem-v1']);
    expect(d[1]!.tilesets, isNull);
    expect(d.every((x) => x!.maxZoom == 16), isTrue);
    expect(o.metadata!['styles'], ['satellite', 'outdoors']);
  });

  test('eski bölge bilgisi uydu sayılır; yeni bilgi okunur', () {
    expect(MapboxOfflineStore.typesFromMetadata(const {}), [
      OfflineMapType.satellite,
    ]);
    expect(
      MapboxOfflineStore.typesFromMetadata(const {
        'style': 'mapbox://styles/mapbox/satellite-streets-v12',
      }),
      [OfflineMapType.satellite],
    );
    expect(
      MapboxOfflineStore.typesFromMetadata(const {
        'styles': ['streets', 'bilinmeyen', 'outdoors'],
      }),
      [OfflineMapType.streets, OfflineMapType.outdoors],
    );
  });

  test('katman stili = indirilen stil (internetsizken karolar bulunsun)', () {
    expect(OfflineMapType.satellite.styleUri, MapboxStyles.SATELLITE_STREETS);
    expect(OfflineMapType.streets.styleUri, MapboxStyles.MAPBOX_STREETS);
    expect(OfflineMapType.outdoors.styleUri, MapboxStyles.OUTDOORS);
    final mapbox = [
      for (final l in kBaseLayers)
        if (l.type == BaseLayerSourceType.mapboxStyle) l,
    ];
    expect(mapbox.map((l) => l.mapType), OfflineMapType.values);
    expect(mapbox.first.id, 'online_satellite'); // kayıtlı görünümler
    final vec = kBaseLayers.firstWhere((l) => l.id == 'vec_turkiye');
    expect(vec.needsFile, isTrue);
    expect(mapbox.first.needsFile, isFalse);
  });
}
