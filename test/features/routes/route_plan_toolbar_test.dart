import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/features/routes/route_widgets.dart';
import 'package:kerteriz/providers/route_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

void main() {
  late ProviderContainer c;

  Future<void> pump(WidgetTester tester, {VoidCallback? onAdd}) async {
    // Bellek içi veritabanı (kapatılmaz: sahte zamanda close beklemede kalır).
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(
          AppDatabase.forTesting(NativeDatabase.memory()),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.read(routePlanningProvider.notifier).start();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 316,
                child: RoutePlanToolbar(onAddAtCrosshair: onAdd),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<InkWell>(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          )
          .onTap !=
      null;

  testWidgets('boşken talimat; geri al / kaydet pasif; + Nokta yok', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Rota: haritaya dokunarak nokta ekleyin'), findsOneWidget);
    expect(find.text('+ Nokta'), findsNothing);
    expect(enabled(tester, 'Geri al'), isFalse);
    expect(enabled(tester, 'Kaydet'), isFalse);
    expect(enabled(tester, 'Çık'), isTrue);
  });

  testWidgets('noktalar eklenince mesafe; geri al çalışır', (tester) async {
    await pump(tester);
    final n = c.read(routePlanningProvider.notifier);
    n.addPoint(const LatLng(39.0, 32.0));
    n.addPoint(const LatLng(39.01, 32.0));
    await tester.pump();
    expect(find.textContaining('NOKTA 2'), findsOneWidget);
    expect(enabled(tester, 'Kaydet'), isTrue);
    await tester.tap(find.text('Geri al'));
    await tester.pump();
    expect(c.read(routePlanningProvider).points, hasLength(1));
  });

  testWidgets('artı imleç açıksa "+ Nokta" görünür ve çağrılır', (
    tester,
  ) async {
    var added = 0;
    await pump(tester, onAdd: () => added++);
    await tester.tap(find.text('+ Nokta'));
    expect(added, 1);
  });
}
