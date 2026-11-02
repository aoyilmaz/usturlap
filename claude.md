# Pusula — Proje Brief'i & Claude Code Başlangıç Prompt'u

> Bu dosyayı projenin kök dizinine `CLAUDE.md` olarak koy. VS Code'da Claude Code'u
> başlatınca bu brief otomatik bağlam olur. İlk mesajın olarak da bu dosyaya
> "Bu brief'i oku ve Faz 1 / Adım 1'den başla" diyebilirsin.
>
> Çalışma adı **Pusula**. İstersen `pusula` yerine başka bir snake_case ad kullan;
> tüm dosyada tutarlı şekilde değiştir.

---

## 0. Ajanın Rolü

Sen kıdemli bir **Flutter / Dart geliştiricisisin**. Çevrimdışı öncelikli (offline-first),
mobil taktik harita uygulaması geliştiriyorsun. Kullanıcı (proje sahibi) Python/PyQt6 ve
SQLite deneyimine sahip; Dart/Flutter'da yeni. Bu yüzden:

- Kararlarını **kısaca gerekçelendir**, ama brief'i her seferinde tekrar anlatma.
- **Küçük, çalışan adımlarla** ilerle. Her adım sonunda derlenen, çalışan bir hal bırak.
- Büyük/yıkıcı değişikliklerden (paket değişimi, mimari kırılma, dosya silme) **önce onay iste**.
- Cihaz derlemesi, Xcode imzalama ve fiziksel iPhone'da test **kullanıcının sorumluluğunda**.
  Sen kodu ve çalıştırma talimatlarını ver; çıktıyı kullanıcıdan iste.

---

## 1. Ürün Hedefi

İnternet/baz istasyonu olmadan çalışan, tek başparmakla kullanılabilen kişisel bir
taktik harita uygulaması. İlham kaynağı Map Warfare; ama bu sürüm **tek kullanıcı**
ve **kişisel kullanım** içindir.

**Ana ilkeler**
- **Offline-first:** harita karoları, waypoint'ler ve track'ler internet olmadan çalışmalı.
- **Tek elle / eldivenle kullanım:** büyük dokunma hedefleri, kalıcı üst HUD.
- **Gizlilik:** hesap yok, telemetri yok, tüm veri cihazda.
- **Sade jest seti:** stres altında kas hafızasıyla kullanılabilecek kadar az jest.

---

## 2. Kısıtlar ve Kararlar

- **Platform önceliği:** iOS (iPhone). Kod tabanı baştan Android'i de destekleyecek
  şekilde platform-bağımsız yazılır, ama test ve cilalama önce iOS'ta.
