import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';
import 'core/constants.dart';
import 'core/restart_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Mapbox token'ı derlemede --dart-define ile gelir (koda gömülmez).
  if (AppConstants.mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
  }
  // RestartScope: acil veri silmeden sonra uygulamayı sıfırdan kurar.
  // ProviderScope: tüm riverpod provider'larının kök kapsayıcısı.
  runApp(const RestartScope(child: ProviderScope(child: KerterizApp())));
}
