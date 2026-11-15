<p align="center">
  <img src="assets/icon/usturlap_logo.svg" width="112" alt="Usturlap logosu">
</p>

# Usturlap

İnternet ve baz istasyonu olmadan çalışan, tek elle (eldivenle de) kullanılan kişisel
**taktik harita** uygulaması. Flutter ile yazıldı; Android ve iPhone.
Hesap yok, reklam yok; uygulama kendi adına veri toplamaz, bütün veri cihazda kalır.
Harita karoları Mapbox'tan gelir; Mapbox'ın isteğe bağlı telemetrisi kapalı başlar
(bkz. [gizlilik](website/gizlilik.html)).

> Proje önce **Pusula**, sonra **Kerteriz** adını taşıdı. Eski dosyalar açılmaya devam
> etsin diye bazı görünmez biçim kimlikleri eski adla kalır (KML/GeoJSON `kerteriz`
> verisi, CoT `__kerteriz` / `__pusula` öğeleri, `.krz` yedek biçimi).

## Kurulum

- **Android:** [son sürümün APK'sı](https://github.com/aoyilmaz/usturlap/releases/latest/download/usturlap.apk)
  ([bütün sürümler](https://github.com/aoyilmaz/usturlap/releases)). Telefonda indirip açın;
  adım adım anlatım: https://aoyilmaz.github.io/usturlap/#kurulum
- **iPhone:** App Store'a yakında. Şimdilik yalnız kaynak koddan, kendi Apple hesabınızla.

## Özellikler

- **Harita:** Mapbox Uydu / Sokak / Topografik, OpenStreetMap, OpenTopoMap. Çevrimdışı
  kullanım için bölge indirme (harita türü seçerek) ve kendi **MBTiles / PMTiles /
  GeoPackage** katmanlarınız. Kaydedilmiş görünümler, gece modu, yatay ekran.
- **Konum ve navigasyon:** MGRS / UTM / WGS84 / DM / DMS; coğrafi, manyetik (WMM2025)
  ya da grid kuzeyi; derece ya da mil. "Git" (düz hatta kerteriz + mesafe), rotalar ve
  rota takibi, taktik pusula, canlı takip, geriden kestirme, elle konum girme.
- **Ölçüm ve arazi:** mesafe-kerteriz çizgisi, menzil halkaları, bullseye; yükseklik
  verisiyle (HGT) yükseklik profili, görüş alanı, eş yükselti ve eğim.
- **İşaretleme ve çizim:** askerî semboller (APP-6), görev noktaları, görüş konisi;
  alan, çizgi, daire, dikdörtgen, serbest çizim, 3B kutu; şekil düzenleme, lasso seçimi,
  geofence (sesli uyarı ve arka plan bildirimi), noktalara fotoğraf ve galeri.
- **Veri ve paylaşım:** KML / KMZ / GPX / GeoJSON içe ve dışa aktarma, TAK uyumlu CoT
  veri paketi, AirDrop ya da Dosyalar'dan "Usturlap ile aç".
- **Saha:** iz kaydı (ekran kapalıyken de), raporlar (9 satır vb.), güneş ve ay,
  hava durumu (Open-Meteo, isteğe bağlı), pil alarmı, ekranı açık tutma.
- **Gizlilik ve güvenlik:** parolayla şifreli yedek (PBKDF2 + AES-GCM), içeriği hızlı
  silme.

## Yol haritası

**Faz 2: Mesh (Meshtastic).** İnternetsiz ekip ağı: BLE ile Meshtastic düğümüne
bağlanma, ekip konumlarını haritada görme, mesh üzerinden kısa mesaj ve nokta / veri
paketi paylaşma. Mimari buna hazır (`PositionSource` / `CommsChannel` arayüzleri); bkz.
[`docs/faz2-brief.md`](docs/faz2-brief.md).

## Tanıtım sitesi

`website/` (statik, derleme yok) → https://aoyilmaz.github.io/usturlap/ (GitHub Actions,
`.github/workflows/pages.yml`). Ekran görüntüleri ve videolar simülatörde demo verisiyle
üretilir: `python3 tool/capture_site_media.py` (`integration_test/showcase_test.dart`).
Yerelde bakmak için: `python3 -m http.server -d website`.

## Mimari

`presentation (features/) → domain (models, ports, usecases) → data (db, tiles,
position, …)`, Riverpod ile. Domain saf Dart; veritabanı `drift` (SQLite).

## Kaynak koddan derleme

Geliştiriciler için; uygulamayı kullanmak için gerekmez.

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json   # bağlı iOS/Android cihaz
```

- `dart_defines.json` repoda yoktur; içine kendi Mapbox **genel** anahtarınızı koyun:
  `{"MAPBOX_ACCESS_TOKEN": "pk..."}` (Mapbox hesabı → Tokens).
- **iOS:** Xcode imzalaması gerekir (`ios/Runner.xcworkspace`, paket kimliği `com.aoyilmaz.usturlap`).
- **Android:** JDK 17 ve Android SDK. Sürüm derlemesi `android/key.properties` varsa onunla,
  yoksa debug anahtarıyla imzalanır: `flutter build apk --release --dart-define-from-file=dart_defines.json`.
- Geliştirme: `flutter analyze` · `flutter test`.

## Sürüm yayınlama (Android)

1. `pubspec.yaml`'daki `version`'ı artırın (ör. `1.0.1+2`; `+N` her yayında büyümeli).
2. Etiketleyip gönderin: `git tag v1.0.1 && git push origin v1.0.1`.
3. GitHub Actions (`.github/workflows/android-release.yml`) APK'yı derler, imzalar ve
   Releases'e koyar. `-` içeren etiketler (ör. `v1.0.1-rc1`) ön sürüm olur.

İmza anahtarı (`usturlap-release.jks`) ve parolaları GitHub secret'larında ve
`android/key.properties`'te durur. **Yedeklenmeli:** kaybolursa mevcut kurulumlar
güncellenemez.

Çevrimdışı karo dosyaları (`.mbtiles` / `.pmtiles`) büyük olduğu için repoda değildir;
uygulama içinden içe aktarılır ya da `assets/tiles/` altına konur.

Uygulama ikonu `assets/icon/usturlap_icon.svg` kaynağından üretilir:
`python3 tool/render_icons.py` (Chrome + Pillow).

## Lisans

Kişisel proje; şu an bir lisans verilmemiştir.
