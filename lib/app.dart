import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'features/map/map_screen.dart';
import 'features/shell/panel_host.dart';

/// Uygulamanın kök widget'ı. Tema ve ana ekranı bağlar.
///
/// Gece modu teması Adım 8'de gelecek; şimdilik koyu bir tema kullanıyoruz
/// (saha kullanımı için göz yormayan, taktik harita görünümüne yakın).
class KerterizApp extends StatelessWidget {
  const KerterizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      // Paneller (menüler, listeler) haritanın üstünde, modal olmadan açılır.
      home: const PanelHost(child: MapScreen()),
    );
  }
}
