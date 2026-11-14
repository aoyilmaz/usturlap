import 'package:flutter/material.dart';

import 'base_layer.dart';

/// Dosyası cihazda olmayan katman için kullanıcının seçimi.
enum MissingLayerChoice { importFile, downloadStreets }

/// Dosyası olmayan katmana dokunulunca (ör. "Vektör — Türkiye" →
/// turkey.pmtiles yok) katman değiştirilmeden ne yapılacağını anlatır.
Future<MissingLayerChoice?> showMissingLayerDialog(
  BuildContext context,
  BaseLayerDef layer,
) {
  return showDialog<MissingLayerChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${layer.label}: dosya yok'),
      content: Text(
        'Bu katman cihazda “${layer.fileName}” dosyasıyla çalışır '
        '(Protomaps vektör harita, Türkiye ~0,8 GB). Dosya telefondaysa '
        '(Dosyalar, iCloud, AirDrop) “İçe aktar” ile seç.\n\n'
        'Dosyan yoksa çevrimdışı sokak haritası için “Sokak” katmanında '
        'bölge indirebilirsin.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(MissingLayerChoice.downloadStreets),
          child: const Text('Sokak\'ta bölge indir'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(MissingLayerChoice.importFile),
          child: const Text('İçe aktar'),
        ),
      ],
    ),
  );
}
