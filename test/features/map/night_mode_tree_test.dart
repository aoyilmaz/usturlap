import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/domain/ports/position_source.dart';
import 'package:usturlap/features/map/map_screen.dart';
import 'package:usturlap/features/shell/panel_host.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/repeater_providers.dart';
import 'package:usturlap/providers/settings_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';

class _NoSource implements PositionSource {
  @override
  Stream<List<Contact>> get contacts => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}
}

/// Gece modu açılıp kapanınca harita ekranının ağacı yeniden kurulmamalı:
/// kurulursa haritanın platform görünümü baştan yaratılır (Android'de eski
/// haritanın kanalları koptu). Haritanın kabı olan FutureBuilder'ın State'i
/// aynı kalmalı.
void main() {
  testWidgets('gece modu haritanın ağacını yeniden kurmaz', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          positionSourceProvider.overrideWithValue(_NoSource()),
          repeatersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: PanelHost(child: MapScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final mapHost = find
        .descendant(
          of: find.byType(MapScreen),
          matching: find.byType(FutureBuilder<void>),
        )
        .first;
    final before = tester.state(mapHost);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );

    for (var i = 0; i < 2; i++) {
      container.read(nightModeProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        identical(tester.state(mapHost), before),
        isTrue,
        reason: 'gece modu ${i == 0 ? 'açılınca' : 'kapanınca'} yeniden kuruldu',
      );
    }

    // drift akışlarının zamanlayıcıları test bitmeden kapansın.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
