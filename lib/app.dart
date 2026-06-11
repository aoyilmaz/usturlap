import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'features/map/map_screen.dart';

/// Uygulamanın kök widget'ı. Tema ve ana ekranı bağlar.
///
/// Gece modu teması Adım 8'de gelecek; şimdilik koyu bir tema kullanıyoruz
/// (saha kullanımı için göz yormayan, taktik harita görünümüne yakın).
class PusulaApp extends StatelessWidget {
  const PusulaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MapScreen(),
    );
  }
}
