# Pusula yol haritası: Kerteriz menü yapısı + ATAK özellikleri

> Durum: **taslak, tartışma için** (2026-11-04). Harita motoru geçişi tamamlandı
> (bkz. `harita-motoru-gecis-plani.md`). Bu belge sıradaki işleri sıralar.
>
> Kaynaklar: Kerteriz Taktik GPS (App Store sayfası, ekran görüntüleri, paket
> incelemesi) · ATAK-CIV Kullanım Kılavuzu v4.5 (22 Kasım 2021, içindekiler) ·
> iTAK App Store sayfası. ATAK'tan **fikir** alınır; kod/ikon/metin kopyalanmaz.

İşaretler: ✅ Pusula'da var · 🟡 kısmen var · ⬜ yok · Efor: S (≤1 gün) · M (2–4 gün) · L (1 hafta+)

---

## 1. Menü yapısı (Kerteriz tarzı)

Kerteriz'in beğenilen düzeni: **üstte genişleyen bilgi şeridi**, **ortada artı
imleç**, **sağda harita kontrolleri**, **altta 5 sekmeli çubuk + ortada büyük
İntikal düğmesi**. İşlem modlarında (rota çizme) alt çubuk o moda özel
düğmelere dönüşür.

Pusula'nın bugünkü hali: tek sütun FAB + tek büyük "Menü" sayfası + uzun basma.

### Önerilen düzen

```
┌──────────────────────────────────────────┐
│ KERTERIZ-1   37S DB 12345 67890   ⛰ 845m │  ← HUD (dokun: genişle)
│ ▾ UTM · WGS84 · hız · GPS ±m · yön · hava│     genişleyince
├──────────────────────────────────────────┤
│                                     [⚙] │  ← ayarlar
│                                     [▤] │  ← katmanlar
│                 ┼                   [3B]│  ← artı imleç (eldivenle
│                                     [+] │     nokta koymak için)
│                                     [◎] │  ← konum / takip
│                                     [N] │  ← kuzey / yön-yukarı
├──────────────────────────────────────────┤
│ Koordinat  Araçlar  ( ● İz )  Rota  Görevler │  ← alt çubuk
└──────────────────────────────────────────┘
```

| Sekme | İçerik |
|---|---|
| **Koordinat** | MGRS/UTM/WGS84 parça parça giriş, yer adı arama, "Konumumu kullan", **Git & yön bul**, **Nokta kaydet** (Kerteriz) |
| **Araçlar** | Mesafe, alan, sektör, görüş hattı (✅ var) + R&B çizgi/daire, bullseye, viewshed, resection (aşağıda) |
| **● İz** (orta, büyük) | Kayıt başlat/durdur; başlatırken ad + **otomatik durdurma** (1/2/4 sa) (Kerteriz) |
| **Rota** | Rota planla (alt çubuk: Geri al · Temizle · **+ Nokta** · Kaydet · Çık) + rota takip paneli |
| **Görevler** | Sekmeler: Noktalar · İzler · Grafikler · Bölgeler (çevrimdışı) · Paketler; ara/filtrele, git, sil, dışa aktar |

Ayarlar (⚙): gece modu, callsign, koordinat biçimi, doğruluk filtresi,
röleler, çevrimdışı test, hakkında. **Uzun basma** korunur (hızlı nokta), ama
artı imleç + "+" eldivenle de çalışır.

> Karar: alt çubukta **Araçlar**; taktik pusula sağdaki [N] düğmesine uzun
> basınca açılır.

---

## 2. Kerteriz'den alınacaklar

