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
  });

  final String name;
  final double south, west, north, east;
  final int maxZoom;
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
