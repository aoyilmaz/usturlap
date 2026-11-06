import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/restart_scope.dart';
import '../../providers/track_providers.dart';
import '../../providers/wipe_providers.dart';

/// Acil veri silme (ATAK "Clear Content", s.58): onay → sil → uygulamayı
/// sıfırdan başlat. Geri alınamaz.
Future<void> showClearContentDialog(BuildContext context, WidgetRef ref) async {
  var includeMaps = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever,
          color: Colors.redAccent,
          size: 36,
        ),
        title: const Text('Tüm veriler silinsin mi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Noktalar, izler, rotalar, grafikler, ayarlar ve dışa aktarılan '
              'dosyalar kalıcı olarak silinir. Geri alınamaz.',
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: includeMaps,
              onChanged: (v) => setState(() => includeMaps = v ?? true),
              title: const Text('Haritaları da sil'),
              subtitle: const Text(
                'İndirilen bölgeler, içe aktarılan paketler, yükseklik verisi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(132, 48),
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text(
              'ŞİMDİ SİL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;

  HapticFeedback.heavyImpact();
  // Silme sırasında ihtiyaç olacakları şimdiden al (ekranlar kapanabilir).
  final wiper = ref.read(contentWiperProvider);
  final recording = ref.read(recordingProvider.notifier);
  final rootContext = Navigator.of(context, rootNavigator: true).context;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Siliniyor…'),
          ],
        ),
      ),
    ),
  );

  try {
    // Açık iz kaydı silinen kayda nokta yazmaya çalışmasın.
    if (ref.read(recordingProvider).isRecording) await recording.stop();
    await wiper.wipe(includeMaps: includeMaps);
  } catch (e) {
    debugPrint('Acil silme hatası: $e');
  }
  // Bütün durumu sıfırdan kur (eski ekranlar, provider'lar, harita kapanır).
  if (rootContext.mounted) RestartScope.restart(rootContext);
}
