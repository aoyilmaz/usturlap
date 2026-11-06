# ATAK-CIV teknik analizi ve Pusula için sonuçlar

> **Tarih:** 2026-11-05 · **Kaynak:** `github.com/TAK-Product-Center/atak-civ`, `main`,
> commit `9f6893d` (1 Aralık 2025, "upstream/5.5.1.10"), ATAK **5.5.1.10**, takkernel **8.30.5**.
>
> **Yöntem:** Depo sığ klonlandı (LFS dosyaları indirilmeden). Analizin büyük kısmı doğrudan
> kaynak okumasıyla yapıldı. Kaynağı olmayan PAR Government video kütüphaneleri **REA** ile
> (dışa aktarım tablosu + dizgeler) incelendi.
>
> **İşaretler:** ✓ = dosya okunarak doğrulandı (varsayılan; işaretsiz iddialar da ✓) ·
> **?** = çıkarım/doğrulanmadı. Cihazda saldırı ya da birlikte çalışma testi **yapılmadı**.
>
> **Dosya yolları** aksi belirtilmedikçe atak-civ deposunun köküne göredir.
> Yeniden üretmek için §8'e bakın.
>
> İlgili belgeler: [atak-karsilastirma.md](atak-karsilastirma.md) (kılavuza göre özellik
> karşılaştırması) · [faz2-brief.md](faz2-brief.md) · [yol-haritasi.md](yol-haritasi.md)

---

## 0. Özet ve karar

1. **ATAK-CIV'in altyapısı:** Android uygulaması (Java) + takkernel (Java + C++ OpenGL ES 3
   harita motoru) + commoncommo (C++ ağ katmanı) + kapalı kaynak PAR video yığını.
   Birinci taraf kod ~1,3 milyon satır. Ayrıntı: §1.
2. **Yapılabilirlik:** TAK uyumlu küçük bir istemci birkaç ayda yapılabilir. ATAK seviyesi
   çok yıllık bir iş. Zor olan protokol değil, harita motoru ve native bağımlılıklar. Ayrıntı: §2.
3. **Fork güvenilirliği:** Kodda arka kapı, telemetri ya da uzaktan kapatma **bulunmadı**.
   Ama güvenlik modeli "ağdaki herkes dosttur" varsayımına dayanıyor ve kaynağı olmayan
   ikili dosyalar içeriyor. Olduğu gibi fork'lanırsa riskli, sertleştirilirse güvenilir. Ayrıntı: §3.
4. **Pusula için öneri (kullanıcı henüz onaylamadı):** ATAK'ı **fork'lamayın**. Pusula ile
   devam edin, Faz 2'de **CoT / Meshtastic `TAKPacket` uyumu** ekleyin. ATAK-CIV'i kod kaynağı
   olarak değil, **spesifikasyon + test eşi + özellik kataloğu** olarak kullanın. Ayrıntı: §4.
5. **Faz 2'de doğrudan kullanılacak protokol bilgisi:** §5.

**Sıradaki somut adımlar:**
- [ ] B aşamasının (navigasyon + yatay düzen) yürüme testi ve commit'i (bekliyor).
- [ ] CoT uyumu kararını onayla ya da reddet → onaylanırsa `faz2-brief.md`'ye "CoT/TAKPacket uyumu" bölümü ekle.
- [ ] Mapbox SDK'nın telemetri / MAU davranışını README'deki "telemetri yok" ilkesine göre kontrol et (?).
- [ ] Meshtastic donanımı gelince `TAKPacket` ile ATAK eşleşmesini uçtan uca doğrula (?).

---

## 1. ATAK-CIV teknik altyapısı

### 1.1 Depo yapısı ve büyüklük

