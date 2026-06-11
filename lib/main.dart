import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // ProviderScope: tüm riverpod provider'larının kök kapsayıcısı.
  runApp(const ProviderScope(child: PusulaApp()));
}
