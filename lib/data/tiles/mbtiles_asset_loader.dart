import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

/// Gömülü bir `.mbtiles` asset'ini okunabilir bir dosya yoluna kopyalar.
///
/// MBTiles aslında bir SQLite dosyasıdır ve `sqlite3` onu ancak gerçek bir
/// dosya yolundan açabilir — uygulama paketindeki asset'i doğrudan açamaz.
/// Bu yüzden asset'i bir kez geçici dizine kopyalayıp o yolu döndürüyoruz.
class MbtilesAssetLoader {
  MbtilesAssetLoader._();

  /// [assetPath] (ör. 'assets/tiles/ankara_osm.mbtiles') asset'ini geçici
  /// dizine kopyalar ve kopyanın tam yolunu döndürür. Zaten kopyalanmışsa
  /// tekrar kopyalamaz.
  static Future<String> ensureLocalCopy(String assetPath) async {
    final fileName = assetPath.split('/').last;
    final outPath = '${Directory.systemTemp.path}/$fileName';
    final outFile = File(outPath);

    // Zaten kopyalanmışsa asset'i belleğe HİÇ alma (72 MB topo'yu her açılışta
    // okumamak için). Dosya adı sürümlü olduğundan (ör. _z10-16) içerik sabittir;
    // güncellenmiş aynı-adlı asset için uygulamayı yeniden kur.
    if (await outFile.exists() && await outFile.length() > 0) {
      return outPath;
    }

    final data = await rootBundle.load(assetPath);
    await outFile.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return outPath;
  }
}
