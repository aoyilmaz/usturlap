# Harita motoru geçiş planı: flutter_map → Mapbox Maps SDK

> Durum: **taslak, onay bekliyor.** CLAUDE.md §2 ("v1'de ticari uydu yok") ve §3
> ("Harita: flutter_map") kararlarını değiştirir.

## Neden

- Hedef: Kerteriz'deki gibi **yüksek çözünürlüklü uydu**, z22'ye kadar kesintisiz
  zoom, **uygulama içinden bölge indirme** ve 3B arazi.
- Mapbox Satellite görüntüsünü **çevrimdışı** olarak yasal biçimde kullanmanın yolu
  Mapbox'ın kendi SDK'sındaki offline (TileStore / OfflineManager) özelliği.
  Kendi indiricimizle (FMTC vb.) toplu indirmek kullanım şartlarına aykırı.
- Mapbox SDK GPU'da (Metal/OpenGL) çizer: akıcı zoom/dönüş, vektör etiketler, 3B arazi.

## Paket

- `mapbox_maps_flutter` **3.34.1** (pub.dev, 2026-10-29). Flutter ≥ 3.38.1 ister.
- Token: public `pk.` token `--dart-define=MAPBOX_ACCESS_TOKEN` ile verilir (koda gömülmez).
  iOS indirme için ayrıca `.netrc` içinde **secret `sk.` token (DOWNLOADS:READ)** gerekebilir.
  Kurulumda doğrula.
- Maliyet: Mapbox mobil SDK aylık aktif kullanıcıya (MAU) göre ücretlendirilir ve
  ücretsiz bir kotası vardır. Güncel fiyat ve offline limitleri başlamadan kontrol et.

## Ne değişir, ne kalır

| Kalır (dokunulmaz) | Yeniden yazılır (harita katmanı) |
|---|---|
| domain/ (modeller, ports, LOS hesabı) | `features/map/map_screen.dart` (1273 satır) |
| data/db (drift), import/export, HGT | işaretçiler → `PointAnnotation` / SymbolLayer |
| konum, pusula, Kalman, HUD widget'ları | çizgiler/alanlar → GeoJSON source + Line/Fill layer |
| providers (riverpod) | LOS overlay, NATO sembolleri (görüntüye çevirip layer'a) |
|  | MBTiles/PMTiles katmanları (aşağıya bkz.) |

**Kendi MBTiles/PMTiles dosyalarımız:** Mapbox SDK bunları doğrudan okumaz. Seçenekler:
(a) uygulama içinde küçük bir yerel karo sunucusu (localhost) üzerinden raster/vector
source olarak vermek, (b) bu katmanlar için flutter_map'i ikincil ekran olarak tutmak.
Önerim (a). Önce bir prototiple doğrulanmalı.

## Adımlar (her biri çalışır halde bırakılır)

1. **Spike (1-2 gün):** Ayrı bir ekranda `MapWidget` + `satellite-streets-v12` + kendi
   konum göstergesi. iPhone'da zoom kalitesi ve kurulum (token, Podfile) doğrulanır.
   → Karar noktası: devam / dur.
2. **Harita adaptörü:** `features/map/engine/` altında ince bir arayüz (kamera, katman
   ekle/kaldır, dokunma/uzun basma olayları). map_screen bu arayüzü kullanır; motor
   değişimi tek noktadan olur.
3. **Katmanlar:** waypoint, iz, ölçüm/çizim grafikleri, nav çizgisi → GeoJSON source'lar.
4. **Uygulama içi bölge indirme:** ekranda görünen alanı çerçevele → isim ver →
   boyut/alan tahmini ve uyarı → ilerleme çubuğu → indirilen bölgeler listesi / silme.
   Stil paketi ve karo bölgesi `OfflineManager` + `TileStore` ile indirilir.
   Zoom aralığı seçilebilir (ör. "keşif z10-14" / "detay z10-18").
5. **3B arazi + gökyüzü** (Mapbox DEM), gece/kızıl stil.
6. **Kendi MBTiles/PMTiles** katmanlarının yeni motora bağlanması.
7. **LOS overlay ve NATO sembolleri** taşınır. flutter_map bağımlılıkları kaldırılır
   (ayrı onayla).

## Riskler

- Yeniden yazım büyük: en çok map_screen ve overlay'ler etkilenir. 2. adımdaki adaptör bu riski azaltır.
- Mapbox'a bağımlılık ve maliyet. Alternatif (MapLibre + lisanslı uydu sağlayıcısı)
  aynı adaptörle ileride mümkün kalır.
- Offline pack/TileStore limitleri ve şartları: bölge boyutu tahmini ve sınırı uygulamada gösterilmeli.
