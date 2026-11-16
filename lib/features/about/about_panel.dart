import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shell/adaptive_sheet.dart';

/// Tanıtım sitesi, rehber, gizlilik ve kaynak kodu adresleri.
const kWebsiteUrl = 'https://aoyilmaz.github.io/usturlap/';
const kGuideUrl = '${kWebsiteUrl}rehber.html';
const kPrivacyUrl = '${kWebsiteUrl}gizlilik.html';
const kSourceUrl = 'https://github.com/aoyilmaz/usturlap';
const kDeveloperName = 'Ahmet Okan Yılmaz';

const _iconAsset = 'assets/icon/usturlap_icon_256.png';

/// Uygulama sürümü ("1.0.1"): pubspec.yaml'daki `version`'ın ilk kısmı.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Bağlantıyı telefonun tarayıcısında açar; açamazsa false döner.
/// Testte sahtesiyle değiştirilir.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// ≡ → Sistem → Hakkında: ad, sürüm, geliştirici ve siteye bağlantılar.
Future<void> showAboutPanel(BuildContext context) {
  return showAdaptiveSheet<void>(
    context: context,
    id: 'about',
    isScrollControlled: true,
    builder: (ctx) => const AboutPanel(),
  );
}

class AboutPanel extends ConsumerWidget {
  const AboutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final version = ref.watch(appVersionProvider).value;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(_iconAsset, width: 64, height: 64),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usturlap',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    version == null
                        ? 'Çevrimdışı taktik harita'
                        : 'Çevrimdışı taktik harita · sürüm $version',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Geliştiren: $kDeveloperName'),
        const SizedBox(height: 4),
        Text(
          'Hesap açmazsın; noktaların, izlerin ve ayarların telefonunda kalır.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 8),
        const _LinkTile(
          icon: Icons.public,
          title: 'Web sitesi',
          subtitle: 'aoyilmaz.github.io/usturlap',
          url: kWebsiteUrl,
        ),
        const _LinkTile(
          icon: Icons.menu_book_outlined,
          title: 'Kullanım rehberi',
          subtitle: 'Bir arama-kurtarma hikâyesiyle bütün araçlar',
          url: kGuideUrl,
        ),
        const _LinkTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Gizlilik',
          subtitle: 'Hangi bağlantı ne zaman, neden kurulur',
          url: kPrivacyUrl,
        ),
        const _LinkTile(
          icon: Icons.code,
          title: 'Kaynak kodu',
          subtitle: 'github.com/aoyilmaz/usturlap',
          url: kSourceUrl,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Açık kaynak lisansları'),
          subtitle: const Text('Kullanılan kütüphaneler'),
          onTap: () => _showLicenses(context, version),
        ),
      ],
    );
  }
}

/// Lisans sayfası saydam rotayla açılır: opak tam ekran sayfa haritayı
/// örtünce Riverpod harita ekranının aboneliklerini duraklatır (iz kaydı
/// zinciri dahil). Saydam rotada harita arkada çalışmaya devam eder.
void _showLicenses(BuildContext context, String? version) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, _, _) => LicensePage(
        applicationName: 'Usturlap',
        applicationVersion: version,
        applicationIcon: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(_iconAsset, width: 48, height: 48),
          ),
        ),
        applicationLegalese: '© 2026 $kDeveloperName',
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _LinkTile extends ConsumerWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final ok = await ref.read(linkOpenerProvider)(Uri.parse(url));
        if (!ok) {
          messenger?.showSnackBar(
            SnackBar(content: Text('Tarayıcı açılamadı. Adres: $url')),
          );
        }
      },
    );
  }
}
