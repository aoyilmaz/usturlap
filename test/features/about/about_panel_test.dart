import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/features/about/about_panel.dart';

/// Hakkında paneli: ad, sürüm, geliştirici, bağlantılar ve lisanslar.
void main() {
  Future<List<Uri>> pump(WidgetTester tester, {bool openOk = true}) async {
    final opened = <Uri>[];
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '1.0.1'),
          linkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return openOk;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: AboutPanel())),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('ad, sürüm ve geliştirici görünür', (tester) async {
    await pump(tester);
    expect(find.text('Usturlap'), findsOneWidget);
    expect(find.text('Çevrimdışı taktik harita · sürüm 1.0.1'), findsOneWidget);
    expect(find.text('Geliştiren: Ahmet Okan Yılmaz'), findsOneWidget);
  });

  testWidgets('bağlantılar doğru adresi açar', (tester) async {
    final opened = await pump(tester);
    await tester.tap(find.text('Web sitesi'));
    await tester.tap(find.text('Kullanım rehberi'));
    await tester.tap(find.text('Gizlilik'));
    await tester.tap(find.text('Kaynak kodu'));
    await tester.pump();
    expect(opened.map((u) => u.toString()), [
      'https://aoyilmaz.github.io/usturlap/',
      'https://aoyilmaz.github.io/usturlap/rehber.html',
      'https://aoyilmaz.github.io/usturlap/gizlilik.html',
      'https://github.com/aoyilmaz/usturlap',
    ]);
  });

  testWidgets('tarayıcı açılamazsa adres şeritte yazar', (tester) async {
    await pump(tester, openOk: false);
    await tester.tap(find.text('Web sitesi'));
    await tester.pump();
    expect(
      find.text(
        'Tarayıcı açılamadı. Adres: https://aoyilmaz.github.io/usturlap/',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lisans sayfası açılır, harita rotası örtülmez', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Açık kaynak lisansları'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    // Saydam rota: alttaki sayfa sahnede kalır (offstage değil).
    expect(find.byType(AboutPanel), findsOneWidget);
  });
}
