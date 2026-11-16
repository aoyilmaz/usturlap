import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/features/shell/adaptive_sheet.dart';

/// Android geri tuşu: panel ya da etkin mod varken uygulamadan çıkılmaz.
///
/// Flutter platforma "geri tuşunu ben üstlenirim"i NavigationNotification
/// ile bildirir; Android 13+ geri hareketi buna göre tuşu Flutter'a verir
/// ya da doğrudan uygulamadan çıkar.
void main() {
  late bool? handlesBack;
  late BuildContext mapContext;

  Future<void> pumpHost(WidgetTester tester, {Widget? child}) async {
    handlesBack = null;
    await tester.pumpWidget(
      MaterialApp(
        onNavigationNotification: (n) {
          handlesBack = n.canHandlePop;
          return true;
        },
        home: PanelHost(
          child: Builder(
            builder: (context) {
              mapContext = context;
              return child ?? const ColoredBox(color: Colors.black);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('panel yokken geri tuşu sisteme bırakılır', (tester) async {
    await pumpHost(tester);
    expect(handlesBack, isNot(true));
  });

  testWidgets('panel açıkken geri tuşu paneli kapatır, uygulama kalır', (
    tester,
  ) async {
    await pumpHost(tester);
    showAdaptiveSheet<void>(
      context: mapContext,
      builder: (_) => const Text('PANEL'),
    );
    await tester.pumpAndSettle();
    expect(handlesBack, isTrue, reason: 'platforma bildirilmeli');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('PANEL'), findsNothing);
    expect(find.byType(PanelHost), findsOneWidget);
    expect(handlesBack, isFalse, reason: 'panel kapandı: yine sisteme');
  });

  testWidgets('üst üste iki panel: her geri tuşu en üsttekini kapatır', (
    tester,
  ) async {
    await pumpHost(tester);
    showAdaptiveSheet<void>(
      context: mapContext,
      builder: (ctx) => TextButton(
        onPressed: () => showAdaptiveSheet<void>(
          context: ctx,
          builder: (_) => const Text('İKİNCİ'),
        ),
        child: const Text('BİRİNCİ'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BİRİNCİ'));
    await tester.pumpAndSettle();
    expect(find.text('İKİNCİ'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('İKİNCİ'), findsNothing);
    expect(find.text('BİRİNCİ'), findsOneWidget);
    expect(handlesBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('BİRİNCİ'), findsNothing);
    expect(find.byType(PanelHost), findsOneWidget);
  });

  testWidgets('harita bir moddayken geri tuşu modu kapatır', (tester) async {
    var mode = true;
    var backs = 0;
    late StateSetter rebuild;
    await pumpHost(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          PanelHost.maybeOf(context)!.setBackHandler(
            wanted: mode,
            onBack: () {
              backs++;
              rebuild(() => mode = false);
            },
          );
          return Text(mode ? 'MOD' : 'HARİTA');
        },
      ),
    );
    expect(handlesBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(backs, 1);
    expect(find.text('HARİTA'), findsOneWidget);
    expect(handlesBack, isFalse, reason: 'mod kapandı: yine sisteme');
  });

  testWidgets('panel ve mod birlikte: önce panel, sonra mod', (tester) async {
    var backs = 0;
    await pumpHost(
      tester,
      child: Builder(
        builder: (context) {
          PanelHost.maybeOf(
            context,
          )!.setBackHandler(wanted: true, onBack: () => backs++);
          return const SizedBox.expand();
        },
      ),
    );
    showAdaptiveSheet<void>(
      context: mapContext,
      builder: (_) => const Text('PANEL'),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('PANEL'), findsNothing);
    expect(backs, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(backs, 1);
  });
}
