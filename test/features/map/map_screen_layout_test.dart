import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/ports/position_source.dart';
import 'package:kerteriz/features/hud/self_info_box.dart';
import 'package:kerteriz/features/map/map_screen.dart';
import 'package:kerteriz/features/map/widgets/scale_bar.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';
import 'package:kerteriz/features/shell/atak_toolbar.dart';
import 'package:kerteriz/features/shell/settings_sheet.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/repeater_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// Harita ekranının tamamı (Mapbox anahtarı testte yok → harita yerine
/// uyarı metni; geri kalan arayüz gerçek). iPhone boyutlarında yerleşim
/// hatası (ör. sınırsız genişlik, yanlış ParentData) olmamalı.
/// Sabit bir konum yayan kaynak (konum kutusunun dolu hâli çizilsin).
class _FixedSource implements PositionSource {
  _FixedSource(this.contact);
  final Contact? contact;

  @override
  Stream<List<Contact>> get contacts =>
      contact == null ? const Stream.empty() : Stream.value([contact!]);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}
}

final _self = Contact(
  callsign: 'KURT-1',
  position: const LatLng(37.0662, 37.3832),
  speedMps: 1.2,
  altitudeMsl: 884,
  headingDeg: 45,
  accuracyMeters: 5,
  timestamp: DateTime.utc(2026, 11, 6),
  isSelf: true,
);

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    Size logical, {
    Contact? self,
  }) async {
    tester.view.physicalSize = logical * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    // Bellek içi veritabanı; kapatılmaz (sahte zamanda close beklemede kalır).
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          positionSourceProvider.overrideWithValue(_FixedSource(self)),
          repeatersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  /// Kutu ekranın içinde mi (ATAK düzeni: konum kutusu sağ altta).
  void expectOnScreen(WidgetTester tester, Finder f, Size screen) {
    final r = tester.getRect(f);
    expect(r.left, greaterThanOrEqualTo(0), reason: '$r');
    expect(r.top, greaterThanOrEqualTo(0), reason: '$r');
    expect(r.right, lessThanOrEqualTo(screen.width), reason: '$r');
    expect(r.bottom, lessThanOrEqualTo(screen.height), reason: '$r');
  }

  /// drift akışlarının zamanlayıcıları test bitmeden kapansın.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('dikey: ATAK düzeni hatasız kurulur', (tester) async {
    await pumpScreen(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Bütün araçlar'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Pusula')), findsOneWidget);
    expect(find.text('Konum bekleniyor…'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('dikey + konum: konum kutusu dolu hâliyle hatasız', (
    tester,
  ) async {
    const screen = Size(390, 844);
    await pumpScreen(tester, screen, self: _self);
    expect(tester.takeException(), isNull);
    expect(find.text('884 m MSL'), findsOneWidget);
    // Siyah ekran hatası (2026-11-06): Stack 0×0'a büzülüp her şeyi ekran
    // dışına itmişti. Harita alanı ekranı kaplamalı, kutular ekranda olmalı.
    expect(tester.getSize(find.byType(Stack).first), screen);
    expectOnScreen(tester, find.byType(SelfInfoBox), screen);
    expectOnScreen(tester, find.byType(AtakToolbar), screen);
    final box = tester.getRect(find.byType(SelfInfoBox));
    expect(box.right, closeTo(390 - 8, 1)); // sağ alt
    expect(box.bottom, closeTo(844 - 34 - 8, 1));
    // Ölçek, Mapbox logosu (güvenli alanın 8–29 pt üstü) ve atıf düğmesinin
    // görünen ikonunun (~40 pt) üstünde kalmalı.
    final scale = tester.getRect(find.byType(MapScaleBar));
    expect(scale.bottom, lessThanOrEqualTo(844 - 34 - 8 - 36 + 0.5));
    expect(find.text('±5 m'), findsOneWidget);
    // Genişlet: diğer biçimler + sapma.
    await tester.tap(find.text('884 m MSL'));
    // Çift dokunma da tanımlı: tek dokunuş zaman aşımından sonra gelir.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('SAPMA'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('yatay + konum: hatasız', (tester) async {
    const screen = Size(844, 390);
    await pumpScreen(tester, screen, self: _self);
    expect(tester.takeException(), isNull);
    expect(find.text('884 m MSL'), findsOneWidget);
    expectOnScreen(tester, find.byType(SelfInfoBox), screen);
    expectOnScreen(tester, find.byType(AtakToolbar), screen);

    // Sağdan panel açılınca konum kutusu panelin soluna kayar.
    final ctx = tester.element(find.byType(MapScreen));
    showSettingsSheet(ctx);
    // Önce kare (panel + kayma animasyonu başlar), sonra animasyon biter.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final panel = sidePanelWidth(ctx);
    expect(
      tester.getRect(find.byType(SelfInfoBox)).right,
      lessThanOrEqualTo(844 - panel - 8 + 0.5),
    );
    Navigator.of(ctx).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(openSidePanels.value, 0);
    expect(tester.getRect(find.byType(SelfInfoBox)).right, closeTo(844 - 8, 1));
    await dispose(tester);
  });

  testWidgets('yatay: ATAK düzeni hatasız kurulur', (tester) async {
    await pumpScreen(tester, const Size(844, 390));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Bütün araçlar'), findsOneWidget);
    await dispose(tester);
  });
}
