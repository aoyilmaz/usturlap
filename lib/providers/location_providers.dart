import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/position/device_position_source.dart';
import '../domain/models/contact.dart';
import '../domain/ports/position_source.dart';

/// Aktif `PositionSource`. v1'de telefon GPS'i; Faz 2'de buraya
/// `MeshPositionSource` takılacak — harita/HUD bu sağlayıcıyı dinlediği için
/// değişiklikten etkilenmezler (§4.1).
final positionSourceProvider = Provider<PositionSource>((ref) {
  final source = DevicePositionSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Kaynaktan gelen canlı `Contact` listesi akışı.
/// İlk dinleyici geldiğinde kaynağı başlatır, son dinleyici gidince durdurur.
final contactsProvider = StreamProvider<List<Contact>>((ref) {
  final source = ref.watch(positionSourceProvider);
  source.start();
  ref.onDispose(() => source.stop());
  return source.contacts;
});

/// Kendi konumumuz (varsa). HUD ve harita işaretçisi bunu kullanır.
final selfContactProvider = Provider<Contact?>((ref) {
  final async = ref.watch(contactsProvider);
  return async.maybeWhen(
    data: (list) {
      for (final c in list) {
        if (c.isSelf) return c;
      }
      return list.isNotEmpty ? list.first : null;
    },
    orElse: () => null,
  );
});
