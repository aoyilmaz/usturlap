# Pusula — FAZ 2 Brief'i & Claude Code Prompt'u (Mesh / Meshtastic)

> Faz 1 bitti (kişisel, çevrimdışı harita çalışıyor). Bu dosyayı repoya `docs/faz2-brief.md`
> olarak koy ya da `CLAUDE.md` sonuna ekle. Claude Code'a: **"Faz 2'ye geçiyoruz, bu brief'i
> oku ve Adım 9'dan başla"** de.
>
> Bu faz, Faz 1'de bilinçli olarak koyduğumuz `PositionSource` ve `CommsChannel`
> soyutlamalarının üstüne oturur. Faz 1 kodunu **kırmadan** ekleme yapılır.

---

## 0. Ajanın Rolü

Kıdemli Flutter/Dart geliştiricisisin. Faz 2'de internetsiz "squad" yeteneği ekliyorsun:
Meshtastic LoRa mesh üzerinden takım konum takibi ve mesajlaşma + bunun üstüne kendi
uçtan uca şifreleme katmanımız. Kurallar Faz 1 ile aynı:

- Küçük, çalışan adımlarla ilerle; her adım derlenip çalışır kalsın.
- Paket ekleme/çıkarma, mimari değişiklik, dosya silme → **önce onay iste**.
- **Fiziksel donanım testi kullanıcının sorumluluğunda** (aşağıya bak). Sen kodu + test
  talimatını ver; çıktıyı kullanıcıdan iste.
- Kriptoyu **icat etme**; denenmiş kütüphaneyi olduğu gibi kullan.

---

## 1. Faz 2 Ne Ekliyor?

- Takım üyelerinin konumunu **internetsiz**, mesh üzerinden, yarı-anlık olarak haritada
  callsign'lı işaretçi olarak görmek.
- Mesh üzerinden metin mesajı ve waypoint paylaşımı.
- Tüm bunların üstüne, Meshtastic'in kendi şifrelemesinden **bağımsız, bizim kontrolümüzde**
  bir uçtan uca şifreleme katmanı (yakalansa bile içerik çözülemesin).
- Anahtar yönetimi + acil silme (panic wipe) gibi OPSEC özellikleri.

---

## 2. Kapsam ve Kritik Sınırlar (ÖNEMLİ)

