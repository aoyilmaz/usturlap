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
import 'package:kerteriz/features/routes/route_widgets.dart';
import 'package:kerteriz/features/tools/range_tools_bar.dart';
import 'package:kerteriz/features/waypoints/point_dropper_bar.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/providers/route_providers.dart';
import 'package:kerteriz/features/shell/adaptive_sheet.dart';
import 'package:kerteriz/features/shell/atak_toolbar.dart';
import 'package:kerteriz/features/shell/settings_sheet.dart';
import 'package:kerteriz/features/shell/toolbar_tools.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/repeater_providers.dart';
import 'package:kerteriz/providers/settings_providers.dart';
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
        child: const MaterialApp(home: PanelHost(child: MapScreen())),
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

  /// Panel + kenar payı (kare sonunda yayınlanır) + kayma animasyonu.
  /// pumpAndSettle olmaz: harita ekranında süren zamanlayıcılar var.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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
    await settle(tester);
    final panel = sidePanelWidth(ctx);
    expect(
      tester.getRect(find.byType(SelfInfoBox)).right,
      lessThanOrEqualTo(844 - panel - 8 + 0.5),
    );
    // Panel modal değil: araç çubuğu kullanılabilir.
    expect(find.bySemanticsLabel('Bütün araçlar').hitTestable(), findsOneWidget);
    Navigator.of(ctx).pop();
    await settle(tester);
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
    expect(tester.getRect(find.byType(SelfInfoBox)).right, closeTo(844 - 8, 1));
    await dispose(tester);
  });

  testWidgets('dikey + panel: konum kutusu panelin üstüne çıkar, ≡ çalışır', (
    tester,
  ) async {
    const screen = Size(390, 844);
    await pumpScreen(tester, screen, self: _self);
    final ctx = tester.element(find.byType(MapScreen));
    showSettingsSheet(ctx);
    await settle(tester);
    expect(tester.takeException(), isNull);
    final panelTop = 844 - PanelHost.insetsOf(ctx).value.bottom;
    // Uzun içerik: yarım ekran.
    expect(panelTop, closeTo(844 / 2, 1));
    final box = tester.getRect(find.byType(SelfInfoBox));
    expect(box.bottom, closeTo(panelTop - 8, 1));
    expect(
      tester.getRect(find.byType(MapScaleBar)).bottom,
      lessThanOrEqualTo(panelTop - 36 + 0.5),
    );

    // Araç çubuğu haritanın üstünde, dokunulabilir: ≡ ayarların yerine
    // araç ızgarasını açar; ikinci basış kapatır.
    await tester.tap(find.bySemanticsLabel('Bütün araçlar'));
    await settle(tester);
    expect(find.text('Koordinat / Git'), findsOneWidget); // ızgarada
    expect(find.text('Gece modu'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Bütün araçlar'));
    await settle(tester);
    expect(PanelHost.maybeOf(ctx)!.hasOpenPanel, isFalse);
    expect(tester.getRect(find.byType(SelfInfoBox)).bottom,
        closeTo(844 - 34 - 8, 1));
    await dispose(tester);
  });

  testWidgets('yatay: ATAK düzeni hatasız kurulur', (tester) async {
    await pumpScreen(tester, const Size(844, 390));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Bütün araçlar'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('rota planlama: çubuk üstte, altta boşluk yok', (tester) async {
    const screen = Size(390, 844);
    await pumpScreen(tester, screen, self: _self);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );
    container.read(routePlanningProvider.notifier).start();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(RoutePlanToolbar));
    expect(bar.top, lessThan(260)); // ana araç çubuğunun hemen altında
    expectOnScreen(tester, find.byType(RoutePlanToolbar), screen);
    // Alttaki eski planlama çubuğu yok → konum kutusu yerinde.
    expect(
      tester.getRect(find.byType(SelfInfoBox)).bottom,
      closeTo(844 - 34 - 8, 1),
    );
    await dispose(tester);
  });

  testWidgets('R&B düğmesi Range Tools çubuğunu açar/kapatır', (tester) async {
    const screen = Size(390, 844);
    await pumpScreen(tester, screen, self: _self);
    expect(find.byType(RangeToolsBar), findsNothing);
    await tester.tap(find.bySemanticsLabel('Ölçüm (R&B)'));
    await tester.pump();
    expect(find.byType(RangeToolsBar), findsOneWidget);
    expectOnScreen(tester, find.byType(RangeToolsBar), screen);
    await tester.tap(find.bySemanticsLabel('Ölçüm (R&B)'));
    await tester.pump();
    expect(find.byType(RangeToolsBar), findsNothing);
    await dispose(tester);
  });

  testWidgets('araç çubuğu: seçim çubuğa yansır, çıkan araç ızgarada kalır', (
    tester,
  ) async {
    await pumpScreen(tester, const Size(390, 844), self: _self);
    final ctx = tester.element(find.byType(MapScreen));
    final container = ProviderScope.containerOf(ctx);
    // Varsayılan çubuk.
    for (final label in [
      'Nokta bırak',
      'Ölçüm (R&B)',
      'Koordinat / Git',
      'Haritalar',
      'İz kaydını başlat',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }

    // Kayıt sürerken düğme "durdur" olur.
    await tester.tap(find.bySemanticsLabel('İz kaydını başlat'));
    await settle(tester);
    expect(find.bySemanticsLabel('İz kaydını durdur'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('İz kaydını durdur'));
    await settle(tester);

    // Kayıt düğmesini çıkar, gece modunu ekle.
    final n = container.read(toolbarToolsProvider.notifier);
    n.remove(ToolbarTool.record);
    n.add(ToolbarTool.nightMode);
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^İz kaydını')), findsNothing);
    await tester.tap(find.bySemanticsLabel('Gece modu'));
    await tester.pump();
    expect(container.read(nightModeProvider), isTrue);
    await tester.tap(find.bySemanticsLabel('Gece modu'));
    await tester.pump();

    // Çubuktan çıkan araç ≡ ızgarasında.
    await tester.tap(find.bySemanticsLabel('Bütün araçlar'));
    await settle(tester);
    // Yarım ekran panelde görünen alanın hemen altında (kaydırınca görünür).
    expect(find.text('İz kaydı', skipOffstage: false), findsOneWidget);
    Navigator.of(ctx).pop();
    await settle(tester);

    // Bir araca uzun bas → Araç çubuğu paneli; harita açık kalır.
    await tester.longPress(find.bySemanticsLabel('Haritalar'));
    await settle(tester);
    expect(find.textContaining('Çubukta 5/6 araç'), findsOneWidget);
    expect(find.bySemanticsLabel('Haritalar').hitTestable(), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('Nokta bırak: palet açılır, tür seçimi sıradaki adı değiştirir', (
    tester,
  ) async {
    await pumpScreen(tester, const Size(390, 844), self: _self);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );
    await tester.tap(find.bySemanticsLabel('Nokta bırak'));
    await tester.pump();
    expect(find.byType(PointDropperBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectOnScreen(tester, find.byType(PointDropperBar), const Size(390, 844));
    expect(find.text('Haritaya dokun → DÜŞMAN-1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Dost'));
    await tester.pump();
    expect(container.read(dropAffiliationProvider), Affiliation.friend);
    expect(find.text('Haritaya dokun → DOST-1'), findsOneWidget);

    // Araç çubuğundaki düğme paleti kapatır.
    await tester.tap(find.bySemanticsLabel('Nokta bırak'));
    await tester.pump();
    expect(find.byType(PointDropperBar), findsNothing);
    await dispose(tester);
  });
}
