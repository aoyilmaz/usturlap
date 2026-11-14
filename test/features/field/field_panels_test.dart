import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:usturlap/features/field/reports_panel.dart';
import 'package:usturlap/features/field/sun_moon_panel.dart';
import 'package:usturlap/features/field/weather_panel.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:usturlap/providers/weather_providers.dart';
import 'package:latlong2/latlong.dart';

import '../../data/weather/open_meteo_test.dart' show sample;

/// I: güneş ve ay, hava durumu, raporlar.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());
  const ankara = LatLng(39.9334, 32.8597);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    List overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(
            Contact(
              callsign: 'KURT-1',
              position: ankara,
              timestamp: DateTime.utc(2026, 11, 15),
              isSelf: true,
            ),
          ),
          ...overrides.cast(),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await settle(tester);
  }

  testWidgets('güneş ve ay: bugün / yarın, ışık durumu', (tester) async {
    await pump(
      tester,
      SunMoonPanel(
        fallback: () => const LatLng(0, 0),
        now: DateTime.utc(2026, 11, 15, 9),
      ),
    );
    expect(
      find.text(
        'Konumum · cihazda hesaplanır (internet gerekmez) · '
        'yerel saat',
      ),
      findsOneWidget,
    );
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.textContaining('BMNT'), findsNWidgets(2));
    expect(find.textContaining('EENT'), findsNWidgets(2));
    expect(find.text('Gündüz'), findsOneWidget);
    expect(find.textContaining('Büyüyen hilal'), findsWidgets);
  });

  testWidgets('hava durumu: güncelle, göster, önbellek, hata', (tester) async {
    LatLng? asked;
    var fail = false;
    await pump(
      tester,
      WeatherPanel(fallback: () => const LatLng(0, 0)),
      overrides: [
        weatherFetcherProvider.overrideWithValue((p) async {
          asked = p;
          if (fail) throw Exception('ağ yok');
          return sample;
        }),
      ],
    );
    expect(find.textContaining('Henüz hava durumu yok'), findsOneWidget);
    await tester.tap(find.text('Güncelle'));
    await settle(tester);
    expect(asked, ankara);
    expect(find.text('Kapalı · 4°C'), findsOneWidget);
    expect(find.text('GD (114°) 4 km/sa'), findsOneWidget);
    expect(find.text('24 km'), findsOneWidget);
    expect(find.text('Hafif yağmur'), findsOneWidget);
    // Önbelleğe yazıldı.
    expect(
      await tester.runAsync(
        () => SettingsRepositoryForTest(db).get('weather_raw'),
      ),
      isNotNull,
    );
    fail = true;
    await tester.tap(find.text('Güncelle'));
    await settle(tester);
    expect(find.textContaining('İnternete ulaşılamadı'), findsOneWidget);
    expect(find.text('Kapalı · 4°C'), findsOneWidget); // son kayıt kalır
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('CASEVAC formu: sayaç, önizleme, haritaya ekle', (tester) async {
    await pump(
      tester,
      ReportFormPage(
        kind: ReportKind.nineLine,
        fallback: () => const LatLng(0, 0),
        clock: () => DateTime.utc(2026, 11, 11, 15, 30),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1) Alım yeri'), findsOneWidget);
    await tester.tap(find.byTooltip('Acil (2 sa içinde) artır'));
    await tester.tap(find.byTooltip('Acil (2 sa içinde) artır'));
    await tester.pump();
    // Önizleme formun sonunda (liste tembel çizer).
    await tester.scrollUntilVisible(
      find.textContaining('CASEVAC 9 SATIR — 111530Z KAS 26'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    // Alım yeri konumum (MGRS).
    expect(find.textContaining('1) ALIM YERİ: 36S'), findsOneWidget);
    // Çağrı adı ayarlardan (varsayılan).
    expect(find.textContaining('/ USTURLAP-1'), findsOneWidget);
    expect(find.textContaining('3) HASTA (ÖNCELİK): A 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Haritaya ekle'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Haritaya ekle'));
    await settle(tester);
    final wps = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!;
    final w = wps.single;
    expect(w.name, 'CASEVAC-1');
    expect(w.affiliation, Affiliation.rallyPoint);
    expect(w.note, contains('3) HASTA (ÖNCELİK): A 2'));
    expect(w.position.latitude, closeTo(ankara.latitude, 0.001));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

/// Ayar deposuna doğrudan erişim (önbellek denetimi).
class SettingsRepositoryForTest {
  SettingsRepositoryForTest(this.db);
  final AppDatabase db;
  Future<String?> get(String key) async {
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
