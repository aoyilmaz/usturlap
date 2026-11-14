// Site için ekran görüntüsü / video çekimi (simülatörde gerçek uygulama).
//
// Tek başına çalıştırılmaz: tool/capture_site_media.py başlatır ve şu
// satırları dinleyerek simülatörden görüntü alır:
//   SHOT:<ad>  ·  VIDEO:start:<ad>  ·  VIDEO:stop
//
// Konum gerçek GPS değil (DemoSource): Kapadokya'da (Göreme) uydurma bir
// tatbikat. Kişisel konum ya da veri görüntülere girmez. Veritabanı bellek
// içidir; simülatördeki uygulama verisine dokunulmaz.
//
// Haritaya dokunmalar Mapbox'ın yerel görünümüne gider, testten basılamaz;
// bu yüzden harita bileşeninin geri çağrıları (onTap, işaretçi onTap) ve
// kamera denetleyicisi doğrudan çağrılır.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:usturlap/app.dart';
import 'package:usturlap/core/constants.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/domain/models/bullseye.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:usturlap/domain/models/route_plan.dart';
import 'package:usturlap/domain/models/sensor_fov.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:usturlap/domain/ports/alert_output.dart';
import 'package:usturlap/domain/ports/position_source.dart';
import 'package:usturlap/domain/usecases/viewshed.dart';
import 'package:usturlap/features/map/engine/map_engine.dart';
import 'package:usturlap/providers/alert_providers.dart';
import 'package:usturlap/providers/bullseye_providers.dart';
import 'package:usturlap/providers/elevation_providers.dart';
import 'package:usturlap/providers/graphic_providers.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/range_line_providers.dart';
import 'package:usturlap/providers/route_providers.dart';
import 'package:usturlap/providers/settings_providers.dart';
import 'package:usturlap/providers/terrain_analysis_providers.dart';
import 'package:usturlap/providers/track_providers.dart';
import 'package:usturlap/providers/viewshed_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';

// ------------------------------------------------------------ senaryo yerleri

const _self0 = LatLng(38.6392, 34.8318); // Göreme'nin güneydoğusu
const _goreme = LatLng(38.6431, 34.8289);
const _uchisar = LatLng(38.6306, 34.8053);

/// Devriye rotası: başlangıç → KN1 → KN2 → hedef (kuzeydoğu, Çavuşin yönü).
const _route = [
  LatLng(38.6392, 34.8318),
  LatLng(38.6450, 34.8352),
  LatLng(38.6512, 34.8371),
  LatLng(38.6575, 34.8402),
];

const _blue = 0xFF42A5F5;
const _red = 0xFFE53935;
const _amber = 0xFFFFB300;
const _green = 0xFF66BB6A;

// ------------------------------------------------------------ sahte kaynaklar

/// Elle sürülen konum kaynağı (gerçek GPS yok).
class DemoSource implements PositionSource {
  DemoSource(this._pos, {this.heading = 35});
  LatLng _pos;
  double heading;
  final _ctrl = StreamController<List<Contact>>.broadcast();

  Contact get _contact => Contact(
        callsign: 'USTURLAP-1',
        position: _pos,
        speedMps: 1.4,
        altitudeMsl: 1105,
        headingDeg: heading,
        accuracyMeters: 4,
        timestamp: DateTime.now().toUtc(),
        isSelf: true,
      );

  void moveTo(LatLng p, {double? headingDeg}) {
    _pos = p;
    if (headingDeg != null) heading = headingDeg;
    _ctrl.add([_contact]);
  }

  @override
  Stream<List<Contact>> get contacts async* {
    yield [_contact];
    yield* _ctrl.stream;
  }

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}
}

/// Sesli uyarı çekimde Mac'ten ses çıkarmasın.
class _SilentSpeaker implements Speaker {
  @override
  Future<void> speak(String text) async => debugPrint('KONUŞMA: $text');
}

class _SilentNotifications implements AlertNotifications {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> show(int id, String title, String body) async {}
}

// ------------------------------------------------------------ yardımcılar

late ProviderContainer _c;
late DemoSource _src;
late RoutePlan _patrol;
final _skipped = <String>[];

Future<void> _wait(WidgetTester t, [double s = 1]) =>
    t.pump(Duration(milliseconds: (s * 1000).round()));

Future<void> _shot(WidgetTester t, String name, {double settle = 1.5}) async {
  await _wait(t, settle);
  debugPrint('SHOT:$name');
  await _wait(t, 2);
}

