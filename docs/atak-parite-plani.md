# ATAK paritesi planı

> **Tarih:** 2026-11-06 · **Dayanak:** [atak-karsilastirma.md](atak-karsilastirma.md)
> (76 satır, kılavuz v4.5) ve [atak-civ-teknik-analiz.md](atak-civ-teknik-analiz.md)
> (ATAK-CIV 5.5.1.10 kaynak analizi).
>
> **Hedef:** ATAK-CIV'in kapsam içindeki her işlevini Pusula'da ✅ seviyesine getirmek,
> sonra ATAK'ı geçmek.
>
> Bu plan [yol-haritasi.md](yol-haritasi.md) §4'teki C–F sırasının yerini alır.
> Kerteriz'den alınacaklar (§2) aşağıdaki aşamalara dağıtıldı.
>
> **Efor:** S = küçük (bir oturum) · M = orta (birkaç oturum) · L = büyük (bir aşamanın ana işi)

---

## 0. "Birebir" ne demek

| Yol | iPhone'da çalışır mı | Sonuç |
|---|---|---|
| ATAK-CIV'i fork'lamak | **Hayır.** ATAK sadece Android; iOS sürümü iTAK kapalı kaynak | Test cihazı iPhone → elenir |
| ATAK kodunu Dart'a çevirmek (port) | Evet | Pusula da **GPLv3** olur. Kişisel kullanımda sorun yok; App Store dağıtımıyla çatışma riski var |
| **ATAK'ı spesifikasyon alıp yeniden yazmak** (**karar: 2026-11-06**) | Evet | İşlev, arayüz, veri modeli ve protokol birebir; kod bizim ("temiz oda") |

**Birebir alınacak üç katman:**
1. **İşlevler:** Karşılaştırmadaki her ⬜ ve 🟡 satırı.
2. **Arayüz ve etkileşim modeli (birebir):** Üst araç çubuğu, ≡ araç ızgarası, sol üstte
   pusula oku, nesneye dokununca radyal menü, Point Dropper, Overlay Manager, yan paneller
   (Aşama D).
3. **Veri modeli ve protokol:** CoT. Her nesne `uid` + tip kodu + nokta + detaydan oluşur.
   Bu sayede Faz 2'de ATAK kullanıcılarıyla aynı haritayı paylaşabiliriz.

**Alınmayacaklar:** ATAK'ın kodu, ikonları, adı ve markası.
Askerî sembol tanımları için açık lisanslı kaynaklar var: **mil-sym** (Apache-2.0, ATAK'ın
kullandığı kütüphane) ve **milsymbol** (MIT). Lisansları eklemeden önce yeniden doğrulanacak.

---

## 1. Pusula'nın ATAK'ı geçeceği yerler

- **iPhone'da çalışır.** ATAK'ın iPhone sürümü yok.
- **Dikey ve yatay ekran, eldiven:** ATAK düzeni iki yönde de çalışır; dokunma hedefleri
  büyük tutulur. Artı imleç ATAK'ta yok, ama eldivenle nokta koymak için Ayarlar'da
  isteğe bağlı kalır.
- **Güvenli varsayılanlar:** Analizdeki 7 ATAK zaafının (§3.3) hiçbiri olmayacak.
  - Şifreli veritabanı varsayılan olarak açık.
  - Ağdan gelen her veri için kullanıcı onayı.
  - Uzaktan silme sadece nesnenin sahibinden kabul edilir.
  - Şifresiz yayın kapalı.
- **Harita kalitesi:** Mapbox uydu (z22); çevrimdışı indirmede gerçek boyut tahmini.
- **Türkiye'ye özel:** Türkçe arayüz, MGRS odaklı giriş, Türkiye röleleri, Türkiye yükseklik paketi.
- **Test edilebilirlik:** Alan katmanı saf Dart ve birim testli. ATAK'ta 553 bin satıra 97 test dosyası düşüyor.

---

## 2. Aşamalar

**Sıra mantığı:**
1. Önce her şeyin dayandığı **nesne modeli**.
2. Sonra **etkileşim**.
3. Sonra **işlev blokları**.
4. En son **ağ**.

