# Pusula — Faz 2 Brief'i (Mesh / Meshtastic)

> Faz 1 (kişisel, çevrimdışı taktik harita) tamamlandı ve cihazda doğrulandı.
> Faz 2, internetsiz bir ekibin (squad) Meshtastic LoRa düğümleriyle konum,
> waypoint ve metin paylaşmasını ekler. Bu dosya `CLAUDE.md` §7'yi
> güncel ekosistem doğrulamasıyla genişletir.

---

## 0. Hedef

İnternet/baz istasyonu olmadan, **LoRa mesh** üzerinden:
- Ekip üyelerinin konumlarını haritada callsign'lı işaretçi olarak görmek,
- Waypoint paylaşmak,
- Basit taktik metin mesajlaşması.

Donanım: kullanıcının **Meshtastic düğümü** (telefona BLE ile bağlanır).
Hedef bölge: **EU_868**.

---

## 1. Ekosistem Doğrulaması (2026-06 — pub.dev + meshtastic.org)

| Konu | Durum |
|---|---|
| Resmi/topluluk **Dart `meshtastic` paketi** | **YOK** (pub.dev'de bulunamadı) → kendimiz yazacağız |
| BLE | `flutter_blue_plus 2.3.4` (stable) |
| Protobuf runtime | `protobuf 6.0.0` |
| Protobuf derleyici | `protoc` + `protoc_plugin` (Dart) — kullanıcı makinesinde kurulmalı (Adım 10) |
| `.proto` kaynağı | `github.com/meshtastic/protobufs` (submodule/kopya olarak alınacak) |

### Meshtastic BLE protokolü (doğrulanmış)
- **Service UUID:** `6ba1b218-15a8-461f-9fa8-5dcae273eafd`
- **ToRadio** (write): `f75c76d2-129e-4dad-a1dd-7866124401e7` — telefon → düğüm (ToRadio protobuf)
- **FromRadio** (read): `2c55e69e-4993-11ed-b878-0242ac120002` — düğüm → telefon (FromRadio protobuf)
- **FromNum** (notify): `ed9da18c-a800-4f66-a670-aa7547e34453` — yeni paket sayacı; notify gelince
  FromRadio'yu sayaca yetişene kadar oku.
- Akış: bağlanınca **`ToRadio.want_config_id`** (startConfig) yaz → düğüm NodeDB +
  yapılandırmayı FromRadio üzerinden gönderir. Tüm veri Protocol Buffers.
- BLE eşleşmesi genelde PIN ister (varsayılan `123456`).

---

## 2. Mimari (Faz 1'de hazırlanan kancalar)

Faz 1'de soyutlamalar baştan kondu; Faz 2 bunlara **takılır**, harita/HUD koduna
neredeyse dokunmadan:

- `domain/ports/PositionSource` → yeni impl **`MeshPositionSource`**
  (düğümlerden gelen konumları `Stream<List<Contact>>` olarak yayar).
  Mevcut `DevicePositionSource` ile birlikte çalışmalı (kendi GPS + mesh düğümleri).
- `domain/ports/CommsChannel` → yeni impl **`MeshCommsChannel`**
  (metin + waypoint gönder/al). Faz 1'de `NullCommsChannel` vardı.
- Yeni veri katmanı: `data/mesh/` (BLE bağlantısı, protobuf çerçeveleme, NodeDB).
- Riverpod: `meshConnectionProvider`, aktif `PositionSource`'u GPS↔Mesh(+GPS birleşik)
  seçen bir katman.

> Önemli karar: v1'de tek `Contact` (kendimiz). Faz 2'de harita **birden çok**
> `Contact` çizecek (kendi GPS + her mesh düğümü ayrı callsign). `selfContact`
> mantığı `isSelf` ile zaten ayrık; mesh contact'lar `isSelf=false`.

---

## 3. Adımlar

Her adım sonunda: derlenir, çalışır, kısa "nasıl test edilir" notu. Donanım
gerektiren adımlarda derlemeyi/testi kullanıcı yapar.

### Adım 9 — BLE bağlantısı
- `flutter_blue_plus` ile tarama: Meshtastic Service UUID'sine göre filtrele.
- Cihaz listesi UI'ı (bulunan düğümler), seç → bağlan, eşleşme PIN'i.
- iOS: `Info.plist`'e `NSBluetoothAlwaysUsageDescription` (+ gerekiyorsa
  `NSBluetoothPeripheralUsageDescription`). Android: BLE + konum izinleri.
- `data/mesh/ble_connection.dart`: bağlan/kes, bağlantı durumu akışı.
- **Kabul:** Tarama düğümü buluyor, bağlanılıyor, bağlantı durumu HUD/panelde görünüyor.
  (Donanım: Meshtastic düğümü gerekir.)

### Adım 10 — Protobuf entegrasyonu
- `meshtastic/protobufs` `.proto` dosyalarını projeye al (`protos/` veya submodule).
- `protoc` + `protoc_plugin` ile Dart'a derle (`lib/data/mesh/gen/`).
- BLE çerçeveleme: ToRadio yaz / FromRadio oku / FromNum notify döngüsü.
- Bağlanınca `want_config_id` ile config iste; gelen FromRadio paketlerini ayrıştır.
- **Kabul:** Düğümden gelen FromRadio paketleri (NodeInfo, Position) loglanıp ayrıştırılıyor.