var _recording = false;

Future<void> _videoStart(WidgetTester t, String name) async {
  _recording = true;
  debugPrint('VIDEO:start:$name');
  await _wait(t, 2); // kaydedici açılsın
}

Future<void> _videoStop(WidgetTester t) async {
  await _wait(t, 0.8);
  _recording = false;
  debugPrint('VIDEO:stop');
  await _wait(t, 3);
}

/// `--dart-define=ONLY=tur,rota`: yalnız bu adımlar (deneme için).
const _only = String.fromEnvironment('ONLY');

/// Bir çekim adımı: hata olursa ekranı hata görüntüsü olarak kaydeder,
/// yarım videoyu iptal eder, arayüzü toparlar ve sıradakine geçer.
Future<void> _step(
  WidgetTester t,
  String name,
  Future<void> Function() body,
) async {
  if (_only.isNotEmpty && !_only.split(',').contains(name)) return;
  debugPrint('ADIM: $name');
  try {
    await body();
  } catch (e, st) {
    _skipped.add(name);
    if (_recording) {
      _recording = false;
      debugPrint('VIDEO:abort');
    }
    debugPrint('ATLANDI:$name: $e\n$st');
    debugPrint('SHOT:hata-$name');
    await _wait(t, 2);
  }
  await _closeAll(t);
}