Her aşama küçük adımlara bölünür ve her adım cihazda test edilir.

### Aşama B kapanışı
Navigasyon + yatay düzen commit edildi (`d9a600e`, 2026-11-06). Yürüme testi bekliyor;
bir sorun çıkarsa ayrı düzeltme commit'i atılır.

### Aşama C: Hızlı kazanımlar + ATAK nesne modeli

**C1. Hızlı kazanımlar** (nesne modelinden bağımsız) — **kodda tamam (2026-11-06), cihaz testi bekliyor**

> Bulgu: iPhone'da `flutter_compass` zaten coğrafi kuzey (`trueHeading`) veriyor; manyetik sapma
> iOS'ta yalnızca gösterim için, Android'de ayrıca pusula düzeltmesi için gerekiyor. Mapbox'ın ölçek
> çubuğu iOS'ta yalnızca zoom sırasında göründüğü için ölçek çubuğu uygulamada çiziliyor.

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Açı birimleri (13) | Manyetik sapma, WMM2025 katsayılarıyla (NOAA, kamu malı) cihazda ve internetsiz hesaplanır. Kerteriz Gerçek/Manyetik/Grid ve Derece/Mil olarak gösterilebilir | M |
| Map Controls (26) | Ölçek çubuğu açılır, gece renklerine uyar | S |
| GPS Error Overlay (8) | Haritada ±m doğruluk dairesi | S |
| Koordinat biçimleri (39) | HUD döngüsüne DMS ve DM eklenir | S |
| Clear Content (58) | Onaylı tam silme: veritabanı, içe aktarılan haritalar, çevrimdışı bölgeler, ayarlar | S |

**C2. ATAK nesne modeli** (temel)

| Ne | Ayrıntı | Efor |
|---|---|---|
| `MapItem` alan modeli | `uid` (UUID), CoT tip kodu (ör. `a-f-G-U-C-I` = dost piyade), ad/callsign, zaman. Etiketler ve ekler kendi aşamalarında (D, G) eklenecek | M |
| drift v8 | Noktalar, grafikler ve rotalara `uid`, `cotType`, `hae` eklenir. Mevcut APP-6 alanları tip koduna çevrilir, veri kaybolmaz | M |
| CoT XML okuma/yazma | Saf Dart; ATAK-CIV'in `takcot/examples` örnekleriyle test edilir | M |
| Tip kodu ↔ sembol | APP-6 çizici tip kodundan beslenir | S |

**Durum (2026-11-06):** kodda tamam, cihaz testi bekliyor.
- `uid`: paket yerine `lib/core/uuid.dart` (`Random.secure()`, RFC 4122 v4) — bağımlılık eklenmedi.
- drift v8: dört tabloda `uid` (benzersiz indeks), noktalarda `cot_type` (yalnızca dışarıdan
  gelen ham tip; yoksa sembolden türetilir) ve `hae`. Yükseltme, telefondaki gerçek v7 şemasından
  üretilen `test/fixtures/db_v7.sqlite` ile test edildi.
- CoT: `lib/data/cot/` (olay, XML, eşleyici). Çıktı ATAK-CIV `takcot/examples` dosyalarıyla
  öğe öğe aynı yapıda. Kademe TAK'ın `<__milsym id=SIDC>` öğesiyle taşınır — ATAK'ın bunu
  çizdiği doğrulanmadı (?).
- Bulgu: ATAK-CIV'in `takcot/xsd` şemaları yetkili değil (`link.xsd` bozuk, işaretçi/rota
  şemaları derlenmiyor, ATAK'ın kendi Circle/R&B örnekleri geçemiyor) → doğrulama örneklerle yapıldı.
- C1 düzeltmesi: acil silme `sqlite_sequence`'i de sıfırlıyor (yeni id'ler eski kayıt sayısını sızdırmasın).

**Neden önce:** Radyal menü, nesneye bağlı R&B çizgisi, veri paketi, dışa aktarma ve mesh
paylaşımının hepsi `uid` ve tip koduna dayanıyor. Bu temel sonraya kalırsa veritabanını
ikinci kez taşımak gerekir.

