/// Mapbox'ın çevrimdışı indirilebilen harita türleri (Aşama H). Katman
/// listesi ve bölge indirici aynı stil adresini kullanır: haritada gösterilen
/// stil ile indirilen stil aynı olmalı ki internetsizken karolar bulunsun.
enum OfflineMapType {
  satellite('Uydu', 'mapbox://styles/mapbox/satellite-streets-v12'),
  streets('Sokak', 'mapbox://styles/mapbox/streets-v12'),
  outdoors('Topografik', 'mapbox://styles/mapbox/outdoors-v12');

  const OfflineMapType(this.label, this.styleUri);
  final String label;
  final String styleUri;

  static OfflineMapType? fromStyleUri(String? uri) {
    for (final t in values) {
      if (t.styleUri == uri) return t;
    }
    return null;
  }

  static OfflineMapType? fromName(String? name) => values.asNameMap()[name];
}

/// Cihaza indirilmiş (çevrimdışı) bir harita bölgesi. Saf Dart.
class OfflineRegion {
  const OfflineRegion({
    required this.id,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.maxZoom,
    required this.createdAt,
    required this.sizeBytes,
    required this.completedResources,
    required this.requiredResources,
    this.types = const [OfflineMapType.satellite],
  });

  final String id;
  final String name;

  /// Kapsama dikdörtgeni (WGS84 derece).
  final double south, west, north, east;

  /// İndirilen en yüksek detay seviyesi (z0'dan bu zoom'a kadar).
  final int maxZoom;
  final DateTime createdAt;

  /// Diskte kapladığı yer (bayt).
  final int sizeBytes;
  final int completedResources;
  final int requiredResources;

  /// İndirilen harita türleri (eski bölgeler: yalnız uydu).
  final List<OfflineMapType> types;

  /// Sınırı biliniyor mu (eski deneme kayıtlarında yok → haritada gösterilemez).
  bool get hasBounds => north > south && east > west;

  /// Tüm kaynaklar indirildi mi (yarıda kesilen indirme → false).
  bool get isComplete =>
      requiredResources > 0 && completedResources >= requiredResources;
}

/// Yeni indirilecek bölgenin tanımı.
class OfflineRegionSpec {
  const OfflineRegionSpec({
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.maxZoom,
    this.types = const [OfflineMapType.satellite],
  });

  final String name;
  final double south, west, north, east;
  final int maxZoom;

  /// İndirilecek harita türleri (en az biri).
  final List<OfflineMapType> types;
}

/// İndirilebilir detay seviyeleri (kullanıcıya gösterilen seçenekler).
enum OfflineDetail {
  recon(14, 'Keşif', 'arazi şekli, köyler, ana yollar'),
  terrain(16, 'Arazi', 'patikalar, tarlalar, binalar'),
  detail(18, 'Detay', 'tek tek bina, araç ölçeği');

  const OfflineDetail(this.maxZoom, this.label, this.hint);
  final int maxZoom;
  final String label;
  final String hint;
}