| Modül | Rol | Büyüklük |
|---|---|---|
| `atak/` | Android uygulaması (`com.atakmap.*`) | 2.175 Java dosyası, ~553 bin satır |
| `takkernel/` | Ortak çekirdek: annotation → port → engine → shared | ~310 bin satır Java + ~430 bin satır C++ |
| `commoncommo/` | Ağ/iletişim kütüphanesi (C++; JNI, ObjC ve C#/Win32 bağları) | ~44 bin satır C++ |
| `takproto/` | TAK Protocol v1 protobuf şemaları | 10 `.proto` |
| `takcot/` | CoT XSD şemaları (TAK + MITRE temel şemaları) ve örnek `.cot` dosyaları | |
| `takthirdparty/` | Native bağımlılık derleme sistemi (Makefile + yamalar) | |
| `depends/`, `takengine/` | Değiştirilmiş GDAL 2.4.4, ASSIMP 4.0.1, tinygltf, LASzip, libLAS (LFS) | |
| `cesium-native/`, `draco/`, `khronos/` | 3D Tiles, mesh sıkıştırma, GL/EGL başlıkları | |
| `plugin-examples/` | 27 örnek eklenti | |
| `atak-gradle-takdev/` | Eklenti geliştirme Gradle eklentisi + özel lint kuralları | |

Lisans: **GPLv3** (`LICENSE.md`). ABD federal çalışanlarının katkıları ABD'de kamu malı (`INTENT.md`).
Kök `VERSION.md` 4.6.1.0'da, `BUILDING.md` NDK r12b'de kalmış; ikisi de güncel değil.

### 1.2 Katmanlı mimari

```
┌──────────────────────────────────────────────────────────────┐
│ Eklentiler (ayrı APK'lar) ── DexClassLoader ──► aynı süreç   │
├──────────────────────────────────────────────────────────────┤
│ ATAK uygulaması (tek Activity: ATAKActivity / MapActivity)   │
│  72 MapComponent · DropDownReceiver paneller · AtakBroadcast │
├──────────────────────────────────────────────────────────────┤
│ takkernel: shared (CoT, widget, semboloji, eklenti API'si)   │
│            engine (Java + JNI ⇄ C++ OpenGL ES 3 motoru)      │
│            port (platform soyutlama) · annotation            │
├───────────────────────────┬──────────────────────────────────┤
│ commoncommo (C++/JNI)     │ PAR Gv2F/PGSC video (kapalı      │
│ UDP/TCP/TLS/QUIC          │ kaynak, FFmpeg 7.1.1 tabanlı)    │
├───────────────────────────┴──────────────────────────────────┤
│ takthirdparty: GDAL, PROJ, GEOS, SpatiaLite, SQLCipher,      │
│ OpenSSL, curl, libkml, libxml2, protobuf, ngtcp2, nghttp2,   │
│ MrSID, PDFium, mdbtools, OGDI, libmicrohttpd                 │
└──────────────────────────────────────────────────────────────┘
```

### 1.3 Uygulama çekirdeği

- **Tek Activity:** Harita ve araçların hepsi `ATAKActivity` (2.811 satır) içinde. Diğer
  Activity'ler sadece ayar ve liste ekranları.
- **Bileşen yükleyici:** `atak/ATAK/app/src/common/java/com/atakmap/android/maps/MapComponentLoader.java:101-212`
  - 72 bileşeni sabit sırayla yüklüyor: Location ilk, Comms ikinci, Plugin en son.
  - 8 bileşen (Comms, User, Cot, Chat, Layers, Wkt, StateSaver, Model) arka planda yükleniyor.
  - Flavor'lar `SystemComponentLoader` ile araya bileşen ekleyebiliyor.
- **Arayüz:**
  - Yan paneller `DropDownReceiver`'dan türüyor (56 alt sınıf; ekranın 1/3, 1/2, 5/8… oranları).
  - Radyal menüler, nesnenin CoT tipine göre `assets/menus/` altındaki 98 XML dosyasından seçiliyor.
- **İç iletişim:** `AtakBroadcast` (LocalBroadcastManager sarmalayıcısı) üzerinden Intent'ler.
- **CoT işleme:** `<detail>` alt öğeleri 38 `CotDetailHandler` alt sınıfına dağıtılıyor: contact,
  `__group`, status, track, takv, remarks, link, archive, color, usericon, shape, `__video`,
  `__geofence`, `_medevac_`, emergency, sensor, `__navcues`, targetMunitions, bullseye…
- **Çökme raporlama:** ACRA 4.6.1 (Java) + jnicrash / libunwindstack (native).

### 1.4 Veri modeli: CoT ve TAK Protocol

Ayrıntılı protokol bilgisi Faz 2 için §5'te. Kısaca:
- **CoT XML olayı:** `<event uid type how time start stale><point lat lon hae ce le/><detail>…</detail></event>`.
  Tip kodları MIL-STD-2525 tabanlı (ör. `a-f-G-U-C` = dost kara birliği).
- **TAK Protocol v1:** Aynı bilginin protobuf karşılığı. Yerel ağda ve sunucu akışında farklı çerçeveleme kullanılıyor.

### 1.5 Ağ katmanı (commoncommo)

| Amaç | Adres / port | Kaynak |
|---|---|---|
| Konum yayını (SA), giriş/çıkış | 239.2.3.1:6969 UDP multicast | `atak/.../comms/CotService.java:750-772` |
| GeoChat | 224.10.10.1:17012 | `ChatManagerMapComponent.java:490`, `commoncommo/core/impl/contactmanager.cpp:1200-1202` |
| Doğrudan mesaj | 4242 UDP + TCP | `CotService.java:750-754`, `cotmessage.cpp:1646-1680` |
| QUIC gelen | 4243/UDP | `CommsMapComponent.java:1426` |
| Sensör verisi (varsayılan kapalı) | 239.5.5.55:7171 | `CotService.java:764-768` |
| PRC-152 | 10011 UDP | `CotService.java:770-771` |
| Ağdan GPS (NMEA) | 4349 UDP | `res/xml/network_gps_preferences.xml:14` |
| TAK Server akışı | 8089 TLS, 8090 QUIC | `comms/app/AddNetInfoActivity.java:438-441` |
| TAK Server API | 8443 HTTPS, 8080 HTTP | `android/cot/CotMapComponent.java:1280-1293` |
| Sertifika kaydı | 8446 | `CotMapComponent.java:1306` |

**Taşıma yöntemleri:**
- UDP multicast/unicast.
- TCP: bağlan, tek mesaj gönder, kapat.
- TLS: PKCS#12 istemci sertifikası + güven deposu; isteğe bağlı kullanıcı/parola auth mesajı.
- QUIC: ngtcp2 + quictls; ALPN değerleri `takcot` ve `takfdp` (`commoncommo/core/impl/quicmanagement.cpp:26-30`).

**Yerel ağ şifrelemesi** (isteğe bağlı, varsayılan kapalı):
- AES-256-CBC + HMAC-SHA256: önce şifrele sonra imzala, rastgele IV (`commoncommo/core/impl/cryptoutil.cpp:88-240`).
- Anahtar ayarlara girilen 64 karakterlik bir metinden geliyor: ilk 32 karakter HMAC, son 32 karakter AES anahtarı.
- Karakterler anahtar türetme olmadan doğrudan ASCII bayt olarak kullanılıyor (`CommsMapComponent.java:920-945`, `rekey()`).

**Diğer Commo yetenekleri:**
- **Görev paketi aktarımı:** Cihazın kendi HTTP(S) sunucusu (`/getfile`, `/getinfo`, QUIC için `/qprox`) ya da TAK Server (`/Marti/sync/missionupload`, `/missionquery`) — `missionpackagemanager.cpp:1119-1186`.
- **Sertifika kaydı:** Cihazda CSR üretiliyor → `/Marti/api/tls/config`, `/Marti/api/tls/signClient/v2`; token auth destekleniyor (`enrollmentmanager.cpp:434-446`).
- **CloudClient:** HTTP/HTTPS/FTP/FTPS üzerinde list/get/put/move/mkcol/delete (`include/cloudio.h`). CA verilmezse her sertifikayı kabul ediyor (`include/commo.h`'de belgeli).
- **Diğer:** Kişi/çevrimiçi durum takibi, CoTDetailExtender ile özel protobuf uzantıları, XML ⇄ protobuf dönüştürücüler (`include/commo.h`).
- **Uygulamanın kullandığı TAK Server REST yolları:** `/api/device/profile/connection`,
  `/api/device/profile/tool/`, `/api/tls/profile/enrollment`, `/api/groups/all`,
  `/api/groups/active`, `/api/cot/xml/`, `/sync/content?hash=`, `/sync/search`, `/vcm`,
  `/TracksKML`, `/ExportMissionKML`, `/ErrorLog`, `/update`.

### 1.6 Harita motoru (takkernel/engine)

- **Çizim:** OpenGL ES 3.0 (EGL client v3). `GLMapView2`, `GLGlobe`/`TiledGlobe` (küre + düz),
  atmosfer shader'ı, tarih değiştirme çizgisi desteği, MSDF/SDF glif atlası ile etiketler
  (`takkernel/engine/src/main/cpp/renderer/core/`).
- **Raster:** GDAL, MBTiles, OSMDroid, GeoPackage, PFPS (FalconView), MOBAC, MrSID, PDFium (GeoPDF ?).
  KDU/JPEG2000 kamuya açık derlemede kapalı.
- **Yükseklik:** DTED, Cesium quantized-mesh, heightmap, eğim ve yükseklik ısı haritası katmanları, EGM96, WMM.
- **Vektör:** KML/KMZ, GPX, Shapefile, OGR, OGDI, GeoJSON, GML, Mapbox Vector Tiles; SpatiaLite tabanlı özellik veritabanı.
- **3D:** ASSIMP (OBJ/DAE/PLY), glTF, Cesium 3D Tiles, Draco, LAS nokta bulutu, ContextCapture/Pix4D georeferanslama.
- **Semboloji:** MIL-STD-2525C/D/E — `mil-sym-android` 2.4.0 / `mil-sym-java` 2.1.5 (Apache-2.0).

### 1.7 Uygulama işlevleri (paket adlarına göre; açıklamalar ?)

| Alan | Paketler |
|---|---|
| Durum farkındalığı | kendi işaret, kişiler, iz geçmişi, ekran dışı göstergeler, acil durum, geofence, düşman yönetimi, kanallar |
| Çizim | drawing, rubbersheet (görüntü oturtma), GRG, MGRS ızgara, hashtag'ler |
| Ölçüm / hedefleme | R&B, bloodhound, resection, viewshed, LRF (PLRF BLE), danger close, fires, mühimmat |
| Navigasyon | routes (80 dosya), GPX, ölü hesap, birinci şahıs görünüm |
| İletişim / veri | GeoChat, görev paketi, dosya paylaşımı, video, WFS, FTP |
| Sağlık | MEDEVAC 9-line |
| Telsiz / sensör | Harris SA / PRC-152, ROVER, Wave Relay, ISRV, Bluetooth (klasik + BLE), USB seri, NMEA |
| İçe aktarma | 33 sınıflandırıcı: CoT, KML/KMZ, GPX, SHP, GeoJSON, GML, DTED, MVT, SQLite, GRG, JPEG/EXIF, ikon seti, sertifika, .pref, APK, görev paketi |

### 1.8 Eklenti mimarisi

`atak/ATAK/app/src/main/java/com/atak/plugins/impl/AtakPluginRegistry.java`:
1. Kurulu paketler taranıyor; `assets/plugin.xml` içeren APK aday sayılıyor
   (`<extension type="gov.tak.api.plugin.IPlugin" impl="…"/>`).
2. Manifestteki `plugin-api` (ör. `com.atakmap.app@5.5.1.CIV`) ile sürüm uyumu kontrol ediliyor (`:840`).
3. İmza kontrolü (`:138-198`): ATAK ile aynı anahtar **ya da** gömülü 5 sertifikadan biri
   (`ACCEPTABLE_KEY_LIST`, `:65`; TPC anahtarları ?) **ya da** App Transparency imzası
   (SHA256withRSA, `PluginValidator.java`). `sdk` derleme tipinde kontrol atlanıyor.
4. `DexClassLoader` ile ATAK'ın sürecine yükleniyor (`:1145`): korumalı alan yok, tam yetki.

### 1.9 Güvenlik ve veri saklama

- **Veritabanları:** SQLCipher, PBKDF2-HMAC-SHA256, 64.000 iterasyon; eski SHA1 formatından taşıma
  (`takkernel/engine/src/main/cpp/db/Database2.cpp:377-506`). İsteğe bağlı kullanıcı parolası (`ATAKDatabaseHelper.promptForKey`).
- **Kimlik bilgileri / sertifikalar:** `AtakAuthenticationDatabase` ve `AtakCertificateDatabase` (SQLCipher).
- **Dosya G/Ç:** `IOProviderFactory` ile değiştirilebilir sağlayıcı (Intune flavor'ı için).
- **Güvenilen CA:** Açılışta **DoD SW CA-66** güvenilir CA olarak ekleniyor (`ATAKActivity.java:358-366`).
- **Manifest:** `usesCleartextTraffic=true`, `allowBackup=false`. 46 izin (MANAGE_EXTERNAL_STORAGE,
  REQUEST_INSTALL_PACKAGES, arka planda konum dahil).
- **Dışa açık bileşenler:**
  - `ATAKActivity`: `tak://com.atakmap.app/enroll`, `/import`, `/preference`.
  - `ImportFileActivity`: SEND/VIEW `*/*`.
  - `ImageEditReceiver`: izinsiz (`AndroidManifest.xml:431-437`, yorum: "eski kod yüzünden izin konamıyor").

### 1.10 Derleme altyapısı

- AGP 8.9.0, Kotlin 2.1.10, compileSdk/targetSdk 35, minSdk 21, NDK 25.1.8937393, CMake, Conan 1.65
  (`atak/ATAK/app/build.gradle:6-7, 129-150`; `takkernel/gradle/versions.gradle`).
- **9 flavor** (`build.gradle:117-125`): civ (4 ABI), civSmall (Play Store), dhsSmall, mpsSmall,
  dmucSmall, fbi, fbium, intune, firstnetSmall (minSdk 24). "Small" sürümler sadece arm64.
  Açık depoda sadece `main`, `common`, `civSmall`, `small` kaynak kümeleri var.
- **Derleme tipleri** (`:261-290`): debug, release (ProGuard), sdk (debuggable, eklenti imza kontrolünü atlıyor).
- takkernel özel TAK Maven/Conan deposundan (kimlik bilgisi gerekir) ya da yerel kaynaktan çözülüyor.
  takthirdparty sadece Linux'ta derleniyor.
- **Testler:** 25 birim + 55 cihaz üstü + 17 UI test dosyası (uygulama); takkernel 209 test dosyası; Commo 7 test dosyası.

### 1.11 REA bulguları: kapalı video yığını

`atak/ATAK/app/src/main/jniLibs/<abi>/` (4 ABI) + `libs/pgscmobilevid.jar`, `libs/jpgscmedia.jar`:
- **`libpgscmediajni.so`:** 422 dışa aktarım, 240'ı JNI (`com.partech.pgscmedia.*`: MediaProcessor,
  MediaMultiplexer, MetadataInjector, VideoFrameConverter, KLVData, MediaMetadataDecoder).
- **KLV meta verisi:** MISB **ST 0601** öğeleri (çerçeve merkezi, köşe enlem/boylam, hedef konumu ve
  hata tahmini, platform, sensör, rüzgâr, silah, sınıflandırma, UMID) + **ST 1201 IMAPB**.
  Okuma ve yazma/enjeksiyon ikisi de var.
- **`libavformatpgsc.so`:** **FFmpeg 7.1.1**. İkilideki derleme ayarlarına göre:
  - Video formatları: H.264, HEVC, AV1 (dav1d), VP8/9, MPEG-1/2/4, MJPEG.
  - Protokoller: SRT, RTSP, RTP/SRTP, RTMP/RTMPS/RTMPE, HLS, HTTP(S), UDP, TCP.
  - Çıkış formatları: MPEG-TS, RTP, RTSP.
  - `--disable-hwaccels` → video yazılımla çözülüyor.
- **`libpgscmobilevid.so`:** Kamera görüntüsünü KLV ile MPEG-TS/RTSP olarak paketliyor.
- Sadece dışa aktarım ve dizgeler incelendi; tam decompile denetimi **yapılmadı**.

**Depoda olmayanlar:** `takkernel/controlled` (README'ye göre "kamuya açılamaz"), kurum flavor'larının
kodu, LFS içerikleri (`pluginsdk.zip`, `depends/*.tar.gz`).

---

## 2. Yapılabilirlik

**Üç yol** (maliyetler kaba tahmin):

| Yol | Ne demek | Kaba maliyet | Ana kısıt |
|---|---|---|---|
| A. Eklenti | Resmi ATAK + eklenti | Özellik başına haftalar–aylar | Resmi ATAK sadece TPC'nin imzaladığı eklentileri yükler (§1.8) |
| B. Fork | ATAK-CIV'i kendi markanla derle | Ortam kurulumu 2–6 hafta, sonra sürekli 3–6 kişi | GPLv3, kapalı video, upstream birleştirme yükü |
| C. Sıfırdan | TAK uyumlu kendi istemcin | MVP: 4–6 geliştirici, 6–12 ay · ATAK seviyesi: 20+ kişi, çok yıllık | ~1,3M satır, ~15 yıllık birikim |

**Zorluk haritası:**
- **Kolay:** CoT/TAK Protocol (belgeli, protobuf), multicast SA, TLS + PKCS#12, sertifika kaydı,
  yerel ağ şifrelemesi (basit yapı). Sunucu tarafı hazır: TAK Server kaynağı açık
  (`TAK-Product-Center/Server`), FreeTAKServer (EPL-2.0), OpenTAKServer (GPL-3.0).
- **Orta:** MIL-STD-2525 (mil-sym Apache-2.0), görev paketi formatı, KML/GPX/SHP (GDAL), video
  (FFmpeg) + MISB 0601 KLV ayrıştırıcı.
- **Zor:** Çevrimdışı harita motoru (DTED, CADRG/CIB, MrSID, GeoPDF, viewshed, 3D) — takkernel'deki
  ~430 bin satır C++. Telsiz entegrasyonları (üretici belgesi + cihaz gerekiyor). Akreditasyon.

---

## 3. Fork güvenilirliği

### 3.1 Arka kapı / veri sızıntısı: temiz

- Google/Firebase, Crashlytics ya da analitik SDK'sı **yok**.
- Çökme raporları sadece diske yazılıyor (`ATAKCrashHandler.java:93-136`).
- `MetricsApi` uygulama içi yayın kullanıyor; sadece bir eklenti dinlerse çalışıyor (`MetricsApi.java:87-89`).
  `realtime_metrics` ve `collect_metrics` varsayılan kapalı (`MetricReportMapComponent.java:185-207`).
- Commo, ağdan gelen XML'i `XML_PARSE_NONET` ile ayrıştırıyor (`cotmessage.cpp:420`).

**Fork'ta değiştirilmesi gereken varsayılan dış bağlantılar ve güven noktaları:**

| Ne | Nerede |
|---|---|
| Yükseklik indirme sunucusu `tak.gov` | `android/elev/ElevationDownloader.java:49`, `res/xml/elevation_preferences.xml:30` |
| Cihaz kaydı, eklenti ve harita kataloğu `auth.tak.gov` / `tak.gov` (kullanıcı başlatıyor ?) | `takkernel/shared/.../client/eud/EndPoints.java:4-15` |
| Adres arama: MapQuest Nominatim (yazılan adresler üçüncü tarafa gider) | `android/user/geocode/GeocoderNominatim.java:37`, `assets/address/mapquest.xml` |
| DoD SW CA-66 güvenilir CA | `ATAKActivity.java:358-366` |
| Eklenti imzası için gömülü 5 yabancı sertifika | `AtakPluginRegistry.java:65` |

### 3.2 Kaynağı olmayan parçalar (tedarik zinciri)

- **PAR video:** 4 `.so` + 2 `.jar`; ATAK sürecinde kamera, mikrofon, konum ve ağ yetkileriyle çalışıyor.
  Çözüm: FFmpeg'i (LGPL) kendin derle + kendi KLV ayrıştırıcın, ya da derin REA denetimi.
- `libgnustl_shared.so`: hazır derlenmiş, NDK'nın terk ettiği eski C++ kütüphanesi.
- `libs/` altındaki hazır jar'lar (ACRA 4.6.1 vb.), "-mod" tarball'lar, özel Maven'den gelen takkernel AAR.
  → Hepsini kaynaktan derle, upstream ile karşılaştır, SBOM çıkar.

### 3.3 Tasarımdan gelen zaaflar (fork'ta sertleştirilmeli)

| # | Bulgu | Etkisi | Kanıt |
|---|---|---|---|
| 1 | Yerel ağ trafiği varsayılan şifresiz | Aynı ağdaki herkes konum ve sohbeti görür | `CotService.java:756-762` |
| 2 | `t-x-d-d` + `__forcedelete`: gönderen doğrulanmıyor; `remoteDelete` varsayılanı true | Ağdaki herhangi bir cihaz haritanızdan herhangi bir nesneyi siler | `android/cotdelete/CotDeleteImporter.java:68-83` |
| 3 | Gelen veri paketleri onaysız açılıp içe aktarılıyor; içindeki `.pref` varsayılan `ALLOW` ile **tüm** ayarları yüklüyor (TAK Server bağlantıları dahil); `filesharingEnabled` varsayılan true | Ağdaki bir cihaz, cihazınızı kendi sunucusuna yönlendirebilir | `CommsMapComponent.java:3111-3135` · `MissionPackageReceiver.java:1113, 1582-1610` · `ImportPrefResolver.java:155-170` · `res/xml/preference_management.xml:24-27` · `PreferenceControl.java:470-530` |
| 4 | Paket manifestindeki `onReceiveAction` gönderenin seçtiği bir uygulama içi Intent'i tetikletiyor | Uzaktan uygulama içi aksiyon tetikleme (etkisi ?) | `MissionPackageReceiver.java:1867-1890` |
| 5 | TLS hostname kontrolü bilinçli kapalı; cihazlar arası HTTPS aktarımında sertifika hiç doğrulanmıyor; CA verilmezse her sertifika kabul | Aynı CA'nın başka bir sertifikasıyla sunucu taklidi mümkün olabilir (EKU kontrolü doğrulanmadı ?) | `streamingsocketmanagement.cpp:85, 1966-1982` · `missionpackagemanager.cpp:1113, 1760-1768` · `urlrequestmanager.cpp:636-642` · `quicconnection.cpp:263` · `takkernel/.../AtakAuthenticationHandlerHTTP.java:438` |
| 6 | Tek paylaşımlı mesh anahtarı: KDF yok, kullanıcı başına anahtar yok, iptal ve ileri gizlilik yok | Bir cihaz ele geçerse tüm ağ açılır | `CommsMapComponent.java:920-945` |
| 7 | Eklentiler korumalı alan olmadan çalışıyor; `sdk` derlemesi imza kontrolünü atlıyor | Tek savunma imza anahtarı | `AtakPluginRegistry.java:138-176` |

**Doğru yapılmış olanlar:**
- SQLCipher ile veritabanı şifreleme.
- Zip slip koruması: `FileSystemUtils.sanitizeWithSpacesAndSlashes` `..` dizilerini ve izin listesi dışı
  karakterleri siliyor (`takkernel/engine/src/main/java/com/atakmap/coremap/filesystem/FileSystemUtils.java`;
  kullanımı `MissionPackageEventHandler2.java:96-105`).
- Sertifika zinciri güven deposuna göre doğrulanıyor: `SelfSignedAcceptingTrustManager` adına rağmen yerel
  depo + sistem CA'larıyla kontrol ediyor (`takkernel/.../platform/engine/net/CentralTrustManager.java:180-252`).
- APK kurulumu Android'in kullanıcı onaylı yükleyicisiyle yapılıyor (`android/update/AppMgmtUtils.java:97-99`);
  otomatik paket içe aktarmada APK atlanıyor (`MissionPackageMapOverlay.java:475`).

### 3.4 Kararlılık

- **Güçlü:** ~15 yıllık, geniş saha kullanımı; sürüm notlarında Play Store çökme kayıtlarından gelen düzeltmeler.
- **Zayıf:**
  - Kod büyüklüğüne göre test az: uygulamada ~97 test dosyası / 553 bin satır; Commo'da 7.
  - Commo'nun ağ ayrıştırıcıları için fuzz harness'i bulunamadı (?).
- **Fork riski:** Upstream'den uzaklaştıkça TPC'nin güvenlik düzeltmelerini birleştirmek zorlaşır.

### 3.5 Değerlendirme

| Senaryo | Güvenilirlik |
|---|---|
| Olduğu gibi fork, kapalı ve güvenilir ağ | Orta |
| Olduğu gibi fork, açık/çekişmeli ağ | Düşük (madde 1–3 doğrudan istismar edilebilir) |
| Sertleştirilmiş fork + bağımsız sızma testi | Yüksek, ulaşılabilir |

**Sertleştirme öncelikleri:**
1. Tedarik zinciri: kaynaktan derleme, PAR ve gnustl'ı çıkarma, kendi imza anahtarları, SBOM.
2. Yabancı güven noktalarını kaldırma: DoD CA, ACCEPTABLE_KEY_LIST, tak.gov / MapQuest.
3. Varsayılanlar:
   - .pref içe aktarma PROMPT/DENY; paketlerden gelen `cot_streams` asla kabul edilmesin.
   - Paket alımı sadece kimliği doğrulanmış kaynaklardan.
   - `remoteDelete` kapalı; `onReceiveAction` için izin listesi.
4. İletişim: şifresiz multicast kapalı; trafik kendi sunucunuz üzerinden TLS/QUIC; hostname ve EKU doğrulaması açık.
5. Test: Commo ayrıştırıcılarına fuzz testi; sahaya çıkmadan bağımsız sızma testi.

---

## 4. Pusula mı, ATAK fork'u mu?

**Öneri: Pusula ile devam et, ATAK'ı fork'lama.** (Kullanıcı henüz onaylamadı.)

| Kriter | Pusula | ATAK-CIV fork'u |
|---|---|---|
| Platform | iOS öncelikli (CLAUDE.md §2), Flutter ile Android de mümkün | Sadece Android; iTAK kapalı kaynak → iPhone'a sıfır katkı |
| Büyüklük / sahiplik | 84 dosya, ~10.800 satır Dart, 23 test dosyası (2026-11-05) | ~1,3M satır Java/C++, Linux'ta derlenen native bağımlılıklar, özel Maven |
| Ürün felsefesi | Tek elle, sade, offline, hesap yok | Özellik yoğun, "ağdaki herkes dosttur" varsayımı, riskli varsayılanlar (§3.3) |
| Lisans | Kişisel proje | GPLv3 + kapalı PAR video |
| ATAK'ın asıl farkı | Video/KLV, telsiz, TAK Server, eklentiler `atak-karsilastirma.md` §8'de zaten kapsam dışı | Fork'un getirisi tam da kapsam dışı alanlarda |

**"ATAK ile konuşan Pusula" planı:**
- **Meshtastic üzerinden (Faz 2'nin doğal devamı):** `meshtastic/protobufs` içindeki `meshtastic/atak.proto`
  → `TAKPacket` (PLI, GeoChat, Contact, Group, Status, Marker, DrawnShape…). `meshtastic/ATAK-Plugin`
  CoT'u mesh üzerinden taşıyor. Adım 10–13 `TAKPacket` ile yazılırsa iPhone'daki Pusula aynı mesh'teki
  Android ATAK kullanıcılarını görebilir (uçtan uca eşleşme donanımla doğrulanacak ?).
- **Wi-Fi yerel ağı üzerinden (donanım beklerken test için):** CoT XML → 239.2.3.1:6969 multicast, `CommsChannel`'ın
  ikinci uygulaması. Bir Android telefona ATAK-CIV kurup Pusula'yı ona karşı test et.
- **ATAK-CIV'in rolü:** Referans, test eşi, özellik kataloğu. **Kodunu kopyalama** (Pusula da GPLv3 olur);
  şemaları okuyup protokolü kendin yaz. Meshtastic `.proto` dosyaları da GPL-3.0: dağıtım düşünülürse dikkate al.

**Fork ne zaman doğru olurdu:** Kurumsal kullanım + sadece Android + ekip + kısa sürede TAK Server/video/telsiz
ihtiyacı. O durumda bile önce ATAK'a eklenti yazmak fork'tan ucuz olurdu.

**Uyarı:** README "telemetri yok" diyor; Mapbox SDK aylık aktif kullanıcı (MAU) sayımı için Mapbox'a bağlanıyor.
Telemetri ayarları ayrıca kontrol edilmeli (?).

---

## 5. Faz 2 için protokol referansı

### 5.1 CoT olayı (XML)

```xml
<?xml version='1.0' standalone='yes'?>
<event version='2.0' uid='PUSULA-<cihaz-id>' type='a-f-G-U-C' how='m-g'
       time='2026-11-05T12:00:00Z' start='2026-11-05T12:00:00Z' stale='2026-11-05T12:02:00Z'>
  <point lat='39.92' lon='32.85' hae='900' ce='10' le='15'/>
  <detail>
    <contact callsign='KURT-1' endpoint='*:-1:stcp'/>
    <__group name='Cyan' role='Team Member'/>
    <status battery='87'/>
    <track speed='1.2' course='45'/>
    <takv device='iPhone' platform='Pusula' os='iOS' version='1.0.0'/>
  </detail>
</event>
```
- `hae`/`ce`/`le` bilinmiyorsa `999999`.
- Şemalar: atak-civ `takcot/xsd/` (TAK detayları), `takcot/mitre/` (temel CoT).
- Örnekler: `takcot/examples/*.cot` (işaretçi, rota, geofence, R&B, çizimler).
- Silme: `type='t-x-d-d'` + `<link uid=… relation=… type=…/>` (+ isteğe bağlı `<__forcedelete/>`).
  Pusula'da **sadece kimliği doğrulanmış gönderenden** kabul edilmeli (§3.3 madde 2).

### 5.2 TAK Protocol v1 (protobuf) — `takproto/`

- `TakMessage { TakControl takControl = 1; CotEvent cotEvent = 2; }`
- `CotEvent`: type, access, caveat, releasableTo, qos, opex, uid, sendTime/startTime/staleTime (ms, uint64),
  how, lat, lon, hae, ce, le, detail.
- `Detail`: `xmlDetail` (metin) + tipli alanlar `Contact{endpoint,callsign}`, `Group{name,role}`,
  `PrecisionLocation{geopointsrc,altsrc}`, `Status{battery}`, `Takv{device,platform,os,version}`,
  `Track{speed,course}` + `ExtensionEncodedDetail{extensionId,data}`.
- `TakControl{minProtoVersion,maxProtoVersion,contactUid,extensionIds}`.

**Çerçeveleme:**
- Yerel ağ (UDP): `0xBF <varint sürüm> 0xBF <TakMessage>`. Her datagram tek mesaj.
- Akış (TCP/TLS): `0xBF <varint uzunluk> <TakMessage>`.
- Eski XML akışı: mesajlar `</event>` sonrasında bölünüyor; her mesaj `<?xml …?>` başlığı + yeni satırla başlıyor.
- Varint: protobuf'un işaretsiz varint'i (en fazla 10 bayt).

**Sunucu anlaşması** (`takproto/README.txt`):
1. Bağlantı XML ile başlar (gerekiyorsa ilk mesaj auth).
2. Sunucu `t-x-takp-v` + `<TakControl><TakProtocolSupport version="1"/></TakControl>` gönderir.
3. İstemci `t-x-takp-q` + `<TakRequest version="1"/>` ister ve ≥1 dk yanıt bekler.
4. Sunucu `t-x-takp-r` + `<TakResponse status="true"/>` → iki yön de protobuf akışına geçer.

**Yerel ağ sürüm seçimi:** Her cihaz ≥60 sn'de bir `TakControl` (min/max sürüm) yayınlar. Gönderim, bilinen tüm
kişilerin ortak desteklediği en yüksek sürümle yapılır. 2 dk `TakControl` göndermeyen kişi son gördüğü sürüme düşer.

### 5.3 Meshtastic `TAKPacket` (Faz 2 için birincil yol)

- Kaynak: `github.com/meshtastic/protobufs` → `meshtastic/atak.proto` (GPL-3.0).
- Mesajlar: `TAKPacket`, `GeoChat`, `Group`, `Team`, `MemberRole`, `Status`, `Contact`, `PLI`,
  `CotHow`, `CotType`, `GeoPointSource`, `AircraftTrack`, `CotGeoPoint`, `DrawnShape`, `Marker`…
- Eşlik eden eklenti: `github.com/meshtastic/ATAK-Plugin` (GPL-3.0).
- BLE UUID'leri ve bağlantı akışı: `faz2-brief.md` ve proje belleği `pusula-faz2-mesh`.

### 5.4 ATAK'tan çıkan tasarım kuralları (Pusula Faz 2 gereksinimleri)

1. Ağdan gelen veri **asla onaysız** ayar, bağlantı ya da sertifika değiştirmesin.
2. Silme/değiştirme komutları sadece kimliği doğrulanmış gönderenden ve sadece onun oluşturduğu nesneler için.
3. Gelen mesajlar uygulama içi aksiyon tetiklemesin (`onReceiveAction` benzeri bir şey olmasın).
4. Paylaşılan tek anahtara güvenme. Meshtastic kanal şifrelemesi + gönderen kimliği birlikte düşünülsün.
5. Dosya yollarında `..` / izin listesi temizliği (ATAK'ın zip slip koruması doğru örnek).
6. Ayrıştırıcılar (XML/protobuf) için bozuk/kötü niyetli girdi testleri.

---

## 6. Açık sorular / doğrulanacaklar

- [ ] (?) Commo TLS doğrulamasında EKU (sunucu amaçlı sertifika) kontrolü var mı? (`certChecker->checkCert`)
- [ ] (?) `onReceiveAction` ile tetiklenebilen iç Intent'lerin gerçek etkisi.
- [ ] (?) `tak.gov` cihaz kaydı / eklenti senkronu kullanıcı başlatmadan çalışıyor mu?
- [ ] (?) ATAK ↔ Meshtastic ↔ Pusula `TAKPacket` eşleşmesinin uçtan uca davranışı (donanım gerekli).
- [ ] (?) Mapbox SDK telemetri/MAU davranışı ve kapatma seçenekleri.
- [ ] (?) PAR video kütüphanelerinin tam decompile denetimi (sadece Pusula'da video düşünülürse).

---

## 7. Analizde kullanılan araçlar

- `git clone --depth 1` (LFS atlandı), dosya okuma/grep, Python ile manifest ayrıştırma.
- REA: `inspect_native_exports` (`libpgscmedia.so`, `libpgscmediajni.so`, arm64) + `strings` ile protokol/yapılandırma dizgeleri.
- GitHub API: `TAK-Product-Center/Server`, `mil-sym-android`, FreeTakServer, OpenTAKServer,
  `meshtastic/ATAK-Plugin`, `meshtastic/protobufs` varlık ve lisans kontrolü.

## 8. Yeniden üretme

```bash
mkdir -p ~/src && cd ~/src
GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/TAK-Product-Center/atak-civ.git
cd atak-civ && git log -1 --format='%H %cd'   # 9f6893d… bekleniyor (daha yenisi gelebilir)
```

En çok başvurulacak dosyalar:
- `takproto/README.txt` ve `takproto/*.proto` (protokol)
- `takcot/xsd/`, `takcot/examples/` (CoT şemaları ve örnekler)
- `commoncommo/core/include/commo.h` (ağ API'si)
- `atak/ATAK/app/src/main/java/com/atakmap/comms/CotService.java` (varsayılan giriş/çıkışlar)
- `atak/ATAK/app/src/common/java/com/atakmap/android/maps/MapComponentLoader.java` (bileşen listesi)