| Özellik | Durum | Efor | Not |
|---|---|---|---|
| Genişleyen HUD (UTM, ondalık, hız, GPS ±, yön, hava) | 🟡 HUD var, genişleme yok | S | |
| Artı imleç + "+" ile nokta | ⬜ | S | uzun basmaya ek |
| Koordinat girişi (parçalı MGRS, Git & yön bul) | ⬜ | M | |
| 10 tür mevki işareti, not + fotoğraf | 🟡 NATO sembolleri var, foto yok | M | foto = Quick Pic |
| Rota planlama + takip paneli (ayak n/N, kalan, kerteriz, ETA, sapma) | 🟡 tek hedef navigasyonu var | L | |
| İz otomatik durdurma, düşük pil uyarısı, ekranı açık tut | ⬜ | S | |
| Işık & gökyüzü: BMNT/EENT, gün doğumu/batımı, ay evresi | ⬜ | S | cihazda hesap, internetsiz |
| Taktik pusula (rota kilidi, sapma kalibrasyonu) | 🟡 pusula var, ekran yok | M | |
| METOC hava (sıcaklık, rüzgâr, nem) | ⬜ | M | **Open-Meteo ücretsiz plan ticari kullanıma kapalı** |
| PDF görev raporu, GPX dışa aktarma | 🟡 KML/GeoJSON var | M | |
| Yedekle / geri yükle (tüm veri) | ⬜ | S | |

## 3. ATAK'tan entegre edilebilecekler

Pusula **tek kişi + çevrimdışı** (Faz 1) ve **mesh ekip** (Faz 2) hedefliyor.
TAK Server, video/KLV, telsiz kontrolü, WFS ve eklenti sistemi kapsam dışı.

### 3a. Navigasyon ve ölçüm

| ATAK aracı | Ne yapar | Pusula | Efor |
|---|---|---|---|
| Range & Bearing **Line** | İki nokta/nesne arası kalıcı mesafe + kerteriz çizgisi | 🟡 ölçüm geçici | S |
| Range & Bearing **Circle** | Merkezden yarıçaplı halka(lar) — menzil halkası | ⬜ | S |
| **Bullseye** | Referans noktadan kerteriz/mesafe ızgarası (pozisyon bildirimi) | ⬜ | M |
| **Bloodhound** | Takipçi ↔ hedef canlı mesafe/kerteriz/ETA; hareketli hedef olabilir | 🟡 konum→hedef çizgisi | S |
| **Routes / Navigation** | Kontrol noktalı rota, adım adım navigasyon, arazi profiliyle | 🟡 | L |
| **Navigation flag / Red X** | Haritada geçici "buraya git" işareti | 🟡 | S |
| **Point Dropper** | Tek dokunuşla hızlı nokta (tür seçerek) | 🟡 uzun basma | S |
| **Go To** | Koordinat/nesneye git | ⬜ | S (Koordinat sekmesi) |

### 3b. Arazi analizi (Pusula'nın güçlü olabileceği alan)

| ATAK aracı | Ne yapar | Pusula | Efor |
|---|---|---|---|
| **Viewshed** | Bir noktadan 360° görülen/görülmeyen alan haritası | 🟡 tek hat LOS var | M |
| **Elevation Tools** / profil | Çizgi/rota boyunca yükseklik profili, eğim | 🟡 LOS profili var | S |
| **Contour Lines** | Yükseklik verisinden eş yükselti eğrileri | ⬜ | M |
| **Resection** | Bilinen 2–3 noktaya kerteriz alarak **GPS'siz** kendi konumunu bulma | ⬜ | M |
| **Elevation Data** (DTED/SRTM) yönetimi | Yükseklik dosyası indir/içe al | 🟡 tek HGT gömülü | M |

### 3c. Çizim ve veri yönetimi

