import 'dart:io';

import 'package:flutter/services.dart';

import 'dem_tile.dart';
import 'elevation_store.dart';

/// Çevrimdışı yükseklik okuyucusu (adı tarihsel; HGT ve DTED okur).
///
/// Belgeler/tiles_external içindeki 1°×1° kareleri (`N37E037.hgt`,
/// `.dt0/.dt1/.dt2`; bkz. [ElevationStore]), yoksa uygulamayla gelen
/// örnekleri kullanır. Kareler gerektikçe yüklenir; en çok [maxTiles] kare
/// bellekte tutulur (SRTM 1″ kare ~25 MB). Bulunamayan kare de önbelleğe
/// alınır: görüş alanı gibi binlerce sorguda diske tekrar tekrar bakılmaz.
class HgtParser {
  HgtParser({
    Future<Directory?> Function()? directory,
    Future<Uint8List?> Function(String key)? bundled,
  }) : _directory = directory ?? defaultElevationDirectory,
       _bundled = bundled ?? _loadAsset;

  static const maxTiles = 4;

  final Future<Directory?> Function() _directory;
  final Future<Uint8List?> Function(String key) _bundled;

  /// Anahtar → yüklenen kare (null = yok). Ekleme sırası = kullanım sırası.
  final _tiles = <String, Future<DemTile?>>{};

  /// Yüklenmesi bitmiş ve veri bulunan kareler (bellekte yer tutanlar).
  final _present = <String>{};

  Directory? _dir;
  Future<void>? _ready;

  /// Klasörü bir kez hazırlar ([getElevation] bekler).
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    try {
      _dir = await _directory();
    } catch (_) {
      _dir = null; // izin / platform: veri yok, hata da yok
    }
  }

  /// Konumun düştüğü kare (yoksa null).
  Future<DemTile?> tileAt(double lat, double lon) async {
    await init();
    final s = lat.floor(), w = lon.floor();
    final key = DemTile.keyFor(s, w);
    final hit = _tiles.remove(key);
    if (hit != null) {
      _tiles[key] = hit; // en sona: yakın zamanda kullanıldı
      return hit;
    }
    final f = _load(key, s, w).then(
      (t) {
        if (t != null && _tiles.containsKey(key)) {
          _present.add(key);
          _evict();
        }
        _pending.remove(key);
        return t;
      },
      onError: (Object e, StackTrace st) {
        // Okuma hatası (izin, G/Ç) önbellekte kalmasın: sonra yeniden dene.
        _tiles.remove(key);
        _pending.remove(key);
        return null;
      },
    );
    _tiles[key] = f;
    _pending[key] = f;
    _evict();
    return f;
  }

  final _pending = <String, Future<DemTile?>>{};

  /// Bellekte en çok [maxTiles] dolu kare (SRTM 1″ karesi ~26 MB; eskiden
  /// boş girişlerle birlikte sayıldığı için 8 dolu kare, ~200 MB kalabiliyordu).
  /// Boş ("bu karede veri yok") girişler ucuz; onlar ayrıca sınırlanır.
  void _evict() {
    while (_present.length > maxTiles) {
      final oldest = _tiles.keys.firstWhere(_present.contains);
      _tiles.remove(oldest);
      _present.remove(oldest);
    }
    while (_tiles.length > maxTiles * 8) {
      final k = _tiles.keys.first;
      _tiles.remove(k);
      _present.remove(k);
    }
  }

  Future<DemTile?> _load(String key, int south, int west) async {
    final dir = _dir;
    if (dir != null) {
      for (final ext in ['hgt', 'dt2', 'dt1', 'dt0']) {
        final file = File('${dir.path}/$key.$ext');
        if (!await file.exists()) continue;
        try {
          return DemTile.parse(
            await file.readAsBytes(),
            south: south,
            west: west,
          );
        } on FormatException {
          continue; // bozuk dosya: sıradakine bak
        }
      }
    }
    final bytes = await _bundled(key);
    if (bytes == null) return null;
    try {
      return DemTile.parse(bytes, south: south, west: west);
    } on FormatException {
      return null;
    }
  }

  static Future<Uint8List?> _loadAsset(String key) async {
    try {
      final data = await rootBundle.load('assets/tiles/$key.hgt');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// Sınırlar içine düşen bütün kareler (olanlar).
  Future<List<DemTile>> tilesIn({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final out = <DemTile>[];
    for (var lat = south.floor(); lat <= north.floor(); lat++) {
      for (var lon = west.floor(); lon <= east.floor(); lon++) {
        final t = await tileAt(lat + 0.5, lon + 0.5);
        if (t != null) out.add(t);
      }
    }
    return out;
  }

  /// En yakın ızgara noktasının yüksekliği (m); veri yoksa null.
  Future<int?> getElevation(double lat, double lon) async =>
      (await tileAt(lat, lon))?.nearest(lat, lon);

  /// Çift doğrusal ara değerli yükseklik (m); veri yoksa null.
  Future<double?> elevationAt(double lat, double lon) async =>
      (await tileAt(lat, lon))?.sample(lat, lon);

  /// Dosyalar değişti (içe aktarma / silme): önbelleği boşalt.
  void invalidate() {
    _tiles.clear();
    _present.clear();
    _pending.clear();
  }
}
