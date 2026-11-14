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
> **Ad (2026-11-14):** uygulamanın adı artık **Usturlap**; bu belgede geçen "Pusula" uygulama
> adı için Usturlap okunmalı ("Kerteriz'den alınacaklar" eski Kerteriz projesini anlatır).
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

**D1. Ana ekran düzeni** — **tamam** (commit 3cfe368)

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

**D2. Paneller ve araç çubukları** — üç adımda: **D2a** araç alt çubukları (commit 89423b0),
**D2b** panel açıkken harita kullanılabilir, **D2c** Toolbar Manager (ikisi commit 2fc0b40).

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

**D4. Gezinme ve temizlik** (kullanıcı isteği, 2026-11-08; F'den önce) — **cihazda ✓ (2026-11-09)**:

> **D4a — Menüye geri dön.** Bugün ≡ ızgarasından bir panel açılınca ızgara kendini kapatıyor;
> menüye dönmek için ✕ ile kapatıp ≡'yi yeniden açmak gerekiyor. Yeni davranış:
> - Izgaradan açılan **panel** ızgaranın üstüne biner (ızgara altta kalır). Haritayla çalışan
>   araçlar (R&B, nokta bırak, rota planlama, taktik pusula) eskisi gibi ızgarayı kapatır.
> - Panel başlığında altta başka panel varsa solda **← Geri** (bir önceki panel); **✕** bütün
>   panelleri kapatır. Android geri tuşu = ← Geri.
> - Aynı kural iç içe akışlarda da: Rota → Profil / Nokta adları, Düzelt → Geriden kestirme,
>   Overlay yöneticisi → nokta detayı.
>
> **D4b — Haritayı temizle.** Ekrana eklenenleri tek tek kapatmak yerine tek seferde:
> - ≡ → Harita → **Haritayı temizle** (araç çubuğuna da eklenebilir; Overlay yöneticisinde de
>   düğme). Haritada ne varsa sayısıyla listelenir, işaretlenenler temizlenir.
> - Varsayılan işaretli (geçici / ölçüm): ölçüm aracı çizimi, R&B çizgileri, menzil halkaları,
>   bullseye, takipler, "Git" hedefi, rota takibi ve önizlemesi, gösterilen iz.
> - Varsayılan işaretsiz (kalıcı veri): noktalar, çizimler, rotalar — işaretlenirse ayrıca uyarı.
> - Silmek yerine **yalnız gizle** seçeneği (Overlay yöneticisi görünürlüğü; veri kalır).
> - Temizledikten sonra birkaç saniye **Geri al** (silinenler aynı kimlikleriyle geri gelir;
>   eldivenle yanlış dokunmaya karşı).
>
> Yapılış: `PanelHost.runStacked` (içinde açılan panel üste biner), menü paneli (`menu: true`;
> üstündeki panel Geri dışında kapanırsa menü de kapanır — geri yığını çıkarırken iç içe çıkarma
> olmasın diye bir sonraki turda), başlıkta ← Geri / ✕ hepsini kapat, `openStacked` yardımcısı
> (Düzelt → Geriden kestirme, Overlay → Haritayı temizle). Android geri tuşu üstteki paneli
> kapatır; menünün üstündeyse menü de kapanır (iOS önceliği; "← Geri" düğmesi menüye döner).
> Temizle: `providers/map_cleaner.dart` (`mapClearTargetsProvider` yalnız görünenleri sayar,
> `MapCleaner.clear/undo/finalize`), `map/clear_map_sheet.dart` (düğme listenin üstünde, 3 sn
> Geri al); silinen noktaların fotoğrafları Geri al süresi dolunca silinir. Kayıtlı rotalar
> haritada durmadığı için listede yok.

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

Adımlar (tablodaki sırayla): **E1** kalıcı / dinamik R&B çizgisi, **E2** kalıcı menzil / tehdit
halkaları, **E3** Bullseye, **E4** çoklu Bloodhound, **E5** Resection, **E6** taktik pusula, **E7**
buluşma noktası, **E8** rota eksikleri, **E9** sensör / FOV — **hepsi cihazda ✓ (2026-11-08).**
**Sesli uyarı ve bildirim (2026-11-11, `flutter_tts` 4.2.5 + `flutter_local_notifications`
22.3.3, onaylı):** rota takibi, geofence ve takip (kırmızı ETA) uyarıları uygulama öndeyken Türkçe
okunur (ayrı konuşma metni: "KN 1 geçildi. Sıradaki KN 2, 850 metre."; iOS ses oturumu playback →
medya sesi, sessiz düğmesi kapatmaz; Ayarlar → Sesli uyarılar + Sesi dene); arka plandayken yerel
bildirim (`providers/alert_providers.dart` AlertDispatcher). Bildirim izni geofence ya da rota takibi
başlayınca sorulur. Arka plan konumu tek karar noktasında (`backgroundLocationNeededProvider`): iz
kaydı **ya da** arka planda izlenen geofence (Geofence paneli → "Arka planda da izle", varsayılan açık).

> E1: iki noktalı ölçüm (R&B) şeritteki Kaydet ile kalıcı **R&B çizgisi** olur (R&B-1…; 3+
> noktalı yol eskisi gibi çizim). Nesneye dokunarak konan uç ona bağlanır (`RbEnd`: `self` /
> `wp:<uid>`; drift v10 `range_lines`, bağlı uçta kuruluş konumu da saklanır, nesne silinirse
> uç orada kalır): ben yürüdükçe / nokta taşınınca çizgi güncellenir. Kendi işaret menüsüne
> "R&B" eklendi (benden hedefe dinamik çizgi); noktanın R&B / Halka eylemleri bağlı başlar.
> Haritada pembe çizgi + ortada "kerteriz · mesafe" etiketi (ayarlardaki kuzey/birim); etikete
> dokun → Detay · Ortala · Sil. Detay paneli: uçlar (canlı / bağlı / silinmiş), mesafe, kerteriz,
> ters kerteriz, iki ucun yüksekliği (bağlı noktada elle girilen, yoksa arazi verisi) ve eğim
> açısı (↗ / ↘, eğrilik yok sayılır); yeniden adlandır, sil (onaylı). Overlay yöneticisinde
> "R&B çizgileri" grubu (göz, #etiket). Motor: `v:` önekli işaretçi resimleri kullanılmayınca
> stilden atılır (değişen etiketler bellek büyütmesin). ATAK paylaşımı (`u-rb-a`) sonra.
>
> E2: menzil halkası aracında Kaydet → kalıcı **halka grubu** (HALKA-1…; R, 2R, 3R; drift v11
> `range_rings`, mesafeler JSON). Merkez nesneye dokunarak konduysa bağlı (nokta / ben). Düşman
> ya da şüpheli noktası merkezliyse **tehdit halkası** (kırmızı), diğerleri pembe. Haritada
> içten dışa solan halkalar + her halkanın kuzey ucunda mesafe etiketi; dokun → Detay · Ortala ·
> Sil. Detay: merkez, halkalar, **konumum** (merkeze mesafe, kerteriz, kaçıncı halkanın içinde);
> **Mesafeler** düzenlenir (en çok 6, 1 m–200 km; boşlukla ayrılır, ondalık virgül/nokta, `km`
> eki: "500 1000 1,5km"). Overlay yöneticisinde "Menzil halkaları". ATAK paylaşımı (`u-r-b-c-c`)
> sonra. Ortak parçalar `tools/measure_common.dart` (onay, ad, uç açıklaması, satır).
>
> E3: **Bullseye** (≡ → Ölçüm; araç çubuğuna eklenebilir; nokta Detay → "Bullseye yap"). Tek
> bullseye (görev başına bir referans): ayarlarda JSON `bullseye`, şema değişmedi; merkez sabit
> ya da noktaya bağlı. Haritada halkalar (aralık 100 m–10 km, 1–10 halka) + 30°'de bir ışın,
> ışınlar **seçili kuzeye** hizalı (manyetikte 030°M tam sayı), uçlarda kerteriz, halkalarda
> mesafe etiketi (6+ halkada seyrek); dokun → Detay · Ortala · Kaldır. Sol altta **"BE 045° /
> 2.30 km"** şeridi (konumumun çağrısı; dokun → panel); nokta detayında noktanın BE çağrısı.
> ATAK paylaşımı (`u-r-b-bullseye`) sonra.
>
> E4: **Takip (Bloodhound)**: nokta menüsünde "Takip" (benden noktaya); ≡ → Navigasyon → Takip
> panelinde iki nokta arası ekleme. Aynı anda birden çok takip ("Git" hedefi gibi bellekte; tek
> "Git" ayrı kalır). Uçlar R&B gibi bağlı. Haritada çizgi + "kerteriz · mesafe · süre (varış
> saati)" etiketi; renk ETA'ya göre: kırmızı ≤ 5 dk, sarı ≤ 15 dk, yeşil (eşikler panelde, kalıcı
> `bloodhound_eta`); hız yalnız benden bilinir, duruyorsam yürüyüş hızıyla "~" tahmin; iki nokta
> arasında süre/renk yok (beyaz). Gerçek hızla kırmızıya girince titreşim + uyarı (ATAK yanıp
> sönme yerine). Renkler anlam taşıdığı için gece modunda da aynı.
>
> E5: **Geriden kestirme** (Resection; ≡ → Navigasyon, ya da kendi işaretin → Düzelt → "Geriden
> kestirme"). 2–3 noktaya pusula kerterizi (ayarlardaki kuzey/birim; `BearingFormatter.parseToTrue`).
> Çözüm `domain/usecases/resection.dart`: yerel düzlem, en küçük kareler; ~5°'nin altı paralel,
> bulunan yerin arkasında kalan nokta "tutarsız" (ters okuma). Hata alanı: en iyi kesişen çiftin
> ±σ çizgileri (pusula hassasiyeti ±1/2/5°) + üç nişanda hata üçgeni, dışbükey çokgen; "± m" =
> en uzak köşe. 30°'nin altı kesişme "zayıf" uyarısı. Haritada canlı önizleme (nişan çizgileri,
> hata alanı, konum). "Konumum yap" → elle konum (D3c), "Nokta olarak kaydet" (KESTİRME-n).
>
> E6: **Taktik pusula** (pusula okuna uzun bas → yandaki sırada; ≡ → Navigasyon). Tam ekran:
> telefonla dönen gül (5°'de çentik, 30°'de kısa etiket, K/D/G/B; seçili kuzey ve birimle), üstte
> sabit çizgi, ortada büyük yön + ters yön. **Kerterizi kilitle** (o anki yön) / **Kerteriz gir**
> / **Hedefe kilitle** ("Git" hedefi; yürüdükçe yeniden hesaplanır). Sapma: "DOĞRU" (±3°), "SAĞA
> 12°" / "SOLA 5°", yeşil / sarı (±15°) / kırmızı; rotaya girince titreşim. Plan "[N]'ye uzun bas"
> diyordu; uzun basma D1'de ek düğmeleri açıyor, pusula o sıraya eklendi.
>
> E7: **Buluşma saati**: "Git" şeridinde ⏱ → saat seç (geçmiş saat = ertesi gün; aynı hedef
> yeniden verilince korunur). Şeritte "Buluşma 14:30 · gereken 4.2 km/h"; hareket ediyorsam
> şimdiki hızla "3 dk geç" (turuncu) / "5 dk erken" / "zamanında". Ekiplerin aynı anda varması Faz 2.
>
> E8: rota menüsü (Rota paneli → ⋮): **Yükseklik profili** (arazi verisinden; ↗/↘ toplam, en
> yüksek/alçak, grafik + kontrol noktaları), **Nokta adları** (boş = BAŞLANGIÇ, KN1…; JSON'da
> isteğe bağlı 3. eleman, şema değişmedi; CoT'ta gidip döner, ATAK'a adsızsa SP/CPn), **Ters
> çevir** (dönüş; takipteyse takip biter), **Yeniden adlandır**, **GPX / KML paylaş**, Sil (artık
> onaylı). Takip panelinde sıradaki noktanın adı. Takipte **uyarı**: rotaya girildi / nokta
> geçildi (sıradaki nokta, kerteriz, mesafe), rota bitti, rotadan sapıldı → titreşim + ekran
> uyarısı. **Sesli** uyarı iOS'ta paket gerektiriyor (`flutter_tts` vb.) → kullanıcı onayı bekliyor.
>
> E9: **Görüş konisi**: nokta Detay → "Görüş konisi ekle": yön (ayarlardaki kuzey/birim; "Yönü
> pusuladan al" = telefonun baktığı yön), açıklık 30/60/90/120/180°/her yön, menzil (1 m–100 km,
> "1,5km"). drift v12: `waypoints.fov_azimuth/fov_width/fov_range` (üçü birlikte; yarım kayıt
> yok sayılır). Haritada noktanın renginde yarı saydam koni; nokta gizlenince konisi de gizlenir.
> ATAK'a koni paylaşımı (CoT `sensor` ayrıntısı) doğrulanmadığı için sonra.

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

