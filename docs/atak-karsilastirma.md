# ATAK-CIV ↔ Pusula özellik karşılaştırması

> Kaynak: **ATAK Civilian Kullanım Kılavuzu v4.5** (22 Kasım 2021, 60 sayfa),
> tüm bölümleri. Pusula durumu: 2026-11-05, Aşama B (navigasyon) + yatay düzen
> dahil. Seviyeler kodun kendisinden doğrulandı.
>
> **Ek kaynak (2026-11-05):** kullanıcının verdiği "çekirdek ATAK özellikleri"
> listesi. Bu listeden gelen ve kılavuzda **geçmeyen** satırlar `(liste)` ile
> işaretli; ATAK'ta gerçekten bulunduğu doğrulanmadı (WMS/WMTS, .tpk,
> MIL-STD-2525 kütüphanesi, KBRN/patlama alanı, buluşma noktası, multicast
> sohbet, TAK Server istemcisi).
>
> **Kaynak kod analizi (2026-11-05):** [atak-civ-teknik-analiz.md](atak-civ-teknik-analiz.md)
> — ATAK-CIV 5.5.1.10 kaynak + REA incelemesi. `(liste)` satırlarından şunlar kodda
> doğrulandı: MIL-STD-2525 kütüphanesi (mil-sym), multicast sohbet (224.10.10.1:17012),
> TAK Server istemcisi (TLS 8089 / QUIC 8090). WMS/WMTS, .tpk ve KBRN hâlâ doğrulanmadı.
>
> **Seviye:** ✅ ATAK düzeyinde · 🟢 iyi (ana işlev var, ATAK'ın ek seçenekleri
> yok) · 🟡 kısmi/ilkel · ⬜ yok · ➖ kapsam dışı (TAK Server, video, telsiz…)

## Özet

