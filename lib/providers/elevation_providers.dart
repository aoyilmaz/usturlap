import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/elevation/hgt_parser.dart';

/// Çevrimdışı yükseklik verisi (HGT) okuyucusu. Görüş hattı ve nokta
/// detayı kullanır.
final hgtParserProvider = Provider<HgtParser>((ref) {
  final parser = HgtParser();
  // Arka planda hazırlanır; getElevation hazırlığı bekler.
  parser.init();
  return parser;
});

/// Bir noktanın arazi yüksekliği (m, deniz seviyesinden; SRTM). Veri
/// yoksa ya da okunamazsa null.
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
