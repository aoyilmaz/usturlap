import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';

/// D2b: harita ekranındaki paneller modal değil (ATAK DropDown).
void main() {
  late int mapTaps;

  /// Haritanın yerine dokunuş sayan bir yüzey; üstünde panel barındırıcısı.
  Future<BuildContext> pumpHost(
    WidgetTester tester,
    Size size, {
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    final portrait = size.height > size.width;
    tester.view.padding = FakeViewPadding(
      top: portrait ? 59 * 3 : 0,
      bottom: (portrait ? 34 : 21) * 3,
    );
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
    mapTaps = 0;
    late BuildContext mapContext;
    await tester.pumpWidget(
      MaterialApp(
        home: PanelHost(
          child: Builder(
            builder: (context) {
              mapContext = context;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => mapTaps++,
                child: const ColoredBox(color: Colors.black),
              );
            },
          ),
        ),
      ),
    );
    return mapContext;
  }

  /// Panelin yüzeyi (içerikteki metnin en yakın Material atası).
  Rect panelRect(WidgetTester tester, String text) => tester.getRect(
    find.ancestor(of: find.text(text), matching: find.byType(Material)).first,
  );

  Widget longList(BuildContext _) => ListView(
    children: [for (var i = 0; i < 60; i++) ListTile(title: Text('Satır $i'))],
  );

  testWidgets('yatay: panel sağda, harita dokunuşları almaya devam eder', (
    tester,
  ) async {
    const screen = Size(844, 390);
    final ctx = await pumpHost(tester, screen);
    showAdaptiveSheet<void>(context: ctx, builder: (_) => const Text('PANEL'));
    await tester.pumpAndSettle();

    final r = panelRect(tester, 'PANEL');
    expect(r.right, screen.width);
    expect(r.width, closeTo(sidePanelWidth(ctx), 0.5));
    expect(r.height, screen.height);
    expect(PanelHost.insetsOf(ctx).value.right, closeTo(r.width, 0.5));

    // Karartma yok: panelin solundaki haritaya dokunuş ulaşır, panel açık kalır.
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();
    expect(mapTaps, 1);
    expect(find.text('PANEL'), findsOneWidget);
  });

  testWidgets('Navigator.pop en üstteki paneli kapatır, Future tamamlanır', (
    tester,
  ) async {
    final ctx = await pumpHost(tester, const Size(390, 844));
    var done = false;
    showAdaptiveSheet<void>(
      context: ctx,
      builder: (_) => const Text('PANEL'),
    ).then((_) => done = true);
    await tester.pumpAndSettle();
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isTrue);

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(find.text('PANEL'), findsNothing);
    expect(done, isTrue);
    expect(PanelHost.insetsOf(ctx).value, EdgeInsets.zero);
    // Ana sayfa yerinde (yalnızca panel kapandı).
    expect(find.byType(ColoredBox), findsWidgets);
  });

  testWidgets('dikey: alttan, içerik kadar; uzun içerik en çok yarım ekran', (
    tester,
  ) async {
    const screen = Size(390, 844);
    final ctx = await pumpHost(tester, screen);

    showAdaptiveSheet<void>(context: ctx, builder: (_) => const Text('KISA'));
    await tester.pumpAndSettle();
    final short = panelRect(tester, 'KISA');
    expect(short.bottom, screen.height);
    expect(short.width, screen.width);
    expect(short.height, lessThan(200));
    // Harita ekranı köşe kutularını bu kadar yukarı kaydırır.
    expect(PanelHost.insetsOf(ctx).value.bottom, closeTo(short.height, 0.5));
    // Üstteki haritaya dokunuş ulaşır.
    await tester.tapAt(const Offset(200, 200));
    expect(mapTaps, 1);

    showAdaptiveSheet<void>(context: ctx, builder: longList);
    await tester.pumpAndSettle();
    expect(find.text('KISA'), findsNothing);
    final long = panelRect(tester, 'Satır 0');
    expect(long.top, closeTo(screen.height / 2, 0.5));
    expect(PanelHost.insetsOf(ctx).value.bottom, closeTo(long.height, 0.5));
  });

  testWidgets('panelin içinden açılan panel üstüne biner, kapanınca alttaki '
      'geri gelir', (tester) async {
    final ctx = await pumpHost(tester, const Size(844, 390));
    showAdaptiveSheet<void>(
      context: ctx,
      builder: (c) => TextButton(
        onPressed: () => showAdaptiveSheet<void>(
          context: c,
          builder: (_) => const Text('B'),
        ),
        child: const Text('A'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing); // gizli (durumu korunur)

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('haritadan açılan panel öncekini kapatır', (tester) async {
    final ctx = await pumpHost(tester, const Size(390, 844));
    showAdaptiveSheet<void>(context: ctx, builder: (_) => const Text('A'));
    await tester.pumpAndSettle();
    showAdaptiveSheet<void>(context: ctx, builder: (_) => const Text('B'));
    await tester.pumpAndSettle();
    expect(find.text('A', skipOffstage: false), findsNothing);
    expect(find.text('B'), findsOneWidget);

    // Geri yığınında yalnız B var: bir pop hepsini kapatır.
    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
  });

  testWidgets('aynı düğme ikinci kez basılınca panel kapanır (toggle)', (
    tester,
  ) async {
    final ctx = await pumpHost(tester, const Size(390, 844));
    void open() => showAdaptiveSheet<void>(
      context: ctx,
      id: 'araclar',
      toggle: true,
      builder: (_) => const Text('ARAÇLAR'),
    );
    open();
    await tester.pumpAndSettle();
    expect(find.text('ARAÇLAR'), findsOneWidget);
    open();
    await tester.pumpAndSettle();
    expect(find.text('ARAÇLAR'), findsNothing);
    open();
    await tester.pumpAndSettle();
    expect(find.text('ARAÇLAR'), findsOneWidget);
  });

  testWidgets('✕ paneli kapatır', (tester) async {
    final ctx = await pumpHost(tester, const Size(844, 390));
    showAdaptiveSheet<void>(context: ctx, builder: (_) => const Text('PANEL'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('PANEL'), findsNothing);
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
  });

  /// A paneli; içindeki düğme B'yi üstüne açar.
  void openAB(BuildContext ctx) => showAdaptiveSheet<void>(
    context: ctx,
    builder: (c) => TextButton(
      onPressed: () =>
          showAdaptiveSheet<void>(context: c, builder: (_) => const Text('B')),
      child: const Text('A'),
    ),
  );

  testWidgets('D4a: ← Geri yalnız altta panel varken; alttakine döner', (
    tester,
  ) async {
    final ctx = await pumpHost(tester, const Size(390, 844));
    openAB(ctx);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Geri'), findsNothing);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Geri'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('D4a: ✕ bütün panelleri kapatır', (tester) async {
    final ctx = await pumpHost(tester, const Size(844, 390));
    openAB(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
  });

  testWidgets('D4a: menünün üstünden Geri menüye döner; başka kapanış menüyü '
      'de kapatır', (tester) async {
    final ctx = await pumpHost(tester, const Size(390, 844));
    final host = PanelHost.maybeOf(ctx)!;
    void openMenu() => showAdaptiveSheet<void>(
      context: ctx,
      id: 'tools',
      menu: true,
      builder: (_) => const Text('MENÜ'),
    );
    void openTool() => showAdaptiveSheet<void>(
      context: ctx,
      builder: (_) => const Text('ARAÇ'),
    );

    openMenu();
    await tester.pumpAndSettle();
    // Haritadan açılan araç normalde menüyü kapatır; menüden açılınca biner.
    expect(host.runStacked(openTool), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('ARAÇ'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('MENÜ'), findsOneWidget);

    // Araç kendi eylemiyle kapanırsa (ör. "Haritada göster") menü de gider.
    host.runStacked(openTool);
    await tester.pumpAndSettle();
    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(find.text('ARAÇ'), findsNothing);
    expect(find.text('MENÜ'), findsNothing);
    expect(host.hasOpenPanel, isFalse);

    // Panel açmayan iş false döner.
    openMenu();
    await tester.pumpAndSettle();
    expect(host.runStacked(() {}), isFalse);
    host.closeId('tools');
    await tester.pumpAndSettle();
    expect(host.hasOpenPanel, isFalse);
  });

  testWidgets('dikey tutamak: yukarı büyütür, aşağı küçültür, sonra kapatır', (
    tester,
  ) async {
    const screen = Size(390, 844);
    final ctx = await pumpHost(tester, screen);
    showAdaptiveSheet<void>(context: ctx, builder: longList);
    await tester.pumpAndSettle();
    final handle = find.bySemanticsLabel('Panel tutamağı');
    expect(panelRect(tester, 'Satır 0').top, closeTo(screen.height / 2, 0.5));

    await tester.drag(handle, const Offset(0, -200));
    await tester.pumpAndSettle();
    // Araç çubuğunun altına kadar (güvenli alan 59 + çubuk 56 + 12).
    expect(panelRect(tester, 'Satır 0').top, closeTo(59 + 56 + 12, 0.5));
    // Tam ekranda köşe kutuları gizlenir (bkz. harita ekranı).
    expect(
      PanelHost.insetsOf(ctx).value.bottom,
      greaterThan(screen.height * 0.55),
    );

    await tester.drag(handle, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(panelRect(tester, 'Satır 0').top, closeTo(screen.height / 2, 0.5));

    await tester.drag(handle, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
  });

  testWidgets('panelden gösterilen bilgi şeridi panelin üstünde görünür', (
    tester,
  ) async {
    final ctx = await pumpHost(tester, const Size(390, 844));
    showAdaptiveSheet<void>(
      context: ctx,
      builder: (c) => TextButton(
        onPressed: () => ScaffoldMessenger.of(
          c,
        ).showSnackBar(const SnackBar(content: Text('Kopyalandı'))),
        child: const Text('KOPYALA'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('KOPYALA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Dokunulabilir = en üstte (panelin arkasında kalmamış).
    expect(find.text('Kopyalandı').hitTestable(), findsOneWidget);
  });

  testWidgets('klavye açıkken panel klavyenin üstünde durur', (tester) async {
    const screen = Size(390, 844);
    final ctx = await pumpHost(tester, screen, keyboard: 300);
    late EdgeInsets inner;
    showAdaptiveSheet<void>(
      context: ctx,
      builder: (c) {
        inner = MediaQuery.viewInsetsOf(c);
        return const Text('GİRİŞ');
      },
    );
    await tester.pumpAndSettle();
    expect(
      panelRect(tester, 'GİRİŞ').bottom,
      closeTo(screen.height - 300, 0.5),
    );
    // İçerik klavye payını ikinci kez eklemesin.
    expect(inner.bottom, 0);
  });
}