| | Adet |
|---|---|
| ✅ ATAK düzeyinde | 6 |
| 🟢 İyi | 13 |
| 🟡 Kısmi | 18 |
| ⬜ Yok | 37 |
| ➖ Kapsam dışı | 8 (tabloda 2 + §8'de 6 grup) |

**Pusula'nın ATAK'tan iyi olduğu yerler:** uygulama içi bölge indirmede gerçek
boyut tahmini, gece modunda haritanın kendisinin karartılması, tek elle/eldivenle
kullanım (artı imleç + büyük alt çubuk), Türkçe ve MGRS odaklı koordinat girişi,
Türkiye telsiz röleleri.

---

## 1. Harita ve görünüm

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| Harita katmanları, Maps & Favorites (21) | Çevrimiçi/çevrimdışı harita kaynakları | Mapbox uydu (z22), OSM, Topo, kendi MBTiles/PMTiles | 🟢 | Harita kaynağı XML ekleme (MOBAC) yok |
| Özel çevrimiçi kaynak: WMS/WMTS/XYZ (liste) | Kendi harita sunucusunu ekleme | — | ⬜ | Kılavuzda yalnızca WFS var. Google/Esri karolarını çevrimdışı toplamak lisans gereği yasak; kamu ortofoto WMS'i gibi kaynaklar çevrimiçi eklenebilir |
| Çevrimdışı görüntü biçimleri (51) | GeoPackage, GeoTIFF, KMZ (görüntülü), CADRG/CIB, MrSID… | MBTiles, PMTiles | 🟡 | GeoPackage ve GeoTIFF en değerlileri; .tpk (Esri) kılavuzda yok |
| Saving a Map Layer (21–22) | Ekrandaki alanı çevrimdışı indir | Çevrimdışı haritalar: çerçevele, detay seç, boyut tahmini | ✅ | ATAK'tan iyi: gerçek boyut tahmini |
| Bookmarking a Location (22) | Kayıtlı görünümler / favori konum | — | ⬜ | |
| WFS Support (22) | Web Feature Service katmanı | — | ➖ | Sunucu gerektirir |
| Overlay Manager (23) | Katman/nesne gruplarını aç-kapa | Taban katman seçimi + röleler aç/kapa | 🟡 | Nokta/iz/grafik gruplarını gizleme yok |
| Elevation Data (25) | DTED/SRTM yükleme | Mapbox DEM (3B) + tek gömülü HGT (görüş hattı) | 🟡 | Kullanıcı yükseklik dosyası ekleyemiyor |
| 3D View (6) | Arazi 3B, eğim kilidi | 3B düğmesi (DEM ×1.5, 60°) + iki parmakla eğim | 🟢 | Eğim kilidi ve ayrı kabartma (hillshade) katmanı yok |
| 3D Models (7) | OBJ model içe aktarma | — | ⬜ | |
| First Person View (7) | Yer seviyesinden bakış | — | ⬜ | |
| Map Controls (26) | Zoom düğmeleri, ölçek | Parmakla zoom; ölçek çubuğu kapalı | 🟡 | Ölçek çubuğu açılmalı |
| Gece / NVG (genel) | Karanlık mod | Gece stili: uydu siyah-beyaz + kırmızı yazılar | ✅ | |

## 2. Pusula, konum, kendi işaretçin

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| Compass: North Up / Track Up (6) | Kuzey-yukarı / yön-yukarı | [N] düğmesi | ✅ | |
| Manual Orientation + Lock (6) | Elle döndür, kilitle | Elle döndürme var | 🟡 | Kilit yok |
| Self-Marker (8) | Yönlü ok, konuma kilitle | Yönlü ok, takip (◎) | 🟢 | |
| Self radial: GPS Error Overlay | Doğruluk dairesi | Doğruluk yalnızca HUD'da (±m) | 🟡 | Haritada daire yok |
| Self radial: Compass Overlay | Konum etrafında pusula gülü | — | ⬜ | |
| Self radial: Tracking Breadcrumbs | Geçilen yol izi | İz kaydı (başlat/durdur, canlı çizgi) | 🟢 | Kayıt dışı "son 15 dk izi" yok |
| Self radial: Fine Adjust / Polar Entry | GPS yokken konumu elle düzelt | — | ⬜ | GPS'siz kullanım için önemli |
| Açı birimleri (13) | Derece/mil, gerçek/manyetik/grid | Yalnızca derece | 🟡 | **Manyetik sapma yok**: pusula manyetik, hesaplar gerçek kuzey |
| Koordinat biçimleri (39) | MGRS, DD, DM, DMS, UTM, adres | Gösterim: MGRS/UTM/ondalık (HUD'a çift dokunuş); giriş: MGRS/UTM/ondalık/DMS | 🟢 | DMS/DM gösterimi yok; adres araması çevrimdışı yapılamaz |
| Kerteriz kilidi / azimut modu (liste) | Pusulayla hedef yönünü sabitleyip izleme | Pusula sensörü var, taktik pusula ekranı yok | ⬜ | Yol haritasında: [N]'ye uzun basınca taktik pusula |

## 3. Nokta / işaretçi

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| Point Dropper (9–10) | Hızlı işaretçi (dost/düşman/nötr/bilinmeyen) | Uzun basma veya artı imleç + "+"; APP-6 çerçeve, kademe, rol | 🟢 | Tek dokunuşta tür seçerek bırakma yok |
| Askeri sembol kütüphanesi, MIL-STD-2525 (liste) | Standart sembollerin tam seti | APP-6: 4 çerçeve, 4 kademe (takım–tabur), 4 rol (piyade, zırhlı, topçu, keşif) | 🟡 | Kılavuzdaki çekirdek ATAK'ta da yalnızca 4 temel çerçeve var (s.9). Şüpheli/varsayılan dost, mayın, engel yok |
| Tehlike alanları: KBRN, patlama yarıçapı (liste) | Hazır tehlike bölgesi şablonları | Renkli alan + menzil halkasıyla elle çizilebiliyor | 🟡 | Hazır şablon (KBRN rüzgâraltı, patlama güvenlik mesafesi) yok |
| Koordinatla nokta (9) | Elle koordinat girip nokta | Koordinat sekmesi → Kaydet | ✅ | |
| Ad öneki + sıra no (9) | "OP-1, OP-2…" otomatik ad | — | ⬜ | |
| Sensor / FOV işaretçisi (9) | Görüş konisi yön/menzil | — | ⬜ | Gözetleme noktası için değerli |
| Vehicle Models (9) | Ölçekli araç modeli | — | ⬜ | |
| Recent points (10) | Son bırakılanlar listesi | Noktalar listesi | 🟢 | |
| Radial Menu (11) | İşaretçiye dokununca hızlı eylemler | Detay sayfası: Ortala, Git, Düzenle, Paylaş, Sil | 🟡 | R&B çizgisi, tehdit halkası, kilitlenme yok |
| Details (11) | Ad, tür, not, yükseklik, ek dosya/foto | Ad, not, APP-6 alanları | 🟡 | Yükseklik ve fotoğraf eki yok |
| Custom Threat Rings (8, 11) | İşaretçi etrafında menzil halkaları | Menzil halkası aracı (bağımsız) | 🟡 | İşaretçiye bağlanmıyor, kaydedilmiyor |

## 4. Ölçüm ve navigasyon

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| R&B Line (12) | İki nokta arası mesafe + kerteriz | Mesafe aracı (2 nokta): mesafe, kerteriz, ters kerteriz | 🟢 | Kalıcı/etiketli değil, eğim açısı yok |
| Dynamic R&B Line (12) | Uçları sürüklenebilir çizgi | — | ⬜ | |
| R&B Circle (13) | Yarıçaplı halka | Menzil halkası (R, 2R, 3R) | 🟢 | Kaydedilemiyor |
| Bullseye (14) | Referans noktaya göre kerteriz/mesafe ızgarası | — | ⬜ | |
| Routes (15–16) | Kontrol noktalı rota planla | Rota planla, kaydet, listele | 🟢 | Ters çevirme, nokta adı, rota GPX dışa aktarma yok |
| Navigation / Route Mode (18–19) | Rota boyunca adım adım | Takip paneli: ayak, sapma, kalan, kerteriz, varış, oto ilerleme | ✅ | Sesli uyarı yok |
| Navigation Flag / Red X (17) | Haritada "buraya git" işareti | Artı imleç + Koordinat → Git | 🟢 | |
| Go To (39) | Koordinata git | Koordinat sekmesi: MGRS/UTM/DMS → Göster | ✅ | |
| Bloodhound (18) | Takipçi→hedef canlı mesafe/kerteriz/ETA | Hedef şeridi: kerteriz, mesafe, dönüş, ETA | 🟢 | Tek hedef; iki nesne arası ve renkli ETA eşikleri yok |
| Multiple Bloodhounds (19) | Aynı anda çok hedef | — | ⬜ | |
| Buluşma noktası / rendezvous (liste) | Ekiplerin aynı anda varması için zaman/hız hesabı | — | ⬜ | Tek kişide de işe yarar: "saat 06:00'da X'te olmak için gereken hız" |
| Resection Tool (50) | Bilinen noktalara kerterizle konum bul (GPS'siz) | — | ⬜ | |
| Digital Pointer (47) | Ekibe "şuraya bak" işaretçisi | — | ⬜ | Faz 2 (mesh) |

## 5. Çizim ve veri yönetimi

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| Drawing Tools / Create a Shape (40–41) | Çizgi, alan, daire, dikdörtgen, renk | Çizgi + alan (renkli, kalıcı), sektör (geçici) | 🟡 | Daire/dikdörtgen kaydı yok |
| Telestrate (42) | Parmakla serbest kroki | — | ⬜ | |
| 3D Shapes (42) | Yükseklikli şekiller | — | ⬜ | |
| Geofencing (43) | Alana giriş/çıkış uyarısı | — | ⬜ | |
| Lasso Tool (44) | Alan seçip toplu işlem | — | ⬜ | |
| Hashtags / Sticky Tags (24) | Etiketle, filtrele | — | ⬜ | |
| Multi-Select Export & Delete (25) | Toplu dışa aktar/sil | — | ⬜ | |
| Track History (46) | Geçmiş izler | İz listesi: göster, paylaş, sil | 🟢 | |
| Track Search (46) | İzlerde tarih/ad araması | — | ⬜ | |
| Import Tool (51) | Katman dosyaları: KML/KMZ/GPX/SHP/DRW/LPT (görüntü biçimleri §1'de) | GPX/KML (nokta+iz) | 🟡 | KMZ ve SHP yok |
| Dışa aktarma (16, 25) | KML/KMZ/GPX/SHP, rota KML/GPX | İz: KML/GeoJSON; nokta: paylaş | 🟡 | GPX, KMZ, SHP, rota ve toplu dışa aktarma yok |
| Rubber Sheet (52) | Fotoğraf/paftayı haritaya oturt | — | ⬜ | |
| Quick Pic / Gallery (45) | Konumlu fotoğraf, galeri | — | ⬜ | |
| File Editing (26) | Dosyaları düzenle | — | ➖ | |
| Data Package Tool (29–30) | Görev paketini (zip) paylaş/al | — | ⬜ | |
| Clear Content (58) / panik düğmesi | **Acil veri silme**: harita, mesaj, sertifika, tüm içerik | — | ⬜ | Taktik açıdan önemli |
| Şifreli veri (5) | Cihazdaki veriyi parola ile şifrele | — | ⬜ | Veritabanı şifresiz |

## 6. Arazi analizi

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| Elevation Tools (48) | Profil, eğim, ısı haritası | Görüş hattı profili (iki nokta) | 🟡 | Rota/çizgi boyunca profil, eğim haritası yok |
| Viewshed (48) | 360° görülen/görülmeyen alan | Tek hat görüş hattı (LOS) | 🟡 | Alan analizi yok |
| Contour Lines (49) | Eş yükselti eğrileri | — | ⬜ | Topo katmanında hazır eğriler var ama analiz yok |

## 7. Ekip, haberleşme, rapor (Faz 2 ağırlıklı)

| ATAK (s.) | Ne yapar | Pusula | Seviye | Not / eksik |
|---|---|---|---|---|
| Contacts (31–32) | Ekip listesi, roller, renkler | Mimari hazır (PositionSource) | ⬜ | Faz 2 |
| GeoChat (32–34) | Grup sohbeti, konumlu mesaj | Mimari hazır (CommsChannel) | ⬜ | Faz 2 |
| Encrypted Mesh Comms (35) | Şifreli mesh | — | ⬜ | Faz 2 (Meshtastic) |
| Team PLI (8) | Kendi konumunu yayınlama + ekip üyelerinin konumu, rol harfleri | — | ⬜ | Faz 2 |
| Cursor on Target, CoT (9) | ATAK'ın XML mesaj biçimi: konum, işaretçi alışverişi | — | ⬜ | Faz 2 açık kararı. Meshtastic'in ATAK eklentisi CoT taşıyor; Pusula CoT konuşursa ATAK/iTAK kullanıcılarıyla çalışır |
| Yerel ağ / multicast (liste) | Sunucusuz, aynı Wi-Fi'daki cihazları bulma ve mesajlaşma | — | ⬜ | `CommsChannel`'ın ikinci uygulaması olabilir; Meshtastic donanımı gelmeden ekip testi için kolay yol |
| Alert (53) | Acil durum: 911, Ring the Bell, TIC | — | ⬜ | Faz 2; yerel SOS bile yok |
| CASEVAC 9-line (20) | Tahliye talebi formu | — | ⬜ | Tek başına da yararlı (paylaş/kopyala) |
| Paylaşım / Send (11) | İşaretçiyi ekibe gönder | Paylaş (iOS paylaşım menüsü) | 🟡 | Ağ üzerinden gönderme yok |

## 8. Kapsam dışı (şimdilik)

Radio Controls + PRC-152 (27) · Rover Controls (28) · Video Player, akış
ekleme/indirme, KLV, canlı video haritada (36–38) · TAK Package Management (54)
· Plug-in kurulumu (59–60) · WFS (22) · File Editing (26) · TAK Server
istemcisi ve sertifikalı bağlantı (liste).
**Toolbar Manager (55–57)** sonradan değerlendirilebilir (kişiye göre araç
çubuğu).

---

## Öncelik önerisi (yol haritasına işlenecek)

**Hemen (küçük, yüksek değer):**
1. Manyetik sapma (gerçek ↔ manyetik kerteriz, mil seçeneği), haritada GPS
   doğruluk dairesi, ölçek çubuğu, DMS gösterimi.
2. İşaretçiye dokununca hızlı eylemler (Git, R&B çizgisi, tehdit halkası,
   kilitlen); nokta yüksekliği; otomatik ad öneki (OP-1, OP-2…).
3. **Acil veri silme** (Clear Content); menzil halkasını kaydetme ve işaretçiye
   bağlama.

**Sonra:**
4. Arazi: viewshed, rota boyunca profil, kontur, resection.
5. Veri: Quick Pic, etiketler + Overlay Manager (grup gizle), toplu dışa
   aktarma, GPX dışa aktarma, görev paketi.
6. Çizim: daire/dikdörtgen kaydı, telestrate, geofence.
7. Bullseye, çoklu bloodhound, sensör FOV, CASEVAC formu, buluşma noktası
   hesabı, taktik pusula (kerteriz kilidi).
8. Harita: GeoPackage/GeoTIFF içe aktarma, özel WMS kaynağı.

**Faz 2:** ekip, sohbet, acil durum yayını, CoT uyumu; mesh'ten önce
denemek için Wi-Fi yerel ağ kanalı.
