import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/sequential_name.dart';
import '../../core/uuid.dart';
import '../../domain/models/attachment.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/location_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';
import '../waypoints/waypoint_detail_panel.dart';

/// Hızlı fotoğraf (ATAK Quick Pic, kılavuz s.45): kamerayla çek, fotoğraf
/// bulunduğun yerde yeni bir noktaya (FOTO-n) eklensin. Konum yoksa
/// [fallback] (harita ortası). Sonucu kısa iletiyle söyler.
Future<void> quickPic(
  BuildContext context,
  WidgetRef ref, {
  required LatLng Function() fallback,
  ValueChanged<LatLng>? onCenter,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final pick = ref.read(pickPhotoProvider);
  final repo = ref.read(waypointRepositoryProvider);
  final photos = ref.read(attachmentRepositoryProvider);
  final self = ref.read(selfContactProvider)?.position;
  try {
    final path = await pick(ImageSource.camera);
    if (path == null) return; // vazgeçildi
    final at = self ?? fallback();
    final names = [
      for (final w in ref.read(waypointsProvider).value ?? const <Waypoint>[])
        w.name,
    ];
    final name = nextSequentialName('FOTO', names);
    final uid = newUuidV4();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    await repo.add(
      name: name,
      position: at,
      uid: uid,
      note:
          'Hızlı fotoğraf ${two(now.day)}.${two(now.month)}.${now.year} '
          '${two(now.hour)}:${two(now.minute)}'
          '${self == null ? ' (konum yoktu: harita ortası)' : ''}',
    );
    await photos.addFile(uid, File(path));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          '$name kaydedildi${self == null ? ' (harita ortasına)' : ''}.',
        ),
        persist: false,
        action: onCenter == null
            ? null
            : SnackBarAction(label: 'Göster', onPressed: () => onCenter(at)),
      ),
    );
  } catch (e) {
    // Ör. kamera izni verilmedi.
    messenger?.showSnackBar(SnackBar(content: Text('Fotoğraf eklenemedi: $e')));
  }
}

/// Galeri (ATAK Gallery, kılavuz s.45): bütün fotoğraflar, ait oldukları
/// noktanın adıyla; dokun → tam ekran (haritada göster, sil).
Future<void> showGalleryPanel(
  BuildContext context, {
  required ValueChanged<LatLng> onCenter,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'gallery',
    toggle: true,
    isScrollControlled: true,
    builder: (_) => GalleryPanel(onCenter: onCenter),
  );
}

class GalleryPanel extends ConsumerWidget {
  const GalleryPanel({super.key, required this.onCenter});

  final ValueChanged<LatLng> onCenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos =
        ref.watch(allAttachmentsProvider).value ?? const <Attachment>[];
    final byUid = {
      for (final w in ref.watch(waypointsProvider).value ?? const <Waypoint>[])
        w.uid: w,
    };
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final repo = ref.read(attachmentRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            photos.isEmpty ? 'Galeri' : 'Galeri (${photos.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (photos.isEmpty)
            Text(
              'Henüz fotoğraf yok. ≡ → Veri → Hızlı fotoğraf ya da bir '
              'noktanın Detay panelinden ekle.',
              style: TextStyle(color: muted),
            )
          else
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.82,
                ),
                itemCount: photos.length,
                itemBuilder: (context, i) {
                  final a = photos[i];
                  final wp = byUid[a.itemUid];
                  return Semantics(
                    button: true,
                    label: 'Fotoğraf: ${wp?.name ?? 'nokta yok'}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => PhotoViewer(
                          attachment: a,
                          title: wp?.name,
                          onDelete: () => repo.delete(a),
                          onShowOnMap: wp == null
                              ? null
                              : () => onCenter(wp.position),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(a.filePath),
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            wp?.name ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
