import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/toolbar_tool.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/providers/settings_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    // Dinlenmeyen sağlayıcı duraklar (Riverpod 3); uygulamada çubuk dinler.
    c.listen(toolbarToolsProvider, (_, _) {});
    return c;
  }

  test('ilk açılışta varsayılan çubuk', () async {
    final c = container();
    await _settle();
    expect(c.read(toolbarToolsProvider), ToolbarTool.defaults);
  });

  test('ekle / çıkar / taşı; seçim yeniden açılışta geri gelir', () async {
    final c = container();
    await _settle();
    final n = c.read(toolbarToolsProvider.notifier);
    n.remove(ToolbarTool.goTo);
    n.add(ToolbarTool.nightMode);
    // record (3) → başa.
    n.move(3, 0);
    const expected = [
      ToolbarTool.record,
      ToolbarTool.dropPoint,
      ToolbarTool.measure,
      ToolbarTool.maps,
      ToolbarTool.nightMode,
    ];
    expect(c.read(toolbarToolsProvider), expected);
    await _settle();

    // Uygulama yeniden açıldı: kayıtlı sıra okunur.
    final again = container();
    await _settle();
    expect(again.read(toolbarToolsProvider), expected);
  });

  test(
    'sona taşıma (ReorderableListView: çıkarıldıktan sonraki dizin)',
    () async {
      final c = container();
      await _settle();
      c.read(toolbarToolsProvider.notifier).move(0, 4);
      expect(c.read(toolbarToolsProvider).last, ToolbarTool.dropPoint);
      expect(c.read(toolbarToolsProvider), hasLength(5));
    },
  );

  test('dolu çubuğa ekleme ve tekrar eklenmez', () async {
    final c = container();
    await _settle();
    final n = c.read(toolbarToolsProvider.notifier);
    n.add(ToolbarTool.maps); // zaten var
    expect(c.read(toolbarToolsProvider), ToolbarTool.defaults);
    n.add(ToolbarTool.settings); // 6.
    n.add(ToolbarTool.tracks); // sınır aşılır → eklenmez
    expect(c.read(toolbarToolsProvider), hasLength(ToolbarTool.maxOnBar));
    expect(c.read(toolbarToolsProvider), isNot(contains(ToolbarTool.tracks)));
  });

  test('hepsi çıkarılabilir; varsayılana dön', () async {
    final c = container();
    await _settle();
    final n = c.read(toolbarToolsProvider.notifier);
    for (final t in ToolbarTool.defaults) {
      n.remove(t);
    }
    expect(c.read(toolbarToolsProvider), isEmpty);
    await _settle();
    final reopened = container();
    await _settle();
    expect(reopened.read(toolbarToolsProvider), isEmpty);

    n.reset();
    expect(c.read(toolbarToolsProvider), ToolbarTool.defaults);
  });
}
