import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/coord_format.dart';
import '../../domain/models/attachment.dart';
import '../../domain/models/bullseye.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/waypoint.dart';
import '../../providers/bullseye_providers.dart';
import '../../providers/elevation_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../tools/bullseye_panel.dart';
import 'fov_editor.dart';

/// Fotoğraf seçici: kamera ya da arşiv → dosya yolu (vazgeçildiyse null).
/// Testte sahtesi takılır.
typedef PickPhoto = Future<String?> Function(ImageSource source);

final pickPhotoProvider = Provider<PickPhoto>(
  (ref) => (source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      // Saha fotoğrafı için yeterli; cihaz belleği şişmesin.
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    return x?.path;
  },
);

/// Nokta detayı (ATAK Details, kılavuz s.11): ad, koordinat, yükseklik,
/// not, eylemler ve fotoğraflar. Noktayı canlı izler (düzenleyince
/// güncellenir); eylem düğmeleri paneli kapatıp işi çağırana bırakır.
class WaypointDetailPanel extends ConsumerWidget {
  const WaypointDetailPanel({
    super.key,
    required this.initial,
    required this.onCenter,
    required this.onGo,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
  });

  /// Açılıştaki hali (liste gelene kadar ve nokta silinirse).
  final Waypoint initial;
  final ValueChanged<Waypoint> onCenter;
  final ValueChanged<Waypoint> onGo;
  final ValueChanged<Waypoint> onEdit;
  final ValueChanged<Waypoint> onShare;
  final ValueChanged<Waypoint> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wp =
        ref
            .watch(waypointsProvider)
            .value
            ?.where((w) => w.id == initial.id)
            .firstOrNull ??
        initial;
    final format = ref.watch(coordFormatProvider);

    void popThen(ValueChanged<Waypoint> action) {
      Navigator.of(context).pop();
      action(wp);
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          wp.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          CoordFormat.format(wp.position, format),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          CoordFormat.wgs84(wp.position),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        ElevationLine(waypoint: wp),
        BullseyeCallLine(waypoint: wp),
        FovSection(waypoint: wp),
        if (wp.note != null && wp.note!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(wp.note!),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => popThen(onCenter),
              icon: const Icon(Icons.my_location),
              label: const Text('Ortala'),
            ),
            OutlinedButton.icon(
              onPressed: () => popThen(onGo),
              icon: const Icon(Icons.navigation),
              label: const Text('Git'),
            ),
            OutlinedButton.icon(
              onPressed: () => popThen(onEdit),
              icon: const Icon(Icons.edit),
              label: const Text('Düzenle'),
            ),
            OutlinedButton.icon(
              onPressed: () => onShare(wp),
              icon: const Icon(Icons.ios_share),
              label: const Text('Paylaş'),
            ),
            OutlinedButton.icon(
              // Tek bullseye: varsa yerini alır. Nokta taşınınca o da gider.
              onPressed: () {
                final had = ref.read(bullseyeProvider) != null;
                ref
                    .read(bullseyeProvider.notifier)
                    .set(
                      Bullseye(
                        center: RbEnd(
                          wp.position,
                          RbEnd.waypointRef(wp.uid),
                        ),
                        name: wp.name,
                      ),
                    );
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${wp.name} bullseye yapıldı'
                      '${had ? ' (öncekinin yerine)' : ''}.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.track_changes),
              label: const Text('Bullseye yap'),
            ),
            OutlinedButton.icon(
              onPressed: () => popThen(onDelete),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AttachmentStrip(itemUid: wp.uid),
      ],
    );
  }
}

/// Yükseklik: elle girildiyse o, değilse arazi verisinden (≈). CoT'tan
/// gelen elipsoit yüksekliği (HAE) varsa ayrıca.
class ElevationLine extends ConsumerWidget {
  const ElevationLine({super.key, required this.waypoint});

  final Waypoint waypoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manual = waypoint.elevation;
    final String text;
    if (manual != null) {
      text = 'Yükseklik: ${manual.round()} m MSL (elle)';
    } else {
      text = ref
          .watch(terrainElevationProvider(waypoint.position))
          .when(
            data: (m) => m == null
                ? 'Yükseklik: bilinmiyor (arazi verisi yok)'
                : 'Yükseklik: ≈ $m m MSL (arazi verisi)',
            loading: () => 'Yükseklik: …',
            error: (_, _) => 'Yükseklik: bilinmiyor',
          );
    }
    final hae = waypoint.hae;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (hae != null)
            Text(
              'HAE ${hae.round()} m (elipsoit, CoT)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Bir nesnenin fotoğrafları: ekle (kamera / arşiv), küçük resimler,
/// dokununca tam ekran (yakınlaştır, sil). Fotoğraflar cihazda kalır.
class AttachmentStrip extends ConsumerWidget {
  const AttachmentStrip({super.key, required this.itemUid});

  final String itemUid;

  static const double thumb = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos =
        ref.watch(attachmentsProvider(itemUid)).value ?? const <Attachment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              photos.isEmpty ? 'Fotoğraflar' : 'Fotoğraflar (${photos.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Fotoğraf çek',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => _add(context, ref, ImageSource.camera),
            ),
            IconButton(
              tooltip: 'Arşivden ekle',
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: () => _add(context, ref, ImageSource.gallery),
            ),
          ],
        ),
        if (photos.isEmpty)
          const Text(
            'Henüz fotoğraf yok.',
            style: TextStyle(color: Colors.grey),
          )
        else
          SizedBox(
            height: thumb,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final a = photos[i];
                return Semantics(
                  button: true,
                  label: 'Fotoğraf ${i + 1}',
                  child: GestureDetector(
                    onTap: () => _view(context, ref, a),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(a.filePath),
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        cacheWidth: (thumb * 3).round(),
                        errorBuilder: (_, _, _) => Container(
                          width: thumb,
                          height: thumb,
                          color: Colors.white10,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final pick = ref.read(pickPhotoProvider);
    final repo = ref.read(attachmentRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await pick(source);
      if (path == null) return; // vazgeçildi
      await repo.addFile(itemUid, File(path));
    } catch (e) {
      // Ör. kamera izni verilmedi.
      messenger.showSnackBar(
        SnackBar(content: Text('Fotoğraf eklenemedi: $e')),
      );
    }
  }

  Future<void> _view(BuildContext context, WidgetRef ref, Attachment a) {
    final repo = ref.read(attachmentRepositoryProvider);
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _PhotoViewer(attachment: a, onDelete: () => repo.delete(a)),
    );
  }
}

/// Tam ekran fotoğraf: iki parmakla yakınlaştır; silme onaylı.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.attachment, required this.onDelete});

  final Attachment attachment;
  final Future<void> Function() onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotoğraf silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await onDelete();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = attachment.createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final when =
        '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.file(
                  File(attachment.filePath),
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    when,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                IconButton(
                  tooltip: 'Fotoğrafı sil',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