Adımlar: **F1** yükseklik verisi, **F2** çizgi / çizim profili ve eğim, **F3** viewshed, **F4** eş
yükselti eğrileri, **F5** eğim / yükseklik renkli katmanı — **hepsi cihazda ✓ (2026-11-10).** F3 ve F5 için harita motoruna
resim katmanı eklenecek.

> F1: **Yükseklik verisi** (≡ → Harita; araç çubuğuna eklenebilir): cihazdaki kareler (biçim,
> çözünürlük, boyut; uygulamayla gelen N37E037 örneği), **Dosya içe aktar** (çoklu seçim; SRTM
> `.hgt` konumu dosya adından, DTED `.dt0/.dt1/.dt2` başlıktan; aynı karenin eski dosyası
> değiştirilir; zip'ler önce Dosyalar'da açılır — `archive` paketi gerekmedi), sil, **haritada
> kapsama** (1°×1° çerçeveler), "bulunduğun kare var / yok (hangi dosya)". Okuyucu (`HgtParser`,
> adı tarihsel): HGT + DTED (`data/elevation/dem_tile.dart`; DTED UHL/DSI/ACC + sütun kayıtları,
> işaret-büyüklük; GDAL'ın örnek n43.dt0 dosyasıyla 121/121 sağlama toplamı doğrulandı — dosya
> projeye eklenmedi), **çift doğrusal ara değer** (`elevationAt`), bulunamayan kare önbelleği,
> en çok 4 kare bellekte; içe aktarma / silmeden sonra önbellek yenilenir.
>
> F2: **Yükseklik profili** her çizgide: ölçüm şeridi (mesafe aracı, 2+ nokta), kayıtlı çizimler
> (çizgiler), R&B detayı, rota menüsü (E8). Panel genelleşti (`elevation/elevation_profile_panel.dart`):
> ara değerli okuma, eğri **eğime göre renkli** (yeşil < %10, sarı < %20, kırmızı), ↗/↘ toplam, en
> yüksek/alçak, **en dik çıkış / iniş** (%; veri boşluğunun üstünden eğim hesaplanmaz).
>
> F3: **Görüş alanı** (≡ → Ölçüm; nokta Detay → "Görüş alanı"): gözlemci (nokta / konumum /
> harita ortası), gözlemci yüksekliği 2/5/10/30 m, hedef zemin/insan/araç, yarıçap 0,5–10 km.
> Hesap `domain/usecases/viewshed.dart`: gözlemci çevresinde ≤ 401×401 ızgara (hücre ≥ 30 m),
> kenar hücrelerine ışın, ufuk açısı takibi, dünya eğriliği + kırılma (k = 0,13); ayrı
> **isolate**'te (gereken kareler baytlarıyla aktarılır). Haritada yeşil görünür / kırmızı
> görünmez yarı saydam **resim katmanı** (motor: `MapImage` → Mapbox ImageSource + raster katman,
> çizimlerin altında; ham RGBA, PNG yok), gözlemci işareti, yarıçap çemberi; özet "Görünen %42 ·
> 3.14 km²". Bitki örtüsü / bina hesaba katılmaz (SRTM/DTED yüzey). Haritayı temizle'de "Görüş
> alanı". Testler: düz arazi, sırt arkası, kule, ufuk (eğrilik), veri yok.
>
> F4 + F5: **Arazi analizi** paneli (≡ → Ölçüm): alan = harita ortası / konumum çevresi 1–10 km.
> **Eş yükselti eğrileri** ("yürüyen kareler", eyer durumları; parçalar uç uca birleşir; aralık
> otomatik (≤ ~20 eğri: 5/10/20/25/50/100/200 m) ya da 10/20/50/100 m); haritada açık kahve, her
> beşinci (ana) eğri kalın ve yüksekliği yazılı (en çok 40 etiket). **Renkli katman**: eğim (Horn;
> < 10° yeşil, 10–20 sarı, 20–30 turuncu, > 30 kırmızı; açıklamalı) ya da yükseklik (alandaki en
> alçak yeşil → en yüksek beyaz). Hesap `domain/usecases/terrain_grid.dart` (≤ 300×300 ızgara,
> hücre ≥ 30 m), isolate'te; eğriler ve katman birlikte durur, ayrı kaldırılır. Haritayı temizle'de
> "Arazi katmanları".

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| Elevation Data (25) | HGT/DTED içe aktarma; Türkiye yükseklik paketi (SRTM kamu malı ya da Copernicus GLO-30); kapsama haritası | M |
| Elevation Tools: profil (48) | Çizgi ve rota boyunca yükseklik profili ve eğim | S |
| Viewshed (48) | 360° görülen/görülmeyen alan; gözlemci ve hedef yüksekliği ayarlanır. Hesap arka planda yapılır (isolate), sonuç haritada yarı saydam katman | L |
| Contour Lines (49) | Seçilen alan için eş yükselti eğrileri | M |
| Eğim / yükseklik ısı haritası (48) | Renkli eğim katmanı | M |

