import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup/backup_service.dart';
import '../../providers/track_providers.dart';
import '../../providers/waypoint_providers.dart';
import '../shell/adaptive_sheet.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);

/// Yedekle / geri yükle paneli (I2): bütün veri parolayla şifreli tek
/// dosyaya (`.krz`). Harita dosyaları ve yükseklik verisi girmez.
Future<void> showBackupPanel(BuildContext context) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'backup',
    isScrollControlled: true,
    builder: (ctx) => const BackupPanel(),
  );
}

class BackupPanel extends ConsumerWidget {
  const BackupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const Text(
          'Yedekle / geri yükle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Noktalar (fotoğraflarıyla), çizimler, izler, rotalar, ölçümler ve '
          'ayarlar parolayla şifrelenmiş tek dosyaya yazılır (AES-256). Harita '
          'dosyaları ve yükseklik verisi büyük olduğu için girmez. Parolayı '
          'unutursan yedek açılamaz.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _backup(context, ref),
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Yedekle'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickAndRestore(context, ref),
          icon: const Icon(Icons.restore),
          label: const Text('Geri yükle'),
        ),
      ],
    );
  }
}

/// Parola sorar; [confirm] ise iki kez (yeni yedek için).
Future<String?> askBackupPassword(
  BuildContext context, {
  required bool confirm,
}) {
  final a = TextEditingController();
  final b = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(confirm ? 'Yedek parolası' : 'Yedeğin parolası'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Parola'),
            ),
            if (confirm)
              TextField(
                controller: b,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Parola (tekrar)'),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (confirm && a.text.length < 8) {
                setLocal(() => error = 'En az 8 karakter.');
                return;
              }
              if (confirm && a.text != b.text) {
                setLocal(() => error = 'Parolalar aynı değil.');
                return;
              }
              if (a.text.isEmpty) return;
              Navigator.of(context).pop(a.text);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    ),
  );
}

/// Uzun işlem sürerken kapatılamaz bekleme penceresi.
Future<T> _withProgress<T>(
  BuildContext context,
  String text,
  Future<T> Function() work,
) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    nav.pop();
  }
}

Future<void> _backup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final password = await askBackupPassword(context, confirm: true);
  if (password == null || !context.mounted) return;
  try {
    final data = await _withProgress(
      context,
      'Yedekleniyor…',
      () => ref.read(backupServiceProvider).create(password),
    );
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final path =
        '${Directory.systemTemp.path}/usturlap_yedek_${now.year}'
        '${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.krz';
    await File(path).writeAsBytes(data, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'Usturlap yedeği'),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Yedeklenemedi: $e')));
  }
}

Future<void> _pickAndRestore(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final res = await FilePicker.pickFiles(type: FileType.any, withData: false);
  final path = res?.files.single.path;
  if (path == null || !context.mounted) return;
  try {
    final bytes = await File(path).readAsBytes();
    if (!context.mounted) return;
    await restoreBackupBytes(context, ref, bytes);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Geri yüklenemedi: $e')));
  }
}

/// Yedeği açar, özetini gösterip onay ister, geri yükler ("Usturlap ile
/// aç" ile gelen .krz de buradan geçer).
Future<void> restoreBackupBytes(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!BackupCrypto.looksLike(bytes)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Bu bir Usturlap yedeği değil.')),
    );
    return;
  }
  // Kayıt sürerken geri yükleme: izler yedektekilerle değişir, yeni
  // noktalar yedekteki aynı numaralı ize eklenirdi.
  if (ref.read(recordingProvider).isRecording) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('İz kaydı sürüyor. Geri yüklemek için önce kaydı durdur.'),
      ),
    );
    return;
  }
  final service = ref.read(backupServiceProvider);
  final password = await askBackupPassword(context, confirm: false);
  if (password == null || !context.mounted) return;
  final BackupContents contents;
  try {
    contents = await _withProgress(
      context,
      'Yedek açılıyor…',
      () => service.open(bytes, password),
    );
  } on BackupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;
  final n = contents.counts;
  final at = contents.createdAt?.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Geri yüklensin mi?'),
      content: Text(
        '${at == null ? '' : 'Yedek: ${two(at.day)}.${two(at.month)}.${at.year} '
                  '${two(at.hour)}:${two(at.minute)}\n'}'
        '${n['waypoints'] ?? 0} nokta, ${n['graphics'] ?? 0} çizim, '
        '${n['tracks'] ?? 0} iz, ${n['routes'] ?? 0} rota, '
        '${n['photos'] ?? 0} fotoğraf.\n\n'
        'Bu cihazdaki noktalar, çizimler, izler, rotalar, ölçümler, '
        'fotoğraflar ve ayarlar bu yedektekilerle DEĞİŞTİRİLİR. Haritalar ve '
        'yükseklik verisi korunur.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Geri yükle'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await _withProgress(
      context,
      'Geri yükleniyor…',
      () => service.restore(contents),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Geri yüklenemedi: $e')));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Geri yüklendi'),
      content: const Text(
        'Veriler yedektekiyle değiştirildi. Ayarların (çağrı adı vb.) '
        'hepsi uygulama yeniden açılınca geçerli olur.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
}