**Kabul:**
- Eski noktalar yükseltmeden sonra yerinde duruyor.
- Her nesnenin CoT çıktısı ATAK'ın açabileceği biçimde.

### Aşama D: ATAK arayüzü (birebir)

Kerteriz tarzı kabuk (alt çubuk, üst HUD, sağ düğme sütunu) kalkar; yerine ATAK'ın ana
ekranı gelir. Kaynak: kılavuz s.5–6, 8, 55–57. Yerleşim kılavuz metninden ve ekran
görüntülerinden alınır, ATAK'ın ikonları kullanılmaz.

**D1. Ana ekran düzeni** — **kodda tamam (2026-11-06), cihaz testi bekliyor**

> Yapılan: `AtakToolbar` (≡ · Nokta bırak · R&B · Git · Haritalar · İz; ≡'ye uzun bas → gizle),
> `MapSideControls` (haritayla dönen pusula oku; dokun: kuzey/yön, uzun bas: döndürme kilidi + 3B;
> ◎; zoom), `SelfInfoBox` (sağ alt; eski HUD), ≡ ızgarası (`tools_grid_sheet.dart`: Navigasyon,
> Ölçüm, Veri, Harita, Sistem), nokta bırakma modu, artı imleç Ayarlar'da (varsayılan kapalı).
> Kalkanlar: Kerteriz alt çubuğu, sağ sütun, üst HUD, sağ kenardan kaydırma. Rota planlama çubuğu
> D2'ye kadar altta. Motor: `zoomBy`, `setRotationLocked`.

| Öğe (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Üst araç çubuğu (5) | Haritanın üstünde boydan boya. Solda ≡ (bütün araçlar), yanında sık kullanılan araç ikonları. ≡'ye uzun basınca çubuk gizlenir | M |
| ≡ Ek Araçlar ızgarası (5) | Bütün araçlar tek ızgarada: Koordinat/Git, Rota, İz, Noktalar, Overlay Manager, çevrimdışı haritalar, içe aktarma, ölçüm araçları, Ayarlar… Bugünkü alt çubuk sekmeleri ve Görevler ekranı buraya dağılır | M |
| Pusula oku, sol üst (5–6) | Dokun: kuzey-yukarı / yön-yukarı. Uzun bas: elle döndürme + kilit, 3B ve eğim kilidi | S |
| Zoom, ortala, kilitle (5) | Büyüteç +/−, kendi konumuna ortala, ekranı kendi konumuna kilitle | S |
| Kendi konum bilgisi | Callsign, koordinat, yükseklik, hız, yön, ±m. Üst HUD'un yerine küçük bir kutu (konumu ATAK ekran görüntüsünden doğrulanacak ?) | S |
| Sol alt: bildirim ve navigasyon (5, 17–19) | Uyarılar, rota/bloodhound bilgi kutusu ATAK'taki gibi sol altta | S |
| Ölçek (5) | C1'de açılan ölçek çubuğu ATAK konumuna taşınır | S |

**D2. Paneller ve araç çubukları** — üç adımda: **D2a** araç alt çubukları (tamam, commit
89423b0), **D2b** panel açıkken harita kullanılabilir (kodda tamam, cihaz testi bekliyor),
**D2c** Toolbar Manager (kodda tamam, cihaz testi bekliyor).

> D2a: R&B düğmesi ana çubuğun altında **Range Tools** çubuğunu açar (halka · R&B · alan · sektör ·
> görüş hattı · ✕; seçili araç sarı, tekrar dokununca kapanır) + altında ölçüm şeridi (kaydet ·
> göster/gizle · geri al · temizle). Rota planlama ATAK'taki gibi üstte tek çubuk (talimat/mesafe +
> Geri al · Temizle · [+ Nokta yalnız artı imleç açıksa] · Kaydet · Çık); alttaki çubuk kalktı.
> Kılavuz s.12 (Range Tools), s.15 (rota: End/Draw/Undo). Draw (parmakla çizim) yok.
>
> D2b: `PanelHost` (`lib/features/shell/panel_host.dart`) harita sayfasının üstünde, **modal
> olmayan** paneller: karartma yok, panel açıkken harita kaydırılır/dokunulur. Yatayda sağdan
> (~%45, tam boy), dikeyde alttan (içerik kadar, en çok yarım ekran; tutamak yukarı → araç
> çubuğunun altına kadar büyür, aşağı → küçülür/kapanır; ✕). Paneller sayfanın geri yığınına
> (`LocalHistoryEntry`) girer: içerikteki `Navigator.pop` ve Android geri tuşu en üstteki paneli
> kapatır, çağıranlar değişmedi. Haritadan/çubuktan açılan panel öncekini kapatır; panel içinden
> açılan üstüne biner. ≡ · Git · Haritalar ikinci basışta kapanır. Köşe kutuları ve Mapbox logosu
> panelin yanına/üstüne kayar (tam ekranda gizlenir). Bilgi şeritleri panelin üstünde.
>
> D2c: üst çubuktaki araçları kullanıcı seçer (`ToolbarTool`, ayarlarda `toolbar_tools`; en
> çok 6, varsayılan D1'deki 5). Katalog: nokta bırak · R&B · Git · Haritalar · iz kaydı ·
> rotalar · noktalar · izler · çizimler · çevrimdışı bölgeler · gece modu · artı imleç · ayarlar.
> "Araç çubuğu" paneli (≡ → Sistem, ya da çubuktaki bir araca uzun bas): tutamaktan sürükle-sırala,
> çıkar, ekle, varsayılana dön; panel modal olmadığı için değişiklik çubukta anında görünür.
> Çubuktan çıkan her araç ≡ ızgarasında da var (ızgaraya Nokta bırak ve İz kaydı eklendi);
> çubuk ve ızgara aynı eylem tanımını kullanır. ATAK'ın birden çok adlı çubuk / sürükle-bırak
> ile ızgaradan çubuğa taşıma yok (gerekirse sonra).

| Öğe (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Yan paneller (DropDown) | Yatayda sağdan 1/3–1/2 genişlik (bugünkü `adaptive_sheet` temeli), dikeyde alttan yarım ekran. Panel açıkken harita kullanılabilir | M |
| Araç alt çubukları (12–13) | Aktif araç kendi küçük araç çubuğunu açar (ATAK'taki Range Tools gibi); bugünkü ToolBanner'ın yerini alır | M |
| Toolbar Manager (55–57) | Üst çubuğa hangi araçların konacağını kullanıcı seçer | M |

**D3. Etkileşim** — adım adım: **D3a** radyal menü, **D3b** kendi işaret menüsü, **D3c** GPS'siz
konum düzeltme, **D3d** Point Dropper (dördü de cihazda ✓, 2026-11-08), **D3e** nokta detayı
(yükseklik + fotoğraf; cihazda ✓, 2026-11-08), **D3f** Overlay Manager + #etiket (cihazda ✓),
**D3g** kayıtlı görünümler (cihazda ✓), **D3h** sembol kütüphanesi + görev seti (cihazda ✓). **D3 tamam.**

> D3a: noktaya / röleye dokununca etrafında 64 pt düğmelerden halka (`shell/radial_menu.dart`).
> Nokta: Detay · Git · R&B (noktadan ölçüm) · Halka (noktayı merkez alan menzil halkası) ·
> Taşı (sonraki dokunuş / "İmlece taşı") · Paylaş · Sil (onaylı) · Ortala. Röle: Detay · Git ·
> R&B · Ortala. Dışına dokunuş kapatır ve haritaya geçer; kamera değişince menü nesneyle kayar.
> Ölçüm / rota planlama / taşıma sürerken nesneye dokunuş noktayı nesnenin üstüne koyar
> (nesneye yapışma). Tehdit halkası ve Kilitlen E'de (R&B/halka kaydı, hareketli nesne).
>
> D3b: kendi işaretine dokununca: Ortala · Daire (GPS hata dairesi aç/kapa) · Pusula (kendi
> konumun etrafında gül; haritayla döner, zoom yarım kademede yeniden ölçeklenir) · 15 dk (son
> 15 dakikanın izi; kayıttan bağımsız, bellekte, 5 m aralık, >50 m doğruluk atlanır) · Paylaş
> (callsign + MGRS + WGS84). Seçimler ayarlarda kalıcı. Ölçüm açıkken kendi işaretine dokunuş
> ölçümü kendi konumundan başlatır.
>
> D3c: kendi işaret menüsü → Düzelt: haritada dokun (ya da İmlece; bir nesneye dokunursan tam
> onun yeri), koordinat yaz, ya da bilinen noktadan kerteriz + mesafe (ayarlardaki kuzey/birim;
> `NorthMath.toTrue`, `GeoMath.positionFromSighting`). Elle konum harita/konum kutusu/navigasyonda
> kullanılır (turuncu işaret, kutuda "MANUEL"); iz kaydı ve son 15 dk izi ham GPS'le
> (`gpsSelfContactProvider`). "GPS'e dön" ile biter; bellekte (yeniden açılışta GPS).
>
> D3d: "Nokta bırak" → palet (Dost · Düşman · Nötr · Bilinmeyen · Nokta; son seçim kalıcı,
> varsayılan Düşman). Haritaya her dokunuş diyalogsuz, sıra numaralı adla (DÜŞMAN-3; silinen
> numara yeniden verilmez) nokta bırakır; artı imleç açıksa "İmlece bırak". Uzun basma eskisi
> gibi diyalogla ekler. **Görev seti (OP, CP, sensör, toplanma) sembol kütüphanesine kaldı:**
> ATAK CoT kodları doğrulanamadı (`b-m-p-s-p-op` trafikte görülüyor ama tanımı yok); yanlış
> kodla dışa aktarmak Faz 2'de sessiz uyumsuzluk yaratır.
>
> D3e: nokta detayı kendi panelinde (`waypoints/waypoint_detail_panel.dart`, noktayı canlı izler).
> Yükseklik: elle girilen (MSL, drift v9 `elevation`; Düzenle'de) ya da arazi verisinden "≈ m
> (arazi verisi)"; CoT `hae` ayrı (jeoit modeli yok, MSL↔HAE çevrilmez). Fotoğraf: kamera /
> arşiv (`image_picker` 1.2.4), Belgeler/attachments/<uid>/ altına kopya, `attachments` tablosu
> (uid'e bağlı, yol göreli, uid yol için temizlenir); tam ekran görüntüleyici (yakınlaştır, onaylı
> sil). Nokta silinince fotoğrafları da silinir; acil silme klasörü siler (testli). HGT okuyucusu
> artık hazırlığı bekliyor (eskiden ilk sorguda sessizce null). Fotoğraf CoT/paket aktarımı G'de.
>
> D3f: Overlay yöneticisi (≡ → Harita; araç çubuğuna da eklenebilir; süzgeç varken vurgulu).
> Noktalar türe göre açılır gruplar, Çizimler, İzler (dokun → haritada göster; bir seferde bir),
> Rotalar (dokun → önizle), telsiz röleleri. Grup ve nesne başına göz düğmesi; nesneye dokun →
> ortala. #etiketler ad ve nottaki `#kelime`'den (Türkçe küçük harf, şema değişikliği yok); çipe
> dokununca haritada yalnız o etiketli noktalar/çizimler kalır, haritada "Yalnız #x" şeridi (✕).
> Seçimler ayarlarda JSON (`OverlayVisibility`). İz/rota çoklu görünürlük ve harita katmanları
> aç/kapa sonra.
>
> D3g: kayıtlı görünümler (≡ → Harita; araç çubuğuna eklenebilir). "Bu görünümü kaydet": merkez,
> zoom, yön, harita kaynağı (ayarlarda JSON `saved_views`; acil silmede gider). Dokununca kaynak
> seçilir ve yüklenince kamera oraya gider; takip ve yön-yukarı kapanır. Kaynak silinmişse mevcut
> haritada açılır (uyarı). Yeniden adlandır / sil.
>
> D3h: Türkçe kodlama kararı (2026-11-08): ekranda ve adlarda her şey Türkçe; CoT kodu yalnız
> dışa/içe aktarımda tercüman (veritabanında türün adı saklanır, şema değişmedi). Yeni türler:
> **varsayılan dost** / **şüpheli** (dost / düşman çerçevesi kesik çizgi, 2525D; CoT `a-a-` /
> `a-s-`, SIDC A / S), tehlike ikonları **mayın** `a-?-G-E-X-M`, **KBRN** `a-?-G-E-X-N` (okurken
> `I-R-N…` tesisleri de), **bariyer** `a-?-G-I-c-bar` (TAK CoTtypes.xml'den doğrulandı; `I-R-M`
> maden ocağıdır, alınmadı; genel "engel" için tek tip yok, eklenmedi). **Görev seti** Pusula'ya
> özgü: Gözetleme (GN), Kontrol (KN), Toplanma (TN) noktası, Sensör (SN) — mor rozet; ATAK'ta
> güncel CoT tipi olmadığı için (yalnız DEPRECATED `b-g-…`) adıyla mor `b-m-p-s-m` gider, tür
> `<__pusula kind=…/>` ayrıntısıyla Pusula'ya geri döner. Point Dropper üç sekme: Sadakat (6) ·
> Görev (Nokta, GN, KN, TN, SN) · Tehlike (MAYIN, KBRN, BARİYER; düşman olarak düşer).
> Ekle/Düzenle'de tür seçimi iki grup (Nokta/görev · Sadakat); tehlike ikonunda büyüklük gizli.
> Uzun basarak eklenen noktanın varsayılan adı WP-n yerine NOKTA-n.

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Radial Menu (11) | Nesneye dokununca, tipine göre değişen halka menü açılır: Sil, İnce ayar, R&B, Git, Tehdit halkası, Kilitlen, Detay, Paylaş. Dilimler eldivenle seçilebilecek büyüklükte | L |
| Self-marker radyali (8) | Kendi işaretine dokununca: GPS hata dairesi, pusula gülü, son 15 dk izi, ince ayar / polar giriş (GPS'siz konum düzeltme) | M |
| Point Dropper (9–10) | Üst çubuktaki paletten tek dokunuşla dost/düşman/nötr/bilinmeyen; görev seti (OP, CP, sensör, toplanma noktası); son kullanılanlar; ad öneki ve sıra no (OP-1, OP-2…) | M |
| Overlay Manager (23) + Hashtags (24) | Noktalar, izler, rotalar, grafikler, röleler ve katmanlar gruplu aç-kapa; #etiket ile filtre | M |
| Kayıtlı görünümler (22) | Favori görünüm: konum + zoom + harita kaynağı | S |
| Details (11) | Yükseklik ve ek dosya/fotoğraf alanları | S |
| Sembol kütüphanesi (liste) | Şüpheli, varsayılan dost, mayın, engel, KBRN… genişletilmiş set | M |

**Kabul:**
- Dikey ve yatay ekranda ATAK düzeni: üst çubuk, ≡ ızgarası, sol üst pusula, paneller.
- Bugünkü her işlev yeni düzende erişilebilir; hiçbir özellik kaybolmuyor.
- Widget testleri yeni kabuğu kapsıyor.

**Not:** Bu karar CLAUDE.md §1'deki "kalıcı üst HUD" ilkesini ve §6 Adım 8'deki
"sağ kenardan kaydır" jestini değiştiriyor. Aşama D başlarken brief güncellenir.

### Aşama E: Ölçüm ve navigasyon tam set

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| R&B Line + Dynamic (12) | Kalıcı çizgi. Uçları nesneye bağlı, nesne hareket edince güncellenir. Eğim/depresyon açısı gösterilir | M |
| R&B Circle, Threat Rings (8, 13) | Kaydedilir ve nesneye bağlanır | S |
| Bullseye (14) | Referans noktadan kerteriz/mesafe halkaları ve "BULLSEYE 045/2,3 km" bildirimi | M |
| Multiple Bloodhounds (18–19) | Birden çok hedef, iki nesne arası takip, renkli ETA eşikleri | M |
| Resection (50) | 2–3 bilinen noktaya alınan kerterizlerden konum ve hata alanı | M |
| Taktik pusula (liste) | [N]'ye uzun basınca büyük pusula, kerteriz kilidi, sapma göstergesi | M |
| Buluşma noktası (liste) | Hedef saat → gereken hız. Ekiplerin aynı anda varması Faz 2'de | S |
| Routes (15–19) eksikleri | Ters çevirme, nokta adı, GPX/KML dışa aktarma, sesli uyarı, rota boyunca profil | M |
| Sensor / FOV (9) | Görüş konisi: yön, genişlik, menzil | S |

### Aşama F: Arazi analizi

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Elevation Data (25) | HGT/DTED içe aktarma; Türkiye yükseklik paketi (SRTM kamu malı ya da Copernicus GLO-30); kapsama haritası | M |
| Elevation Tools: profil (48) | Çizgi ve rota boyunca yükseklik profili ve eğim | S |
| Viewshed (48) | 360° görülen/görülmeyen alan; gözlemci ve hedef yüksekliği ayarlanır. Hesap arka planda yapılır (isolate), sonuç haritada yarı saydam katman | L |
| Contour Lines (49) | Seçilen alan için eş yükselti eğrileri | M |
| Eğim / yükseklik ısı haritası (48) | Renkli eğim katmanı | M |

**Kabul:** Hepsi uçak modunda, cihazdaki yükseklik verisiyle çalışıyor.

### Aşama G: Çizim ve veri yönetimi

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Drawing Tools (40–41), Telestrate (42) | Daire, dikdörtgen ve serbest çizim kaydedilir; çizgi kalınlığı ve stili | M |
| 3D Shapes (42) | Yükseklikli alan (Mapbox fill-extrusion) | S |
| Geofencing (43) | Alana giriş/çıkış uyarısı, uygulama arka plandayken de. Arka plan konum izni iz kaydı için zaten açık | M |
| Lasso + Multi-Select (25, 44) | Alan seçip toplu dışa aktarma, silme, etiketleme | M |
| Quick Pic / Gallery (45) | Konumlu fotoğraf; nesneye ek; galeri | M |
| Track Search (46) | Tarih ve ada göre arama | S |
| İçe/dışa aktarma (51) | KMZ, GPX dışa aktarma, GeoJSON. SHP için Dart ayrıştırıcı gerekiyor (?) | M |
| Data Package (29–30) | ATAK uyumlu görev paketi (zip + `MANIFEST/manifest.xml`). İçe aktarmada önizleme ve onay | L |

### Aşama H: Harita kaynakları

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| GeoPackage raster (51) | SQLite karo tablosu; mevcut yerel karo sunucusu üzerinden gösterilir | M |
| Özel WMS/WMTS/XYZ (liste) | Çevrimiçi kaynak ekleme (ör. kamu ortofotosu). Google/Esri karolarını toplu indirmek lisans gereği yine yasak | M |
| GeoTIFF (51) | Yalnızca WGS84 / Web Mercator. Diğer projeksiyonlar pusula-tiler ile dönüştürülür | L |
| KMZ görüntü katmanı (51) | GroundOverlay desteği | S |
| Rubber Sheet (52) | Kâğıt pafta fotoğrafını 4 köşesinden haritaya oturtma | L |

### Aşama I: Güvenlik, saha konforu, raporlar

| Özellik | Ne yapılacak | Efor |
|---|---|---|
| Şifreli veri (ATAK s.5) | SQLCipher. Anahtar iOS Keychain'de; isteğe bağlı parola / Face ID. Mevcut veritabanı şifreli kopyaya taşınır | M |
| Yedekle / geri yükle | Tek, şifreli dosya | S |
| Saha konforu (Kerteriz) | İz kaydının kendiliğinden durması, düşük pil uyarısı, ekranı açık tutma, BMNT/EENT, ay evresi | M |
| CASEVAC 9-line (20), SPOTREP/SALUTE | Form → metin olarak paylaşma. Faz 2'de mesh üzerinden | M |
| METOC (Kerteriz) | Open-Meteo (yol haritası karar 2) | S |

### Faz 2: Ekip, ATAK ile konuşan Pusula

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Wi-Fi yerel ağ kanalı | CoT trafiği: konum yayını 239.2.3.1:6969, sohbet 224.10.10.1:17012, doğrudan mesaj 4242. **iOS'ta multicast için Apple'dan özel yetki (multicast entitlement) almak gerekiyor.** Yetki gelene kadar doğrudan IP (4242) ile test edilir | M |
| Meshtastic BLE + `TAKPacket` (Adım 9–13) | Donanım gelince | L |
| Contacts, Team PLI (8, 31–32) | Kişiler, takım rengi ve rolü | M |
| GeoChat (32–34) | Grup sohbeti, konumlu mesaj | M |
| Digital Pointer (47), Alert (53) | "Şuraya bak" işaretçisi, acil durum yayını | M |
| Encrypted Mesh (35) | Meshtastic kanal şifrelemesi + gönderen kimliği. ATAK'taki tek paylaşımlı anahtar hatası tekrarlanmaz | M |
| Veri paketini ağdan gönderme/alma | Aşama G'deki paket + onay ekranı | M |

---

## 3. Kapsam dışı kalanlar

| ATAK (s.) | Neden |
|---|---|
| Video oynatıcı, KLV, canlı video (36–38) | PAR video kütüphanesi kapalı kaynak. FFmpeg + MISB 0601 ayrıştırıcı ayrı ve büyük bir proje |
| Radio Controls, PRC-152, ROVER (27–28) | Üretici belgesi ve donanım gerekiyor |
| Eklenti sistemi (59–60) | iOS, uygulama çalışırken dışarıdan kod yüklemeye izin vermiyor. Yerine Ayarlar'da özellik aç/kapa (Toolbar Manager benzeri) yapılabilir |
| CADRG/CIB/MrSID, WFS (22, 51) | Askerî ve sunucu biçimleri; GDAL gerektiriyor |
| TAK Server istemcisi (TLS 8089, PKCS#12, kayıt 8446) | Sunucu gerektiriyor; önce yerel ağ ve mesh (karar 2026-11-06). İhtiyaç olursa sonra eklenir |
| 3D Models, First Person View (7) | Sonra değerlendirilir (Mapbox'ta 3B model katmanı var) |

---

## 4. Her aşamada uyulacak kurallar

1. **ATAK referanstır, kod kaynağı değil.** Her özellik için önce kılavuzdaki bölüm, gerekirse
   ATAK-CIV'deki davranış okunur; kod kopyalanmaz.
2. **Karşılaştırma tablosu güncellenir.** Hedef seviye ✅. Bir özellik ATAK'tan farklı
   yapılıyorsa nedeni tabloya yazılır.
3. **ATAK düzeni esastır.** Yeni her araç ATAK'taki yerine konur: ≡ ızgarası, üst çubuk,
   radyal menü ya da yan panel. ATAK'tan farklı yapılan her şeyin nedeni yazılır.
4. **Güvenlik kuralları** (analiz §5.4, 6 madde) Faz 2'den önce, veri paketinde (Aşama G) de geçerli.
5. **Yeni paketler** (ör. `uuid`, `archive`, `sqlcipher_flutter_libs`) eklenmeden önce onay
   alınır ve pub.dev'den güncel sürüm doğrulanır.
6. **Saf Dart birim testleri:** CoT, WMM, resection, viewshed, bullseye, paket manifesti.

---

## 5. Büyük kalemler (L)

ATAK arayüzüne geçiş ve radyal menü (D) · viewshed (F) · veri paketi (G) ·
GeoTIFF ve rubber sheet (H) · Meshtastic (Faz 2).
Planın geri kalanı S/M boyutunda, birbirinden bağımsız adımlar.

---

## 6. Kararlar (2026-11-06)

1. **Lisans:** Temiz oda. ATAK kodu kopyalanmaz ve çevrilmez; kılavuz, protokol bilgisi ve
   davranış referans alınır.
2. **Arayüz:** ATAK arayüzü birebir (Aşama D). Kerteriz tarzı kabuk kalkar.
3. **TAK Server istemcisi:** Şimdilik kapsam dışı.
4. **Aşama B:** Yürüme testi beklenmeden commit edildi.