### Adım 11 — Mesh konumları → harita
- `MeshPositionSource` (PositionSource impl): NodeDB + Position paketlerinden
  her düğüm için `Contact` (callsign = node short/long name).
- Aktif kaynak katmanı: kendi GPS + mesh contact'ları birleştir.
- Harita çoklu `Contact` çizer (kendi mavi ok + diğerleri farklı renk/etiket).
- **Kabul:** İkinci bir düğüm hareket edince haritada callsign'lı işaretçi güncelleniyor.

### Adım 12 — Waypoint paylaşımı (mesh)
- `MeshCommsChannel.shareWaypoint` → Meshtastic Waypoint mesajı (ToRadio).
- Gelen Waypoint mesajları → haritada paylaşılan waypoint olarak göster (drift'e
  opsiyonel kaydet).
- **Kabul:** Bir düğümden gönderilen waypoint diğerinin haritasında beliriyor.

### Adım 13 — Metin mesajlaşma
- `MeshCommsChannel.sendText` / `incomingText` → Meshtastic text mesajları (kanal 0 / primary).
- Basit taktik sohbet ekranı (gönder/al, callsign'lı).
- **Kabul:** İki düğüm arası metin gidip geliyor.

---

## 4. Donanım & Test Gereksinimleri

- **En az 1 Meshtastic düğümü** (Adım 9-10 için), anlamlı mesh testi için **2 düğüm**
  (Adım 11-13). EU_868 bölgesinde yapılandırılmış.
- iOS BLE: fiziksel cihaz şart (simülatörde BLE yok). İmzalama/test kullanıcıda.
- `protoc` araç zinciri (Adım 10) kullanıcı makinesinde kurulu olmalı.

---

## 5. Riskler / Açık Konular

- Dart resmi paketi olmadığından protobuf+BLE çerçevelemeyi elle yazıyoruz;
  referans: resmi **Android (Kotlin)** ve **iOS (Swift)** uygulamaları, `@meshtastic/js`,
  `python.meshtastic.org`.
- BLE eşleşme/PIN ve iOS arka plan kısıtları cihazdan cihaza değişebilir.
- Protokol sürümü değişebilir; `.proto`'ları güncel master'dan almak gerekir.

---

## 6. ŞİMDİ YAP

**Faz 2 / Adım 9**'dan başla:
1. `flutter_blue_plus` ekle (onay), iOS `Info.plist` Bluetooth izinleri.
2. Meshtastic Service UUID'sine göre tarama + cihaz listesi + bağlan/kes.
3. `data/mesh/ble_connection.dart` + bağlantı durumu provider'ı + basit panel.
4. Bittiğinde: 3-4 satır özet + "nasıl test edilir" (donanım notuyla).
Sonra Adım 10 için onay bekle.

---

## 7. Adım 9 — Kararlaştırılan Detaylı Plan

> Durum: **planlandı, kod yok.** Donanım henüz yok → uygulama, kullanıcı bir
> Meshtastic düğümü edinince (ya da istenirse mock kaynakla) yapılacak.

**Kapsam:** tara → listele → bağlan/kes → durum göster. Protobuf/veri Adım 10.

**Paket & izin:** `flutter_blue_plus ^2.3.4` (onayla eklenecek). iOS `Info.plist`:
`NSBluetoothAlwaysUsageDescription`. Bluetooth kapalı/izin reddi durumları yönetilir.
BLE eşleşme PIN'i genelde `123456` (OS diyaloğu).

**Dosyalar:**
- `lib/data/mesh/mesh_constants.dart` — §1'deki Service + ToRadio/FromRadio/FromNum UUID'leri.
- `lib/data/mesh/mesh_device.dart` — `MeshDevice{id, name, rssi}`.
- `lib/data/mesh/ble_connection.dart` — flutter_blue_plus sarmalayıcı: servis-filtreli
  tarama, connect/disconnect, discoverServices → 3 karakteristik + FromNum notify aboneliği,
  `Stream<MeshConnState>` (disconnected/scanning/connecting/connected/error). Ham
  karakteristikleri Adım 10 için dışa verir.
- `lib/providers/mesh_providers.dart` — `bleConnectionProvider`, `meshScanProvider`,
  `meshConnStateProvider`.
- `lib/features/mesh/mesh_panel.dart` — tarama/bağlan paneli.

**UI KARARI:** Mesh erişimi **katman paneline** eklenecek (yeni FAB yok). Mevcut
`_openLayerSwitcher` bottom sheet'ine "Mesh" bölümü: Bluetooth durumu + "Tara" + bulunan
düğümler + bağlan/kes + durum. Bağlıyken HUD'da küçük yeşil mesh rozeti.

**Kabul (donanım gerekir):** tarama düğümü bulur, bağlanır, panel/HUD "Bağlı" gösterir.

**Mimari:** `ble_connection` ham karakteristik verir → Adım 10 protobuf çerçevelemesi
(ToRadio yaz / FromRadio oku / `want_config_id`) bunun üstüne kurulur → Adım 11-12
`MeshPositionSource`/`MeshCommsChannel` ile Faz 1 kancalarına bağlanır.