| ATAK aracı | Ne yapar | Pusula | Efor |
|---|---|---|---|
| Drawing Tools (daire, dikdörtgen, serbest) | Şekil çizme | 🟡 çizgi/alan | S |
| **Telestrate** | Parmakla serbest çizim (hızlı kroki) | ⬜ | S |
| **Geofencing** | Alana giriş/çıkışta uyarı (titreşim/ses) | ⬜ | M |
| **Lasso** + Multi-Select Export/Delete | Alan seçip toplu dışa aktar/sil | ⬜ | M |
| **Hashtags / Sticky Tags** | Nesnelere etiket, etikete göre filtre | ⬜ | S |
| **Overlay Manager** | Katman/nesne gruplarını aç-kapa | 🟡 katman menüsü | M |
| **Maps & Favorites / Bookmark** | Kayıtlı görünümler, hızlı geçiş | ⬜ | S |
| **Track History / Search** | İz geçmişi, tarih/ada göre arama | 🟡 iz listesi | S |
| **Import Tool** (KML/KMZ/GPX/SHP/GeoTIFF) | Geniş format desteği | 🟡 GPX/KML, MBTiles/PMTiles | M |
| **Rubber Sheet** | Kâğıt pafta fotoğrafını haritaya oturtma | ⬜ | L |
| **Quick Pic / Gallery** | Konum etiketli fotoğraf, galeri | ⬜ | M |
| **Data Package** | Noktalar+izler+grafikler+fotoğrafları tek paket (zip) olarak paylaş/içe al | ⬜ | M |

### 3d. Raporlar ve ekip (Faz 2 — mesh ile)

| ATAK aracı | Ne yapar | Pusula | Efor |
|---|---|---|---|
| **CASEVAC** (9-line MEDEVAC) | Standart tahliye talebi formu | ⬜ | M |
| SPOTREP / SALUTE benzeri raporlar | Gözlem raporu şablonu | ⬜ | S |
| **Alert** (acil durum işareti) | Ekibe acil durum yayını | ⬜ | M (Faz 2) |
| **Contacts / GeoChat** | Kişiler, grup sohbeti, konumlu mesaj | ⬜ | L (Faz 2) |
| **Encrypted Mesh Communications** | Şifreli mesh haberleşme | ⬜ (mimari hazır) | L (Faz 2) |
| **CoT uyumu** | ATAK/iTAK'ın mesaj biçimi (Cursor-on-Target) | ⬜ | M — **Meshtastic'in ATAK eklentisi var; Pusula CoT konuşursa ATAK kullanıcılarıyla birlikte çalışabilir** |

---

## 4. Önerilen sıra

| Aşama | İçerik | Neden önce |
|---|---|---|
| **A. Menü iskeleti** | Alt çubuk, sağ kontroller, artı imleç, genişleyen HUD, ⚙ Ayarlar, birleşik Görevler ekranı | Sonraki her özellik bu yapıya yerleşir |
| **B. Navigasyon çekirdeği** | Koordinat girişi + Git, R&B çizgi/daire, Bloodhound, rota planlama + takip paneli | Kerteriz'in en çok kullanılan kısmı |
| **C. Saha konforu** | İz otomatik durdurma, pil uyarısı, ekranı açık tut, BMNT/EENT, Quick Pic, etiketler, yedekleme | Küçük, değeri yüksek |
| **D. Arazi analizi** | Viewshed, profil, kontur, resection, geofence | Pusula'yı Kerteriz'den ayıran kısım |
| **E. Paylaşım ve rapor** | Görev paketi, GPX/PDF, CASEVAC/SPOTREP şablonları, METOC | |
| **F. Ekip (Faz 2)** | Meshtastic, kişiler, GeoChat, acil durum, CoT uyumu | Donanım (Meshtastic düğümü) gerekir |

## 5. Kararlar (2026-11-04)

1. Alt çubuk: **Koordinat · Araçlar · ● İz · Rota · Görevler**. Taktik pusula,
   sağdaki [N] düğmesine uzun basınca açılır.
2. Hava (METOC): **Open-Meteo**, kişisel kullanım için. Mağazaya çıkarken
   ücretli plana ya da ticari kullanıma uygun başka bir kaynağa geçilir.
3. iTAK ayrıca REA ile incelenmeyecek (resmi ATAK kılavuzu yeterli).

Açık: ATAK/iTAK ile **CoT birlikte çalışabilirlik** Faz 2'de hedef mi?
