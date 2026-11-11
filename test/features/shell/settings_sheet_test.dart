import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/settings_repository.dart';
import 'package:kerteriz/data/position/stub_position_source.dart';
import 'package:kerteriz/features/shell/settings_sheet.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/repeater_providers.dart';
import 'package:kerteriz/providers/settings_providers.dart';

/// Veritabanısız ayar deposu (yalnızca test).
class _MemSettings implements SettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async => values[key] = value;
}

void main() {
  late _MemSettings mem;

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    mem = _MemSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mem),
          positionSourceProvider.overrideWithValue(StubPositionSource()),
          repeatersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSettingsSheet(context),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  /// Liste uzun: öğeye dokunmadan önce görünür olana kadar kaydır.
  Future<void> reveal(WidgetTester tester, Finder f) => tester
      .scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).last);

  testWidgets('kuzey, açı birimi ve koordinat seçimi kalıcı kaydedilir', (
    tester,
  ) async {
    await openSheet(tester);

    await reveal(tester, chip('DMS'));
    await tester.tap(chip('DMS'));
    await tester.pumpAndSettle();
    expect(mem.values['coord_format'], 'dms');

    await reveal(tester, chip('Manyetik'));
    await tester.tap(chip('Manyetik'));
    await tester.pumpAndSettle();
    expect(mem.values['north_ref'], 'magnetic');

    await reveal(tester, chip('Mil'));
    await tester.tap(chip('Mil'));
    await tester.pumpAndSettle();
    expect(mem.values['angle_unit'], 'mils');

    // Seçili çip vurgulu (yukarıda kaldı: geri kaydır).
    await tester.scrollUntilVisible(
      chip('Manyetik'),
      -120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.widget<ChoiceChip>(chip('Manyetik')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(chip('Coğrafi')).selected, isFalse);
  });

  testWidgets('konum yokken sapma bilgisi bekleme metni gösterir', (
    tester,
  ) async {
    await openSheet(tester);
    final info = find.textContaining('konum gelince hesaplanır');
    await reveal(tester, info);
    expect(info, findsOneWidget);
  });

  testWidgets('acil veri silme: onay sorulur, Vazgeç hiçbir şey silmez', (
    tester,
  ) async {
    await openSheet(tester);
    final tile = find.text('Acil veri silme');
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('Tüm veriler silinsin mi?'), findsOneWidget);
    expect(find.text('ŞİMDİ SİL'), findsOneWidget);
    // "Haritaları da sil" varsayılan açık.
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Tüm veriler silinsin mi?'), findsNothing);
    expect(find.text('Siliniyor…'), findsNothing);
  });
}