Widget _engineView(WidgetTester t) => t.widget(find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_MapboxEngineView'));

MapEngineController _ctrl(WidgetTester t) =>
    (_engineView(t) as dynamic).controller as MapEngineController;

/// Haritada bir noktaya dokunma (Mapbox'ın tek dokun geri çağrısı).
void _mapTap(WidgetTester t, LatLng p) =>
    ((_engineView(t) as dynamic).onTap as MapPointCallback?)?.call(p);

/// Haritadaki bir işaretçiye dokunma.
void _markerTap(WidgetTester t, String id) {
  final overlays = (_engineView(t) as dynamic).overlays as List<MapOverlay>;
  overlays.whereType<MapMarker>().firstWhere((m) => m.id == id).onTap!();
}

Future<void> _tapLabel(WidgetTester t, Pattern label) async {
  final f = label is String
      ? find.bySemanticsLabel(label)
      : find.bySemanticsLabel(label as RegExp);
  await t.tap(f.first);
  await _wait(t, 0.9);
}

/// Nokta bırakma paleti açık mı (palette "Sadakat" sekmesi var).
bool _dropOpen() => find.text('Sadakat').evaluate().isNotEmpty;

Future<void> _setDropMode(WidgetTester t, bool on) async {
  if (_dropOpen() != on) await _tapLabel(t, 'Nokta bırak');
  await _wait(t, 0.5);
}

/// Ölçüm / alan aracı açıksa kapatır (araç çubuğundaki R&B düğmesi).
Future<void> _closeMeasure(WidgetTester t) async {
  final banner = find.textContaining('Alan:');
  final bar = find.bySemanticsLabel('Menzil halkası');
  if (banner.evaluate().isNotEmpty || bar.evaluate().isNotEmpty) {
    await _tapLabel(t, 'Ölçüm (R&B)');
  }
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await _wait(t, 0.9);
}

/// ≡ ızgarasından bir araç.
Future<void> _openTool(WidgetTester t, String label) async {
  await _tapLabel(t, 'Bütün araçlar');
  await _wait(t, 0.6);
  // Izgara uzun bir liste: alttaki bölümler kaydırılmadan kurulmaz.
  final list = find
      .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
      .first;
  await t.scrollUntilVisible(find.text(label), 120, scrollable: list);
  await _wait(t, 0.3);
  await _tapText(t, label);
  await _wait(t, 0.6);
}

/// Açık panel / sayfa / menüleri kapatır.
Future<void> _closeAll(WidgetTester t) async {
  // Tam ekran sayfalar ve diyaloglar (ör. rapor formu) rota olarak açılır.
  for (final nav in t.stateList<NavigatorState>(find.byType(Navigator))) {
    nav.popUntil((r) => r.isFirst);
  }
  await _wait(t, 0.6);
  for (var i = 0; i < 5; i++) {
    final close = find.byTooltip('Kapat');
    final back = find.byTooltip('Geri');
    final backBtn = find.byType(BackButton);
    if (close.evaluate().isNotEmpty) {
      await t.tap(close.last, warnIfMissed: false);
    } else if (back.evaluate().isNotEmpty) {
      await t.tap(back.last, warnIfMissed: false);
    } else if (backBtn.evaluate().isNotEmpty) {
      await t.tap(backBtn.last, warnIfMissed: false);
    } else {
      break;
    }
    await _wait(t, 0.7);
  }
}

/// Kamerayı yumuşakça kaydırır (motorun moveTo'su anlık; küçük adımlarla).
Future<void> _glide(
  WidgetTester t, {
  required LatLng from,
  required LatLng to,
  required double zoomFrom,
  required double zoomTo,
  double seconds = 3,
}) async {
  final steps = (seconds * 30).round();
  for (var i = 0; i <= steps; i++) {
    final k = i / steps;
    final e = k < 0.5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;
    _ctrl(t).moveTo(
      LatLng(
        from.latitude + (to.latitude - from.latitude) * e,
        from.longitude + (to.longitude - from.longitude) * e,
      ),
      zoom: zoomFrom + (zoomTo - zoomFrom) * e,
    );
    await t.pump(const Duration(milliseconds: 33));
  }
}

double _bearing(LatLng a, LatLng b) {
  final p1 = a.latitudeInRad, p2 = b.latitudeInRad;
  final dl = b.longitudeInRad - a.longitudeInRad;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) -
      math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

// ------------------------------------------------------------ demo verisi

Future<void> _seed() async {
  final wps = _c.read(waypointRepositoryProvider);
  Future<int> wp(
    String name,
    LatLng p, {
    Affiliation a = Affiliation.waypoint,
    Echelon e = Echelon.none,
    SymbolRole r = SymbolRole.none,
    String? uid,
  }) =>
      wps.add(name: name, position: p, affiliation: a, echelon: e, role: r, uid: uid);

  final gn = await wp('GN-1', _uchisar, a: Affiliation.observationPost, uid: 'demo-gn1');
  await wps.setFov(gn, const SensorFov(azimuth: 35, width: 70, range: 1800));
  await wp('ALFA', const LatLng(38.6418, 34.8212),
      a: Affiliation.friend, e: Echelon.squad, r: SymbolRole.infantry);
  await wp('BRAVO', const LatLng(38.6548, 34.8296),
      a: Affiliation.friend, e: Echelon.team, r: SymbolRole.recon);
  await wp('D-1', const LatLng(38.6668, 34.8236),
      a: Affiliation.hostile, e: Echelon.company, r: SymbolRole.armor, uid: 'demo-d1');
  await wp('D-2', const LatLng(38.6612, 34.8478),
      a: Affiliation.hostile, e: Echelon.squad, r: SymbolRole.infantry);
  await wp('Ş-1', const LatLng(38.6702, 34.8352), a: Affiliation.suspect);
  await wp('MAYIN', const LatLng(38.6626, 34.8338),
      a: Affiliation.hostile, r: SymbolRole.mine);
  await wp('TOPLANMA', const LatLng(38.6372, 34.8425), a: Affiliation.rallyPoint);
  await wp('KN-3', const LatLng(38.6496, 34.8195), a: Affiliation.checkpoint);

  final gr = _c.read(mapGraphicRepositoryProvider);
  await gr.add(
    name: 'HEDEF BÖLGE',
    type: GraphicType.area,
    colorValue: _red,
    points: const [
      LatLng(38.6694, 34.8180),
      LatLng(38.6712, 34.8292),
      LatLng(38.6648, 34.8304),
      LatLng(38.6632, 34.8196),
    ],
  );
  await gr.add(
    name: 'TEHLİKE',
    type: GraphicType.circle,
    colorValue: _amber,
    points: const [LatLng(38.6612, 34.8478), LatLng(38.6612, 34.8518)],
  );
  await gr.add(
    name: 'FAZ HATTI',
    type: GraphicType.line,
    colorValue: _blue,
    dashed: true,
    strokeWidth: 4,
    points: const [
      LatLng(38.6556, 34.8090),
      LatLng(38.6578, 34.8230),
      LatLng(38.6566, 34.8420),
      LatLng(38.6596, 34.8580),
    ],
  );
  await gr.add(
    name: 'YASAK BÖLGE',
    type: GraphicType.area,
    colorValue: 0xFFFF7043,
    geofence: GeofenceTrigger.entry,
    points: const [
      LatLng(38.6470, 34.8338),
      LatLng(38.6473, 34.8394),
      LatLng(38.6493, 34.8397),
      LatLng(38.6490, 34.8336),
    ],
  );

  await _c.read(rangeRingRepositoryProvider).add(
        name: 'GN-1 HALKALARI',
        center: RbEnd(_uchisar, RbEnd.waypointRef('demo-gn1')),
        radii: const [500, 1000, 1500],
        colorValue: _green,
      );
  await _c.read(rangeLineRepositoryProvider).add(
        name: 'GN-1 → D-1',
        start: RbEnd(_uchisar, RbEnd.waypointRef('demo-gn1')),
        end: RbEnd(const LatLng(38.6668, 34.8236), RbEnd.waypointRef('demo-d1')),
      );

  _patrol = await _c.read(routeRepositoryProvider).add(
        name: 'DEVRİYE',
        points: _route,
        pointNames: const ['BAŞLANGIÇ', 'KN1', 'KN2', 'HEDEF'],
      );

  // Uçhisar'dan Göreme'ye yürüyüş izi (hafif kıvrımlı).
  final trail = <LatLng>[];
  for (var i = 0; i <= 40; i++) {
    final k = i / 40;
    trail.add(LatLng(
      _uchisar.latitude + (_goreme.latitude - _uchisar.latitude) * k +
          0.0009 * math.sin(k * math.pi * 3),
      _uchisar.longitude + (_goreme.longitude - _uchisar.longitude) * k,
    ));
  }
  await _c.read(trackRepositoryProvider).importTrack('İZ-1', trail);
}

/// Görüş alanı / arazi analizi için N38E034 yükseklik karesi (SRTM 1″,
/// AWS Terrain Tiles, herkese açık). İndirilemezse arazi çekimleri atlanır.
Future<bool> _ensureElevation() async {
  final store = _c.read(elevationStoreProvider);
  if ((await store.list()).any((e) => e.key == 'N38E034')) return true;
  try {
    final res = await http
        .get(Uri.parse('https://s3.amazonaws.com/elevation-tiles-prod/skadi/N38/N38E034.hgt.gz'))
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) return false;
    final bytes = gzip.decode(res.bodyBytes);
    await store.importBytes(Uint8List.fromList(bytes), 'N38E034.hgt');
    _c.read(hgtParserProvider).invalidate();
    _c.invalidate(elevationTilesProvider);
    return true;
  } catch (e) {
    debugPrint('Yükseklik verisi alınamadı: $e');
    return false;
  }
}

