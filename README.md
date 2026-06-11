# Pusula

Çevrimdışı öncelikli (offline-first), tek elle kullanılabilen kişisel **taktik
harita** uygulaması (Flutter, iOS öncelikli). İnternet/baz istasyonu olmadan
çalışır; tüm veri cihazda kalır (hesap yok, telemetri yok).

## Özellikler (Faz 1 — tamamlandı)

- **Harita katmanları:** çevrimiçi OSM + gömülü çevrimdışı **MBTiles** (sokak/uydu/
  topografik) + **vektör PMTiles** (Protomaps, her zoom'da keskin). Katman seçilince
  kapsama alanına otomatik gider; büyük katmanlar tembel yüklenir.
- **HUD:** callsign (düzenlenebilir), koordinat (**MGRS / UTM / WGS84** — çift dokunarak
  geçiş), kerteriz, hız, yükseklik.
- **Konum & pusula:** GPS + manyetik kerteriz, kuzey-yukarı / track-up, takip.
- **Waypoint'ler:** uzun bas → ekle, SQLite (`drift`) ile kalıcı, MGRS, listele/sil.
- **İz kaydı:** başlat/durdur, canlı polyline, KML/GeoJSON dışa aktarım; ekran kapalıyken
  de kayıt (yalnızca kayıt sırasında arka plan konumu) + GPS doğruluk filtresi.
- **Ölçüm/çizim araçları:** mesafe, alan (poligon), sektör.
- **Gece modu**, haptik geri bildirim, sade tek-kolon buton düzeni.

> Faz 2 (Meshtastic mesh) için mimari hazır (`PositionSource` / `CommsChannel`
> arayüzleri); bkz. [`docs/faz2-brief.md`](docs/faz2-brief.md).

## Mimari

`presentation (features/) → domain (models, ports) → data (db, tiles, position)`,
Riverpod ile. Domain saf Dart (test edilebilir).

## Çevrimdışı karolar (önemli)

`.mbtiles` / `.pmtiles` dosyaları **büyük olduğundan repoya dahil değildir**
(`.gitignore`). Bunları ayrı **`pusula-tiler`** aracıyla (Sentinel-2 uydu, Copernicus
DEM topo, WMS ortofoto, XYZ, Protomaps vektör) üretip, `lib/features/map/base_layer.dart`
içindeki `assetPath` adlarıyla `assets/tiles/` altına koyun. Karolar olmadan yalnızca
"çevrimiçi OSM" katmanı çalışır.

## Çalıştırma

```bash
flutter pub get
flutter run            # bağlı bir iOS/Android cihazda
```

iOS'ta cihaza kurmak için Xcode imzalaması gerekir (kendi Apple ID'niz; `ios/Runner.xcworkspace`).
Geliştirme: `flutter analyze` · `flutter test`.

## Lisans

Kişisel proje.