- **Node firmware'ine DOKUNMUYORUZ.** Node'lar hazır açık kaynak Meshtastic firmware'i
  çalıştırır (kullanıcı flash'lar/yapılandırır). Biz **yalnızca telefon tarafındaki uygulamayı**
  yazıyoruz: telefon ↔ node arası BLE + protobuf.
- **Mesh yönlendirmesi firmware'in işi.** Uygulama tek bir node'a (kullanıcının taşıma node'u)
  BLE ile bağlanır; mesajların kaç hop'tan geldiği, hangi röleden geçtiği bizi ilgilendirmez.
  Biz sadece node'un veritabanındaki (NodeDB) kişileri ve gelen paketleri işleriz.
- **Donanım/flash/ayar kullanıcının tarafında** (Faz 1'deki Xcode imzalama gibi).
- **Dürüst teknik gerçek:** Bu fazın en zor parçası protobuf/BLE entegrasyonudur. Flutter/Dart
  için olgun, resmi bir Meshtastic kütüphanesi olmayabilir. **Başlamadan önce pub.dev ve
  Meshtastic protobuf reposunun güncel durumunu doğrula**; bakımlı bir Dart paketi varsa onu
  kullan, yoksa `.proto`'ları `protoc` ile kendin derle. Referans: resmi Android (Kotlin) ve
  iOS (Swift) istemcileri.

---

## 3. Donanım Topolojisi (uygulamanın bilmesi gereken bağlam)

Kullanıcının kuracağı üç rol var. Uygulama **kendi taşıma node'una** bağlanır; diğerleri
mesh'i genişletir ve uygulama için şeffaftır:

1. **Taşıma node'u** — RAK WisBlock (nRF52840 + SX1262, **EU868**). Telefona BLE ile bağlı.
   Uygulamanın konuştuğu node budur.
2. **Sabit/araç rölesi** — LilyGO T-Beam (EU868), balkon/araç tavanı. Menzil uzatır.
3. **Deployable solar röle** — yüksek noktaya bırakılan solar repeater (EU868).

Uygulama tasarımı node rolünden bağımsız olmalı: tek BLE bağlantısı + NodeDB + paketler.

---

## 4. Mimari (Faz 1 soyutlamalarının üstüne)

### 4.1 Transport katmanı
- `MeshTransport` — `flutter_blue_plus` ile node'a BLE bağlantısı; Meshtastic BLE servis/
  karakteristiklerini (toRadio / fromRadio / fromNum) sarmalar; bağlantı durumu yönetimi.

### 4.2 Protokol katmanı
- `MeshProtocol` — protobuf serileştirme/ayrıştırma (`ToRadio`, `FromRadio`, `MeshPacket`,
  `NodeInfo`, `Position`, `User`, `Data` vb.). NodeDB senkronizasyonu.

### 4.3 Domain port implementasyonları (Faz 1 arayüzleri)
- `MeshPositionSource implements PositionSource` — mesh'ten gelen konumları `Stream<List<Contact>>`
  olarak yayınlar; harita/HUD bunu zaten dinliyor (Faz 1).
- `MeshCommsChannel implements CommsChannel` — metin + waypoint gönder/al.

### 4.4 Şifreleme katmanı
- `CryptoLayer` — `MeshCommsChannel` ile protokol serileştirme **arasına** girer: giderken
  şifreler, gelirken çözer. (Detay §6.)

### 4.5 Anahtar deposu
- `KeyStore` — `flutter_secure_storage` (iOS Keychain / Android Keystore) sarmalayıcısı.
  Anahtarlar **yalnızca telefonda**; node'a asla yazılmaz.

Katman akışı (gönderim):
```
Pusula (düz metin)
  → CryptoLayer.encrypt (XChaCha20-Poly1305, takım anahtarı)   ← BİZİM KATMAN
    → MeshProtocol (protobuf paketle)
      → MeshTransport (BLE → node)
        → node Meshtastic kanal anahtarıyla tekrar şifreler → LoRa
```

---

## 5. Teknoloji Eklemeleri

> Sürümleri sabitlemeden önce pub.dev'den güncel stable'ı doğrula.

| Amaç | Paket / Araç |
|---|---|
| BLE | `flutter_blue_plus` |
| Protobuf | `protobuf` (+ `protoc` ile Meshtastic `.proto` derleme) |
| Kripto | `cryptography` (XChaCha20-Poly1305, X25519, HKDF) |
| Güvenli depo | `flutter_secure_storage` |
| QR (anahtar paylaşımı) | `qr_flutter` (üret) + `mobile_scanner` (oku) |

---

## 6. Şifreleme Tasarımı — `CryptoLayer` (anlaştığımız)

**Amaç:** Meshtastic kanal anahtarı (PSK) sızsa ya da bir node ele geçse bile içerik
çözülemesin; sahte/enjekte mesaj reddedilsin.

- **Algoritma:** **XChaCha20-Poly1305** (AEAD).
  - 24 baytlık nonce → her mesaj için rastgele üret (sayaç yönetimi yok).
  - 16 baytlık **Poly1305 doğrulama etiketi** → çözülürken bütünlük/orijinallik doğrulanır;
    sahte mesaj **çözme aşamasında reddedilir** (Meshtastic'in "PSK'i bilen spoof yapabilir"
    zaafını kapatır).
- **Anahtar:** rastgele 256-bit **takım anahtarı**. LoRa'da el sıkışma yapılmaz →
  **çevrimdışı/önceden dağıt** (QR kod / yüz yüze).
- **Depolama:** `flutter_secure_storage` (mümkünse Secure Enclave destekli Keychain).
  **Anahtar node'da değil, sadece telefonda.**
- **Anahtar döndürme:** ileri-gizlilik mesh'te tam sağlanamaz; pragmatik çözüm **periyodik
  anahtar rotasyonu** (günlük / göreve özel anahtar). Bir anahtar sızsa yalnızca o pencere açılır.
- **Paket bütçesi:** LoRa paketi ~256 bayt; kripto ek yükü (nonce + etiket ≈ 28-32 bayt) küçük
  paketten yer. Kısa metin/konum için sorun yok; uzun metin lüksü yok. Kodu bu bütçeyi
  gözeterek yaz (gerekirse uzun mesajı parçala).
- **İleri (v2, şimdi değil):** her node'a X25519 anahtar çifti → kişiye özel uçtan uca DM.

**Dikkat:** Meshtastic'in kendi şifrelemesini **kapatma**; bizimkini onun *üstüne* koy
(katmanlı/defense-in-depth). Kendi kripto algoritması yazma; `cryptography` paketinin
ilkellerini olduğu gibi kullan; nonce'u elle tekrarlama; anahtarı koda gömme.

**Kapsam dışı (kripto çözmez):** RF yayınının tespiti, yön bulma (DF), metadata, jamming.
Uygulama bunu gizleyeceği vaadini **vermez**; yalnızca yayın disiplinini kolaylaştıran
ayarlar sunar (§8).

---

## 7. Takım & Konum Takibi

- **Takım = kanal.** Ortak PSK'li bir Meshtastic kanalı = takım. Uygulama kanal üyelerini
  NodeDB'den okur.
- **Konum yayını periyodiktir** (saniye–dakika), sürekli akış değil. Uygulama gelen `Position`
  paketleriyle her üyenin işaretçisini günceller ("yarı-anlık").
- **Render:** her üye → haritada callsign + son konum + yaş (kaç sn önce). Bayatlayan konum
  görsel olarak soldurulur.
- **Ayarlanabilir aralık:** kullanıcı konum yayın aralığını seçebilsin. Uyarı metni: sık yayın =
  daha çok hava-zamanı + pil + **EU868 duty cycle (~%1) sınırı**.

---

## 8. OPSEC / Güvenlik Özellikleri (UI)

- **Panic wipe:** tek dokunuşla `KeyStore`'daki tüm anahtarları sil (onaylı).
- **Anahtar yönetimi ekranı:** takım anahtarı üret / QR ile paylaş / QR'dan al / döndür.
- **Varsayılan anahtar uyarısı:** Meshtastic varsayılan kanal anahtarı ("AQ==") tespit edilirse
  kullanıcıyı uyar (güvensiz).
- **Yayın disiplini:** elle "şimdi yayınla" modu + ayarlanabilir aralık; "yayın = tespit
  edilebilirlik" konusunda kısa bilgi notu.

---

## 9. ADIMLAR

Her adım sonunda: derlenir, çalışır, "gerçek node ile nasıl test edilir" notu verirsin.

**Adım 9 — BLE bağlantısı**
- `flutter_blue_plus` ile Meshtastic node tarama/bağlanma/yeniden bağlanma; bağlantı durumu UI.
- `MeshTransport` iskeleti (toRadio/fromRadio karakteristikleri).
- Kabul: uygulama gerçek RAK node'a (EU868) bağlanıp ham fromRadio verisi alıyor.

**Adım 10 — Protobuf entegrasyonu**
- Güncel Meshtastic `.proto`'larını Dart'a derle (ya da bakımlı paketi kullan).
- `FromRadio`/`ToRadio`, NodeInfo, Position, Data çözümleme; NodeDB modeli.
- Kabul: bağlı node ve mesh'teki düğümler ayrıştırılıp loglanıyor.

**Adım 11 — MeshPositionSource → harita**
- NodeDB + Position akışını `PositionSource` arayüzüne bağla; üyeleri callsign işaretçisi
  olarak göster (Faz 1 harita katmanı değişmeden çalışmalı).
- Kabul: ikinci bir node hareket edince haritada işaretçisi güncelleniyor.

**Adım 12 — MeshCommsChannel (mesaj + waypoint)**
- Metin gönder/al; Meshtastic Waypoint mesajı gönder/al → haritada göster.
- Kabul: iki cihaz arasında mesh üzerinden mesaj/waypoint gidip geliyor.

**Adım 13 — CryptoLayer (katmanlı şifreleme)**
- XChaCha20-Poly1305 ile şifrele/çöz; `MeshCommsChannel` ile protokol arasına yerleştir.
- Paket bütçesini gözet; gerekirse parçalama.
- Kabul: anahtarsız bir node mesajı çözemiyor; bozuk/sahte mesaj reddediliyor (birim testle de).

**Adım 14 — Anahtar yönetimi + güvenli depo**
- `KeyStore` (flutter_secure_storage); anahtar üret/QR paylaş/QR oku/döndür ekranı.
- Kabul: iki telefon QR ile aynı anahtarı paylaşıp şifreli haberleşiyor.

**Adım 15 — Panic wipe + OPSEC ayarları**
- Tek tuş panic wipe; konum yayın aralığı ayarı + duty cycle/uyarı notları; varsayılan anahtar uyarısı.
- Kabul: panic wipe sonrası şifreli kanal kapanıyor; ayarlar kalıcı.

---

## 10. Çalışma Şekli & Kalite

- Adım adım; aynı anda tek özellik; her adım çalışır.
- **Birim testleri:** CryptoLayer (şifrele→çöz round-trip, sahte mesaj reddi), protobuf çözümleme,
  NodeDB→Contact dönüşümü. Bunlar donanımsız test edilebilir; yaz.
- **Donanım testi kullanıcıda:** BLE/mesh simülatörde test edilemez. Kullanıcının elinde
  Meshtastic firmware'i yüklü, EU868'e ayarlı en az iki node olmalı. Sen her adımda net bir
  "iki node ile şu senaryoyu dene" talimatı ver.
- **Sürüm doğrulama:** BLE, protobuf, kripto paketlerini eklerken güncel stable'ı pub.dev'den
  kontrol et; Meshtastic protobuf şemasının güncel sürümünü kullan.
- **Sırlar:** anahtarları yalnızca secure storage'da tut; koda/log'a yazma.
- **Faz 1'i kırma:** mevcut `PositionSource`/`CommsChannel` tüketicileri (harita, HUD) değişmeden
  çalışmaya devam etmeli.

---

## 11. ŞİMDİ YAP

**Adım 9**'dan başla:
1. `flutter_blue_plus` ekle (güncel stable'ı doğrula).
2. `data/mesh/transport/` altında `MeshTransport` iskeletini ve BLE tarama/bağlanma/durum UI'sini yaz.
3. Bağlanınca ham `fromRadio` baytlarını logla (henüz ayrıştırma yok).
4. Bittiğinde: ne yaptığını 3-4 satırda özetle ve "gerçek RAK node (EU868) ile nasıl test edilir"
   talimatını yaz.
Sonra Adım 10 için onayımı bekle.