// ------------------------------------------------------------ çekim

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('site vitrini', (t) async {
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
    _src = DemoSource(_self0);
    _c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(
          AppDatabase.forTesting(NativeDatabase.memory())),
      positionSourceProvider.overrideWithValue(_src),
      speakerProvider.overrideWithValue(_SilentSpeaker()),
      alertNotificationsProvider.overrideWithValue(_SilentNotifications()),
    ]);
    await _seed();
    final hasDem = await _ensureElevation();

    await t.pumpWidget(UncontrolledProviderScope(
      container: _c,
      child: const UsturlapApp(),
    ));
    await _wait(t, 8);
    _ctrl(t).moveTo(_self0, zoom: 13.9);
    _src.moveTo(_self0);
    await _wait(t, 5);

    await _step(t, 'ana-ekran', () async {
      _ctrl(t).moveTo(const LatLng(38.6490, 34.8268), zoom: 13.1);
      await _shot(t, 'ana-ekran', settle: 5);
    });

    await _step(t, 'tur', () async {
      _ctrl(t).moveTo(const LatLng(38.6440, 34.8180), zoom: 12.4);
      await _wait(t, 4);
      await _videoStart(t, 'tur');
      await _glide(t,
          from: const LatLng(38.6440, 34.8180),
          to: const LatLng(38.6470, 34.8290),
          zoomFrom: 12.4,
          zoomTo: 14.2,
          seconds: 4);
      await _wait(t, 1);
      // 3B arazi: pusula okuna uzun bas → 3B düğmesi.
      await t.longPress(find.bySemanticsLabel(RegExp('^Pusula')).first);
      await _wait(t, 0.8);
      await _tapLabel(t, RegExp('^3B arazi'));
      await _wait(t, 2.5);
      for (var i = 0; i <= 90; i++) {
        _ctrl(t).rotateTo(i * 0.45);
        await t.pump(const Duration(milliseconds: 33));
      }
      await _videoStop(t);
      await _shot(t, '3b-arazi', settle: 0.5);
      await _tapLabel(t, RegExp('^3B arazi'));
      await _wait(t, 1);
      _ctrl(t).rotateTo(0);
      await _wait(t, 1);
    });

    await _step(t, 'katmanlar', () async {
      _ctrl(t).moveTo(const LatLng(38.6480, 34.8290), zoom: 13.9);
      await _tapLabel(t, 'Haritalar');
      await _shot(t, 'katmanlar');
      await _tapText(t, 'Topografik');
      await _closeAll(t);
      await _shot(t, 'topografik', settle: 4);
      await _tapLabel(t, 'Haritalar');
      await _tapText(t, 'Uydu');
      await _closeAll(t);
      await _wait(t, 2);
    });

    await _step(t, 'cevrimdisi', () async {
      await _openTool(t, 'Çevrimdışı bölgeler');
      await _tapText(t, 'Yeni bölge indir');
      await _shot(t, 'cevrimdisi', settle: 2.5);
      await _tapText(t, 'Vazgeç');
    });

    await _step(t, 'nokta', () async {
      _ctrl(t).moveTo(const LatLng(38.6480, 34.8290), zoom: 14.6);
      await _wait(t, 2);
      await _videoStart(t, 'nokta');
      await _setDropMode(t, true);
      await _wait(t, 1);
      _mapTap(t, const LatLng(38.6462, 34.8236));
      await _wait(t, 1.2);
      _mapTap(t, const LatLng(38.6480, 34.8300));
      await _wait(t, 1.2);
      await _setDropMode(t, false);
      await _wait(t, 0.8);
      // Son bırakılan nokta (en büyük kimlik) ekranın ortasında.
      final ids = ((_engineView(t) as dynamic).overlays as List<MapOverlay>)
          .whereType<MapMarker>()
          .where((m) => m.id.startsWith('wp:'))
          .map((m) => int.parse(m.id.substring(3)))
          .toList()
        ..sort();
      _markerTap(t, 'wp:${ids.last}');
      await _wait(t, 2.5);
      await _videoStop(t);
      await _shot(t, 'radyal', settle: 0.3);
      _mapTap(t, const LatLng(38.6400, 34.8200));
      await _wait(t, 1);
    });

    await _step(t, 'nokta-paleti', () async {
      _ctrl(t).moveTo(const LatLng(38.6480, 34.8290), zoom: 14.2);
      await _setDropMode(t, true);
      await _tapText(t, 'Görev');
      await _shot(t, 'nokta-paleti');
      await _tapText(t, 'Sadakat');
      await _setDropMode(t, false);
    });

    await _step(t, 'olcum', () async {
      _ctrl(t).moveTo(const LatLng(38.6500, 34.8150), zoom: 13.3);
      _c.read(bullseyeProvider.notifier).set(
          const Bullseye(center: RbEnd(_goreme), ringSpacing: 500, ringCount: 4));
      await _wait(t, 2);
      final rb = ((_engineView(t) as dynamic).overlays as List<MapOverlay>)
          .whereType<MapMarker>()
          .firstWhere((m) => m.id.startsWith('rb:'))
          .id;
      _markerTap(t, rb);
      await _wait(t, 1.2);
      await _tapText(t, 'Detay');
      await _shot(t, 'olcum', settle: 2);
      await _closeAll(t);
      _c.read(bullseyeProvider.notifier).set(null);
    });

    await _step(t, 'rota', () async {
      _c.read(activeRouteProvider.notifier).start(_patrol);
      _ctrl(t).moveTo(_self0, zoom: 15.4);
      _src.moveTo(_self0, headingDeg: _bearing(_route[0], _route[1]));
      await _tapLabel(t, 'Kendine ortala / takip et');
      await _wait(t, 3);
      await _videoStart(t, 'rota');
      var shotTaken = false;
      for (var leg = 0; leg < _route.length - 1; leg++) {
        final a = _route[leg], b = _route[leg + 1];
        final h = _bearing(a, b);
        for (var i = 1; i <= 75; i++) {
          final k = i / 75;
          _src.moveTo(
            LatLng(a.latitude + (b.latitude - a.latitude) * k,
                a.longitude + (b.longitude - a.longitude) * k),
            headingDeg: h,
          );
          await t.pump(const Duration(milliseconds: 50));
          // İkinci ayakta YASAK BÖLGE'ye girilir: uyarı ekrandayken.
          if (leg == 1 && i == 30) debugPrint('SHOT:geofence');
        }
        if (leg == 0 && !shotTaken) {
          shotTaken = true;
          debugPrint('SHOT:rota');
        }
      }
      await _videoStop(t);
      _c.read(activeRouteProvider.notifier).stop();
      _src.moveTo(_self0, headingDeg: 35);
      await _wait(t, 1.5);
    });

    await _step(t, 'taktik-pusula', () async {
      await _openTool(t, 'Taktik pusula');
      await _shot(t, 'taktik-pusula', settle: 2);
    });

    if (hasDem) {
      await _step(t, 'gorus-alani', () async {
        _ctrl(t).moveTo(const LatLng(38.6390, 34.8150), zoom: 13.2);
        await _wait(t, 2);
        await _c.read(viewshedProvider.notifier).run(
              const ViewshedParams(
                  observer: _uchisar, observerHeight: 10, radius: 3000),
              observerName: 'GN-1',
            );
        await _shot(t, 'gorus-alani', settle: 4);
        _c.read(viewshedProvider.notifier).clear();
      });

      await _step(t, 'arazi', () async {
        const c = LatLng(38.6450, 34.8250);
        _ctrl(t).moveTo(c, zoom: 13.6);
        await _c
            .read(terrainAnalysisProvider.notifier)
            .drawColor(c, 2200, TerrainColorMode.slope);
        await _c.read(terrainAnalysisProvider.notifier).drawContours(c, 2200);
        await _shot(t, 'arazi', settle: 4);
        _c.read(terrainAnalysisProvider.notifier).clear();
      });
    }

    await _step(t, 'olcum-alan', () async {
      _ctrl(t).moveTo(const LatLng(38.6560, 34.8300), zoom: 14.4);
      await _wait(t, 2);
      await _videoStart(t, 'cizim');
      await _openTool(t, 'Alan');
      for (final p in const [
        LatLng(38.6600, 34.8240),
        LatLng(38.6612, 34.8330),
        LatLng(38.6572, 34.8372),
        LatLng(38.6530, 34.8320),
        LatLng(38.6538, 34.8238),
      ]) {
        _mapTap(t, p);
        await _wait(t, 0.9);
      }
      await _wait(t, 1.5);
      await _videoStop(t);
      await _shot(t, 'olcum-alan', settle: 0.3);
      await t.tap(find.byTooltip('Temizle').first);
      await _wait(t, 0.5);
      await _closeMeasure(t);
    });

    await _step(t, 'sekil', () async {
      await _closeMeasure(t);
      _ctrl(t).moveTo(const LatLng(38.6672, 34.8242), zoom: 14.7);
      await _wait(t, 2);
      _mapTap(t, const LatLng(38.6690, 34.8215));
      await _wait(t, 1.2);
      await _tapText(t, 'Şekil');
      await _shot(t, 'sekil-duzenleme', settle: 1.5);
      await t.tap(find.byTooltip('Şekil düzenlemeyi iptal et'));
      await _wait(t, 0.8);
    });

    await _step(t, 'disa-aktar', () async {
      await _openTool(t, 'Dışa aktar');
      await _shot(t, 'disa-aktar');
    });

    await _step(t, 'rapor', () async {
      await _openTool(t, 'Raporlar');
      await _tapText(t, 'SPOTREP (SALUTE)');
      await _shot(t, 'rapor', settle: 1.5);
    });

    await _step(t, 'gunes-ay', () async {
      await _openTool(t, 'Güneş ve ay');
      await _shot(t, 'gunes-ay', settle: 2);
    });

    await _step(t, 'hava', () async {
      await _openTool(t, 'Hava durumu');
      await _wait(t, 1);
      final update = find.text('Güncelle');
      if (update.evaluate().isNotEmpty) {
        await t.tap(update.first);
      }
      await _shot(t, 'hava', settle: 5);
    });

    await _step(t, 'yedek', () async {
      await _openTool(t, 'Yedekle / geri yükle');
      await _shot(t, 'yedek');
    });

    await _step(t, 'gece', () async {
      _ctrl(t).moveTo(const LatLng(38.6500, 34.8290), zoom: 14);
      _c.read(nightModeProvider.notifier).toggle();
      await _shot(t, 'gece', settle: 4);
      _c.read(nightModeProvider.notifier).toggle();
      await _wait(t, 2);
    });

    await _step(t, 'yatay', () async {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft]);
      await _wait(t, 3);
      _ctrl(t).moveTo(const LatLng(38.6480, 34.8290), zoom: 13.8);
      await _shot(t, 'yatay', settle: 3);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      await _wait(t, 2);
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    });

    debugPrint('BİTTİ: atlananlar: ${_skipped.isEmpty ? 'yok' : _skipped.join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