- **Uydu görüntüsü (2026-11-02'de güncellendi):** Yüksek çözünürlüklü uydu **Mapbox Satellite**
  ile sağlanır, **yalnızca Mapbox Maps SDK** üzerinden (çevrimiçi + SDK'nın kendi
  OfflineManager/TileStore indirmesi). Mapbox/Google/Esri karolarını **kendi indiricimizle**
  (FMTC, script, pusula-tiler) toplu indirmek/önbelleğe almak **YASAK** (lisans ihlali).
  - Geçiş planı: [`docs/harita-motoru-gecis-plani.md`](docs/harita-motoru-gecis-plani.md)
  - Mapbox token'ı koda gömülmez: `--dart-define=MAPBOX_ACCESS_TOKEN=pk...`
- **Kullanıcının kendi karo paketleri** (yasal/ücretsiz kaynaklar) desteklenmeye devam eder:
  - **OpenStreetMap / Protomaps** (vektör/sokak), **Topografik** (OpenTopoMap / Copernicus DEM)
  - **ESA Sentinel-2** (~10 m uydu), WMS ortofoto vb.
  - Bunlar `pusula-tiler` / QGIS + `gdal2tiles` ile MBTiles/PMTiles olarak üretilip içe aktarılır.
- **Mesh (Meshtastic) Faz 2'dir.** Ama v1 mimarisi mesh'e hazır olmalı (bkz. §4 soyutlamalar).

---

## 3. Teknoloji Yığını

> Sürümleri sabitlemeden önce **pub.dev'den güncel kararlı (stable) sürümleri doğrula**;
> bilgi tabanın eski olabilir. Aşağıdakiler paket seçimleridir, sürüm değil.

| Katman | Paket / Araç | Not |
|---|---|---|
| Çatı | Flutter (stable) + Dart | Tek kod, iOS + Android |
| Harita (hedef) | `mapbox_maps_flutter` | GPU motoru, Mapbox Satellite, 3B arazi, SDK içi offline indirme. Geçiş sürüyor (spike) |
| Harita (mevcut) | `flutter_map` | Geçiş bitene kadar ana ekran; MBTiles/PMTiles katmanları |
| Karo katmanları | `mbtiles` / `pmtiles` okuyucu | Kullanıcının kendi çevrimdışı paketleri |
| Çevrimdışı indirme | Mapbox `OfflineManager` + `TileStore` | FMTC **kullanılmaz** (Mapbox karoları için lisans ihlali) |
| Yerel veri | `drift` (SQLite üstü) | Waypoint/track/geofence; tip güvenli |
| Konum | `geolocator` | Konum, hız, yükseklik |
| Pusula | `flutter_compass` | Kerteriz |
| Koordinat | `mgrs_dart`, `proj4dart` | MGRS / UTM / WGS84 |
| Durum yönetimi | `riverpod` | Sade, test edilebilir |
| BLE (Faz 2) | `flutter_blue_plus` | Meshtastic düğümü |
| Protobuf (Faz 2) | `protobuf` + `protoc` | Meshtastic mesajları |

---

## 4. Mimari İlkeler (KRİTİK)

v1 tek kullanıcı olsa da, Faz 2'de mesh'i **söküp yeniden yazmadan** ekleyebilmek için
iki soyutlama baştan konur:

### 4.1 `PositionSource` arayüzü
Haritadaki tüm konum işaretçileri bu arayüzden beslenir.
- v1 implementasyonu: `DevicePositionSource` (telefon GPS'i — tek işaretçi).
- Faz 2 implementasyonu: `MeshPositionSource` (mesh düğümlerinden gelen çoklu callsign).
- Harita/HUD katmanı hangi kaynağın aktif olduğunu **bilmez**; sadece `Stream<List<Contact>>` dinler.

### 4.2 `CommsChannel` arayüzü
Mesaj/waypoint paylaşım kanalı soyutlaması.
- v1 implementasyonu: `NullCommsChannel` (no-op) ve/veya `LocalShareChannel` (clipboard/SMS export).
- Faz 2 implementasyonu: `MeshCommsChannel` (Meshtastic text + waypoint mesajları).

### 4.3 Katmanlama
```
presentation (widget'lar, harita ekranı, HUD)
      │  riverpod provider'lar üzerinden
domain  (Contact, Waypoint, Track, Geofence modelleri; arayüzler)
      │
data    (drift/SQLite, MBTiles okuyucu, PositionSource/CommsChannel impl.)
```
- `domain` katmanı Flutter'a bağımlı olmamalı (saf Dart) → test edilebilirlik.

---

## 5. Önerilen Klasör Yapısı

```
pusula/
├─ CLAUDE.md                 # bu dosya
├─ pubspec.yaml
├─ assets/
│  └─ tiles/                 # gömülü MBTiles (kullanıcı koyar)
├─ lib/
│  ├─ main.dart
│  ├─ app.dart
│  ├─ core/                  # sabitler, tema, jest tanımları
│  ├─ domain/
│  │  ├─ models/             # Contact, Waypoint, Track, Geofence
│  │  └─ ports/              # PositionSource, CommsChannel arayüzleri
│  ├─ data/
│  │  ├─ db/                 # drift şeması
│  │  ├─ tiles/              # MBTiles okuyucu
│  │  ├─ position/           # DevicePositionSource
│  │  └─ comms/              # NullCommsChannel / LocalShareChannel
│  ├─ features/
│  │  ├─ map/                # harita ekranı + katman kontrolü
│  │  ├─ hud/                # callsign HUD
│  │  ├─ waypoints/
│  │  ├─ tracks/
│  │  └─ tools/              # mesafe/çizgi araçları
│  └─ providers/             # riverpod
└─ test/
```

---

## 6. FAZ 1 — Kişisel (iPhone, Çevrimdışı)

Her adım sonunda: derlenir, çalışır, kısa bir "nasıl test edilir" notu verirsin.

**Adım 1 — İskelet + ekranda harita**
- Flutter projesi, klasör yapısı (§5), bağımlılıklar.
- `flutter_map` ile online raster karo (OSM) gösteren tek ekran.
- `PositionSource` ve `CommsChannel` arayüzlerini boş/stub olarak tanımla.
- Kabul: iPhone'da uygulama açılıyor, harita kaydırılıp yakınlaştırılabiliyor.

**Adım 2 — Çevrimdışı karolar**
- `assets/tiles/` içindeki bir MBTiles dosyasını okuyup gösteren katman.
- Katman değiştirici (sokak / topografik / uydu) — basit alt-sağ buton.
- Kabul: uçak modunda harita görünüyor.

**Adım 3 — GPS + pusula + HUD**
- `DevicePositionSource` (PositionSource impl.) → konum, hız, yükseklik.
- Üstte kalıcı **Callsign HUD**: callsign, koordinat, kerteriz, hız, yükseklik (MSL notu).
- Harita üzerinde kendi konum işaretçisi + kuzey/track-up modu.
- Kabul: hareket edince HUD ve işaretçi güncelleniyor.

**Adım 4 — Waypoint + SQLite + MGRS**
- Uzun bas → waypoint bırak; drift ile kaydet; listele/sil.
- Koordinatı MGRS olarak göster (`mgrs_dart`).
- Kabul: waypoint uygulama yeniden açılınca duruyor.

**Adım 5 — Koordinat format geçişi**
- HUD'a çift dokun → MGRS / UTM / WGS84 döngüsü; tercih kalıcı.

**Adım 6 — Track kaydı**
- Başlat/durdur ile rota izi; polyline çizimi; drift'e kaydet; KML/GeoJSON export.

**Adım 7 — Mesafe / çizgi araçları**
- Nokta koyarak mesafe ölçümü, sektör/poligon çizimi; katman olarak gizle/göster.

**Adım 8 — Gece modu + jest cilası**
- Düşük ışık teması; jest seti: uzun-bas (waypoint), çift-dokun-HUD (format),
  sağ kenardan kaydır (katman paneli).

---

## 7. FAZ 2 — Mesh (İnternetsiz Squad, Meshtastic)

> Bu fazın başında **Dart/Meshtastic ekosisteminin güncel durumunu birlikte doğrula**;
> olgun resmi paket olmayabilir. Referans: resmi Android (Kotlin) ve iOS (Swift) uygulamaları.

**Adım 9 — BLE bağlantısı**
- `flutter_blue_plus` ile Meshtastic düğümü tarama/bağlanma (hedef bölge **EU_868**).

**Adım 10 — Protobuf entegrasyonu**
- Meshtastic `.proto` tanımlarını `protoc` ile Dart'a derle; BLE çerçeveleme protokolü.

**Adım 11 — Mesh konumları → harita**
- `MeshPositionSource` (PositionSource impl.) → düğümleri callsign'lı işaretçi olarak göster.

**Adım 12 — Waypoint paylaşımı (mesh)**
- `MeshCommsChannel` üzerinden Meshtastic Waypoint mesajı gönder/al.

**Adım 13 — Metin mesajlaşma**
- Basit taktik sohbet (mesh text mesajları).

---

## 8. Çalışma Şekli & Kalite

- **Adım adım git.** Aynı anda tek özellik. Her adımı çalışır bırak.
- **Test:** `domain` modelleri ve koordinat dönüşümleri için birim test yaz.
- **Onay kapıları:** paket ekleme/çıkarma, mimari değişiklik, dosya silme → önce sor.
- **Sürüm doğrulama:** paket eklerken pub.dev'den güncel stable sürümü kontrol et.
- **Yorumlar:** kritik yerlerde kısa, Türkçe yorum (kullanıcı Dart'ta yeni).
- **Sırlar:** API anahtarı/koordinat gibi şeyleri koda gömme; gerekiyorsa `--dart-define`.
- **iOS notu:** her adımda kullanıcıya "iPhone'da nasıl çalıştırılır" (Xcode imzalama,
  `flutter run`) kısa hatırlatması ver; ama derlemeyi/imzalamayı kullanıcı yapar.

---

## 9. ŞİMDİ YAP

**Faz 1 / Adım 1**'den başla:
1. `pusula` adıyla Flutter projesi oluştur, §5 klasör yapısını kur.
2. `flutter_map` ekle, OSM raster karo gösteren tek ekran yaz.
3. `PositionSource` ve `CommsChannel` arayüzlerini `domain/ports/` altında tanımla (stub impl. ile).
4. Bittiğinde: ne yaptığını 3-4 satırda özetle ve iPhone'da nasıl çalıştırılacağını yaz.
Sonra Adım 2 için onayımı bekle.