**Kabul:** Hepsi uçak modunda, cihazdaki yükseklik verisiyle çalışıyor.

### Aşama G: Çizim ve veri yönetimi

Adımlar: **G1** çizim araçları, **G2** 3B şekiller, **G6** iz arama (üçü cihazda ✓, 2026-11-10),
**G4** lasso / çoklu seçim, **G3** geofence, **G5** hızlı fotoğraf / galeri (üçü cihazda ✓,
commit `f4cb0ff`), **G7** içe/dışa aktarma + çizim düzenleme (cihazda ✓, commit `6a92204`),
**G8** veri paketi (kodda tamam, cihaz testi bekliyor). `archive` 4.6.0 eklendi (onaylı, 2026-11-11).

> G1: **Çizim araçları** çubuğu (araç çubuğuna eklenebilir; ≡ → Veri): Çizgi (çoklu nokta; 2
> noktada da çizim, R&B değil) · Alan · **Daire** (merkez + kenar) · **Dikdörtgen** (iki çapraz
> köşe, enlem/boylam eksenli) · **Serbest çizim** (parmakla; çizim modunda harita kaymaz; iz
> Douglas–Peucker ile ~2,5 pt toleransla sadeleşip tek seferde konuma çevrilir — motor
> `latLngsAt`). Kaydet penceresi: ad (DAİRE-1…), renk, **kalınlık** 2/3/5/8, **kesikli çizgi**.
> drift v13 `map_graphics.stroke_width/dashed`; daire `points` = [merkez, kenar]. Motor:
> kesikli çizgi/kenar ayrı katman (`line-dasharray` öğe başına verilemiyor). ATAK'a daire ve
> dikdörtgen kapalı serbest çizim (`u-d-f`, 72 köşeli çokgen) olarak gider: `u-d-c-c` / `u-d-r`
> ayrıntı yapısı doğrulanmadı; kalınlık (`strokeWeight`) gidip döner, kesikli stil ATAK'a gitmez.
>
> G2: **3B şekiller**: kapalı çizimlerde (alan / daire / dikdörtgen) kaydederken "3B yükseklik"
> Düz / 10 / 25 / 50 / 100 m (drift v14 `map_graphics.height`). Mapbox `fill-extrusion` katmanı;
> harita eğikken (pusula okuna uzun bas → 3B) kutu olarak yükselir, düz bakışta alan gibi. Düz
> dolgu katmanı yükseklikli şekilleri çizmez. ATAK'a yükseklik gitmez (yapısı doğrulanmadı).
>
> G6: **İz arama** (İzler paneli): ad ya da tarih ("12.11") ile arama (Türkçe büyük/küçük harf
> duyarsız), Bugün / 7 gün / 30 gün / Tümü süzgeci, en yeni üstte; listede iz tarihi görünür.
>
> G4: **Seç (lasso)** (≡ → Veri; araç çubuğuna eklenebilir): parmakla alanın çevresi çizilir
> (serbest çizim katmanı, camgöbeği); içindeki **görünür** noktalar (konum), çizimler (bir köşesi),
> R&B çizgileri (orta nokta), halkalar (merkez) seçilir (`domain/usecases/lasso.dart`). Seçim
> paneli: işareti kaldırılan işleme girmez; **#etiket ekle** (noktaların notuna, diğerlerinin
> adına; zaten varsa eklenmez), **Dışa aktar** (G7 paneli; önceden KML paylaş), **Sil**
> (onaylı; Haritayı temizle altyapısı → 3 sn Geri al, fotoğraflar süre dolunca). Seçim alanı
> haritada kesikli çizgiyle; panel kapanınca seçim biter.
>
> G3: **Geofence** (≡ → Veri; araç çubuğuna eklenebilir): kapalı çizime (alan / daire /
> dikdörtgen) uyarı türü — Yok / Girişte / Çıkışta / Giriş ve çıkışta. Kaydet penceresinde ya da
> Çizimler listesindeki çit düğmesiyle (drift v15 `map_graphics.geofence`). İzleyici
> (`domain/usecases/geofence_monitor.dart`) her konumda içeride / dışarıda durumunu öncekiyle
> karşılaştırır; ilk konum yalnız durumu belirler (açılışta boşuna uyarı yok); doğruluğu 50 m'den
> kötü konum yok sayılır. Uyarı: güçlü titreşim + turuncu ekran uyarısı ("Liste" → Geofence
> paneli). Panel: uyarılı alanlar (şu an içeride / dışarıda), son 30 uyarı. **Sınır:** bildirim
> paketi olmadığından (onaysız paket eklenmedi) arka planda ses/bildirim yok; iz kaydı sürerken
> arka planda olanlar geçmişe yazılır, uygulama açılınca görünür. ATAK'a geofence ayrıntısı gitmez.
>
> **Çizim düzenleme** (2026-11-11, kullanıcı isteği): haritada çizime dokun → radyal menü
> (Düzenle · Şekil · Geofence · Profil · Sil). Düzenle = kaydetme penceresi dolu gelir (ad, renk,
> kalınlık, kesikli, 3B, geofence; şekil değişmez). Şekil = köşe tutamaçları: köşeye dokun → seçilir,
> haritaya / nesneye dokun → oraya taşınır; kenar ortasındaki + köşe ekler; ortadaki tutamaç bütün
> şekli taşır (boyut / yön korunur); dairede merkez + kenar (yarıçap); dikdörtgen eksenli kalır.
> Geri al, Köşeyi sil, İptal, Kaydet. Dokunma 24 pt toleransla (`domain/usecases/graphic_hit.dart`,
> kenar önce, sonra içindeki en küçük şekil); `domain/usecases/shape_edit.dart`. Çizimler listesinde
> satıra dokun = Düzenle. Sil Geri al'lı.
>
> Düzeltmeler (2026-11-11): kendi işaretin adı konum kutusundaki çağrı adından (GPS kaynağı
> varsayılan "KERTERIZ-1"i taşıyordu); düğmeli uyarı şeritleri Flutter'da varsayılan kalıcı
> (`SnackBar.persist`) → `persist: false`, Geri al süresi 3 sn.
>
> G7: **İçe aktar** (≡ → Veri ya da Noktalar / İzler listesi): KMZ, KML, GPX, GeoJSON; biçim
> içerikten anlaşılır (seçici bütün dosyaları gösterir: iOS KMZ / GeoJSON'u tanımadığı için
> file_picker onları seçilemez yapıyordu). KML: Point → nokta, LineString / `gx:Track` → iz,
> Polygon → alan çizimi (Style / StyleMap rengi ve kalınlığı), MultiGeometry, HTML açıklama nota
> (resimler KMZ'den noktaya fotoğraf). GeoJSON: Point / LineString / Polygon + Multi* ve
> GeometryCollection, simplestyle renkleri. Eklemeden önce önizleme (kaç nokta, çizim, iz,
> fotoğraf) ve onay; aynı kimlik zaten varsa atlanır (`data/import/import_writer.dart`).
> **Dışa aktar** (≡ → Veri; lasso seçim panelinde de): tür seçimi (noktalar, çizimler, izler, R&B,
> halkalar) ve biçim: KMZ (fotoğraflarla), KML, GPX (yalnız noktalar + izler), GeoJSON →
> paylaşım (`data/export/geo_exporter.dart`). Pusula'dan Pusula'ya kayıpsız: daire, kalınlık,
> kesikli, 3B, geofence, sembol (birlik / kademe / rol / CoT tipi), yükseklik, görüş konisi, kimlik
> KML `ExtendedData` ("kerteriz" JSON) / GeoJSON "kerteriz" özelliğinde; başka uygulamalar düz
> geometri görür. Güvenlik: dosya ≤ 50 MB; KMZ ≤ 1000 girdi, girdi ≤ 30 MB, toplam ≤ 150 MB
> (açmadan önce bildirilen boyutla; `archive` açarken de bildirilen boyutu aşmaz); `..`, mutlak,
> ters bölü ve sürücü harfli yollar yok sayılır; yalnız noktaların başvurduğu resimler okunur;
> koordinatlar aralık denetiminden geçer. SHP desteklenmiyor. "Kerteriz ile aç" (AirDrop /
> Dosyalar'dan doğrudan açma) yok: G8'de.
>
> G8: **Veri paketi** (Mission Package v2; biçim kamuya açık kaynaklardan doğrulandı: TAK
> eğitim belgesi + MIT lisanslı node-CoT, ATAK kodu kullanılmadı). Zip: `MANIFEST/manifest.xml`
> (`MissionPackageManifest version="2"`, Configuration `uid` / `name`, her dosya için `Content
> zipEntry ignore`), nesneler `<uid>/<uid>.cot`, fotoğraflar `<uid>/foto_n.jpg` (manifestte
> `Parameter uid` = noktanın uid'i). **Dışa aktar** → "Veri paketi": noktalar (+ fotoğraf),
> çizimler, rotalar CoT; R&B, halkalar, izler `kerteriz/ekler.kml`. Pusula ayrıntısı CoT
> `<__kerteriz>` JSON (ATAK yok sayar) → kayıpsız. Oluşturan: kalıcı cihaz kimliği
> `KERTERIZ-<uuid>` (ayarlar `device_uid`) + çağrı adı. **İçe aktar**: zip manifest ya da `.cot`
> içeriyorsa paket; manifestsizse aynı klasördeki resim o CoT'a eklenir; paket içindeki
> KML / KMZ / GPX / GeoJSON da okunur (iç içe paket açılmaz). Önizleme: paket adı, sayılar,
> **alınmayacaklar** ve nedeni (`.pref` ayar dosyası, `.apk`, "yok say" işaretli, desteklenmeyen
> CoT türü ör. `u-d-c-c`, bağsız resim, güvensiz yol, tanınmayan dosya). Manifestteki
> `onReceiveAction` / `onReceiveImport` / `onReceiveDelete` yok sayılır (ATAK zaafları 3–4).
> **"Kerteriz ile aç"**: Info.plist `CFBundleDocumentTypes` (zip, kmz, kml, gpx, geojson;
> `LSHandlerRank` Alternate) + içe alınan UTI'ler; `AppDelegate.swift` IncomingFilesPlugin
> (Flutter sahne kancası `addSceneDelegate`; dosya geçici klasöre kopyalanır, Inbox kopyası
> silinir) → `kerteriz/incoming_files` kanalı → önizleme. Rotalar G7 biçimlerine de eklendi
> (KML / GeoJSON kayıpsız, GPX `rte`).
>
> G5: **Hızlı fotoğraf** (≡ → Veri): kamerayı açar; çekilen fotoğraf konumumda (konum yoksa harita
> ortasında) yeni FOTO-n noktasına eklenir (not: "Hızlı fotoğraf gg.aa.yyyy ss:dd"). **Galeri**:
> bütün nokta fotoğrafları 3 sütun; dokununca tam ekran, "Haritada göster" noktaya gider.

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

Durum (2026-11-14, kodda tamam, cihaz testi bekliyor). Kullanıcı kararları: çevrimdışı sokak /
arazi = Mapbox; "Vektör — Türkiye" kalır ama yol gösterir; ek olarak yalnız GeoPackage.
**Ertelendi:** KMZ resim katmanı (GroundOverlay), pafta oturtma (Rubber Sheet), özel WMS / XYZ,
GeoTIFF.

> H1: Katmanlar'da Mapbox **Uydu** / **Sokak** / **Topografik** (Outdoors: eş yükselti eğrileri,
> patikalar) — `BaseLayerSourceType.mapboxStyle` + `OfflineMapType` (stil adresinin tek kaynağı;
> haritadaki stil = indirilen stil, testle korunur). Uydu'nun id'si `online_satellite` kaldı
> (kayıtlı görünümler). OSM ve OpenTopoMap "yalnız çevrimiçi" (toplu indirme yasak).
>
> H2: Çevrimdışı haritalar → Yeni bölge: **Harita türü** (Uydu / Sokak / Topografik; çoklu, en az
> biri; varsayılan seçili katmanın türü). Her tür için stil paketi + karo tanımı, DEM bir kez;
> metadata `styles`, eski bölgeler Uydu. Bölge listesinde türler. İnternetsizken o türün katmanı
> indirilen bölgede çizilir.
>
> H3: Dosyası olmayan katman (ör. "Vektör — Türkiye" → turkey.pmtiles) seçilmez; pencere: **İçe
> aktar** ya da **Sokak'ta bölge indir**. Listede "dosya yok · dokun: nasıl eklenir". Yerleşik
> katmanın dosya adıyla içe aktarılan dosya ayrı kayıt oluşturmaz, o katmanı etkinleştirir.
>
> H4: **GeoPackage raster** (.gpkg) "Harita paketi içe aktar" ile: yalnız EPSG:3857, küresel
> ızgaraya hizalı (gdal `TILING_SCHEME=GoogleMapsCompatible`); `data/tiles/gpkg_grid.dart` (saf
> eşleme) + `gpkg_reader.dart` (sqlite3 salt-okunur) → yerel karo sunucusu; içerik türü karo
> başına imzadan (karışık PNG / JPEG). `sqlite3` doğrudan bağımlılık oldu (2.9.4, yeni indirme yok).
> Acil silmede "haritaları koru" .gpkg'yi de korur.

| Özellik (ATAK s.) | Ne yapılacak | Efor |
|---|---|---|
| GeoPackage raster (51) | SQLite karo tablosu; mevcut yerel karo sunucusu üzerinden gösterilir | M |
| Özel WMS/WMTS/XYZ (liste) | Çevrimiçi kaynak ekleme (ör. kamu ortofotosu). Google/Esri karolarını toplu indirmek lisans gereği yine yasak | M |
| GeoTIFF (51) | Yalnızca WGS84 / Web Mercator. Diğer projeksiyonlar pusula-tiler ile dönüştürülür | L |
| KMZ görüntü katmanı (51) | GroundOverlay desteği | S |
| Rubber Sheet (52) | Kâğıt pafta fotoğrafını 4 köşesinden haritaya oturtma | L |

### Aşama I: Güvenlik, saha konforu, raporlar

Durum (2026-11-11, kodda tamam, cihaz testi bekliyor): **I3** saha konforu, **I4** raporlar,
**I5** hava durumu, **I2** şifreli yedek. **I1** şifreli veritabanı (SQLCipher) kullanıcı kararıyla
şimdilik yok. Paketler (onaylı): `wakelock_plus` 1.5.2 (`share_plus` 12 ile `win32` uyumu için
1.8 değil), `battery_plus` 7.1.2, `http` 1.6.0 (dolaylıdan doğrudana), `cryptography` 2.9.0.

> I3: Ayarlar → **Ekranı açık tut** (Kapalı / Görevde = iz kaydı, rota takibi ya da Git hedefi
> varken / Her zaman; varsayılan Görevde), **İz kaydı kendiliğinden dursun** (Kapalı / 1 / 2 / 4 sa;
> kayıt başlarken şerit, süre dolunca titreşim + şerit + sesli / bildirim; zamanlayıcı + her
> konumda denetim), **Düşük pil uyarısı** (%20, %10, %5; şarjda ya da %25 üstünde sıfırlanır).
> **Güneş ve ay** (≡ → Saha): bugün / yarın BMNT, BMCT, doğum, öğle, batım, EECT, EENT, gün ışığı,
> ay doğuşu / batışı, evre ve aydınlık %; şu anki ışık durumu. Cihazda hesap
> (`domain/usecases/sun_moon.dart`; güneş: gün doğumu denklemi, ay: Astronomical Almanac düşük
> duyarlıklı formülleri); USNO API değerleriyle ±1 dk doğrulandı (Ankara, 15 Kasım ve 21 Haziran 2026).
>
> I4: **Raporlar** (≡ → Saha): CASEVAC 9 satır (öncelik / tür / uyruk sayaçları, teçhizat,
> güvenlik, işaretleme, KBRN + arazi) ve SPOTREP (SALUTE); konum MGRS (Konumum / Harita ortası /
> elle), DTG "111530Z KAS 26". Paylaş, Kopyala, **Haritaya ekle** (CASEVAC-n toplanma noktası /
> SPOT-n düşman, not = rapor). Ağdan gönderme Faz 2.
>
> I5: **Hava durumu** (≡ → Saha): Open-Meteo (anahtarsız), yalnız Güncelle'ye basınca; konum 0,1°
> (~11 km) yuvarlanır. Şimdi: durum, sıcaklık / hissedilen, rüzgâr (estiği yön, hız, hamle), görüş,
> bulut, nem, basınç; 24 saatlik tahmin. Son yanıt ayarlarda önbellekli (internetsiz de görünür).
>
> I2: **Yedekle / geri yükle** (≡ → Sistem): `.krz` = "KRTZYDK1" + PBKDF2-HMAC-SHA256 (300 bin tur)
> + AES-256-GCM şifreli zip (`kerteriz.sqlite` = `VACUUM INTO` kopyası, `attachments/`,
> `yedek.json`). Harita dosyaları ve yükseklik verisi girmez. Geri yükleme bağlantıyı kapatmaz:
> yedek ayrı açılıp güncel şemaya yükseltilir, `ATTACH` + tek işlemde sütun adlarıyla kopyalanır
> (eski veritabanlarında sütun sırası farklı); içe aktarılmış harita katmanları korunur; fotoğraf
> klasörü kenara alınıp değiştirilir (hata olursa geri konur). "Kerteriz ile aç" `.krz`'yi de açar
> (`UTExportedTypeDeclarations` com.kerteriz.backup). Ayarlar uygulama yeniden açılınca geçerli.

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
