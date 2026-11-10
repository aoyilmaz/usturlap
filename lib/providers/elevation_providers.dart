import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/elevation/elevation_store.dart';
import '../data/elevation/hgt_parser.dart';

/// Çevrimdışı yükseklik okuyucusu (HGT / DTED). Görüş hattı, profil ve
/// nokta detayı kullanır.
final hgtParserProvider = Provider<HgtParser>((ref) {
  final parser = HgtParser();
  // Arka planda hazırlanır; getElevation hazırlığı bekler.
  parser.init();
  return parser;
});

/// Yükseklik dosyaları: liste, içe aktarma, silme.
final elevationStoreProvider = Provider<ElevationStore>(
  (ref) => ElevationStore(),
);

/// Cihazdaki yükseklik kareleri (uygulamayla gelen örnek dahil).
final elevationTilesProvider = FutureProvider<List<ElevationTileInfo>>(
  (ref) => ref.watch(elevationStoreProvider).list(),
);

/// Kareler değişti: okuyucu önbelleği, liste ve nokta yükseklikleri yenilensin.
void refreshElevationData(WidgetRef ref) {
  ref.read(hgtParserProvider).invalidate();
  ref.invalidate(elevationTilesProvider);
  ref.invalidate(terrainElevationProvider);
}

/// Haritada yükseklik verisi kapsamı (kare çerçeveleri) gösteriliyor mu.
class ElevationCoverageNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final showElevationCoverageProvider =
    NotifierProvider<ElevationCoverageNotifier, bool>(
      ElevationCoverageNotifier.new,
    );

/// Bir noktanın arazi yüksekliği (m, deniz seviyesinden). Veri yoksa ya
/// da okunamazsa null.
final terrainElevationProvider = FutureProvider.autoDispose
    .family<int?, LatLng>((ref, p) async {
      try {
        final v = await ref
            .watch(hgtParserProvider)
            .getElevation(p.latitude, p.longitude);
        // SRTM boşluk değeri (-32768): veri yok.
        return v == null || v < -500 ? null : v;
      } catch (_) {
        return null;
      }
    });
