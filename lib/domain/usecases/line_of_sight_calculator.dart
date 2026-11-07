import 'package:latlong2/latlong.dart';

import '../../data/elevation/hgt_parser.dart';

/// Arazi profilindeki tek bir noktayı temsil eder.
class ProfilePoint {
  final LatLng coordinate;
  final double distanceMeters;
  final double elevation; // HGT'den okunan ham yükseklik
  final double elevationWithCurvature; // Dünya eğriliği eklenmiş göreceli yükseklik
  final double lineOfSightHeight; // İki anten arasına çizilen düz sanal çizginin (ışının) o noktadaki yüksekliği
  final bool hasLineOfSight; // Işın yer şeklinin üstünden mi geçiyor? (Engel var mı)

  ProfilePoint({
    required this.coordinate,
    required this.distanceMeters,
    required this.elevation,
    required this.elevationWithCurvature,
    required this.lineOfSightHeight,
    required this.hasLineOfSight,
  });
}

/// Görüş hattı analiz sonucunu tutar.
class LineOfSightResult {
  final bool isVisible; // Uçtan uca görüş var mı?
  final List<ProfilePoint> profile; // Detaylı 2D kesit grafiği verileri

  LineOfSightResult({required this.isVisible, required this.profile});
}

/// İki koordinat arasında dünya eğriliğini ve arazi engellerini
/// hesaba katarak (RF / Optik) görüş hattını hesaplar.
class LineOfSightCalculator {
  final HgtParser hgtParser;

  // Dünya'nın ortalama yarıçapı (metre)
  static const double earthRadiusMeters = 6371000.0;

  // Radyo dalgaları (LoRa vb.) atmosferik kırılma nedeniyle ufkun ötesine bir miktar
  // eğilerek giderler. Telsiz haberleşmesinde efektif dünya yarıçapı 4/3 R kabul edilir.
  static const double radioEarthRadiusMeters = earthRadiusMeters * (4 / 3);

  LineOfSightCalculator(this.hgtParser);

  /// [source]: Kaynak koordinat
  /// [target]: Hedef koordinat
  /// [sourceHeightMeters]: Kaynaktaki antenin/gözlemcinin yerden yüksekliği (Örn: 2m)
  /// [targetHeightMeters]: Hedefteki antenin/gözlemcinin yerden yüksekliği (Örn: 2m)
  /// [sampleStepMeters]: Kaç metrede bir yükseklik örneği alınacağı (Örn: 50m)
  /// [useRadioHorizon]: Optik görüş yerine RF dalga yayılımını (4/3 R) baz al.
  Future<LineOfSightResult> calculate({
    required LatLng source,
    required LatLng target,
    double sourceHeightMeters = 2.0,
    double targetHeightMeters = 2.0,
    double sampleStepMeters = 50.0,
    bool useRadioHorizon = true,
  }) async {
    const distance = Distance();
    final totalDistance = distance.as(LengthUnit.Meter, source, target);

    int sampleCount = (totalDistance / sampleStepMeters).ceil();
    if (sampleCount < 2) sampleCount = 2; // En az başlangıç ve bitiş noktaları olmalı

    List<ProfilePoint> profile = [];
    bool hasGlobalLos = true;

    double rEffective = useRadioHorizon ? radioEarthRadiusMeters : earthRadiusMeters;

    // Başlangıç ve Bitiş yüksekliklerini al
    int? sourceElevRaw = await hgtParser.getElevation(source.latitude, source.longitude);
    int? targetElevRaw = await hgtParser.getElevation(target.latitude, target.longitude);

    // Yükseklik verisi (DEM) yoksa geçici olarak deniz seviyesi (0) kabul et
    double hSource = (sourceElevRaw ?? 0).toDouble() + sourceHeightMeters;
    double hTarget = (targetElevRaw ?? 0).toDouble() + targetHeightMeters;

    for (int i = 0; i <= sampleCount; i++) {
      double fraction = i / sampleCount;

      // Koordinat interpolasyonu (Yakın mesafelerde basit lineer yaklaşım yeterlidir)
      double lat = source.latitude + (target.latitude - source.latitude) * fraction;
      double lon = source.longitude + (target.longitude - source.longitude) * fraction;

      double currentDist = totalDistance * fraction;

      int? elevRaw = await hgtParser.getElevation(lat, lon);
      double elevation = (elevRaw ?? 0).toDouble();

      // Dünya Eğriliği Faktörü (Earth Curvature Drop)
      // Formül: h_drop = (d1 * d2) / (2 * R)
      // İki nokta arasındaki tepeler, Dünya'nın bombesi yüzünden ışın hattına daha çok yaklaşır.
      double d1 = currentDist;
      double d2 = totalDistance - currentDist;
      double curvatureDrop = (d1 * d2) / (2 * rEffective);

      double elevationWithCurvature = elevation + curvatureDrop;

      // İki anten arasına çizilen düz ışının (Line of Sight) o mesafedeki yüksekliği
      double losRayHeight = hSource + ((hTarget - hSource) * fraction);

      // Işın dağın/arazinin içinden mi geçiyor?
      bool isPointVisible = true;
      if (i > 0 && i < sampleCount) { // Başlangıç ve bitiş noktalarını engelden sayma
        if (elevationWithCurvature > losRayHeight) {
          isPointVisible = false;
          hasGlobalLos = false;
        }
      }

      profile.add(ProfilePoint(
        coordinate: LatLng(lat, lon),
        distanceMeters: currentDist,
        elevation: elevation,
        elevationWithCurvature: elevationWithCurvature,
        lineOfSightHeight: losRayHeight,
        hasLineOfSight: isPointVisible,
      ));
    }

    return LineOfSightResult(isVisible: hasGlobalLos, profile: profile);
  }
}
