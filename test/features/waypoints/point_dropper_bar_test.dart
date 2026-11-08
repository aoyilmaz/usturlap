import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/sequential_name.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/features/waypoints/point_dropper_bar.dart';

/// D3d + D3h: ATAK Point Dropper paleti (Sadakat / Görev / Tehlike).
void main() {
  late List<String> log;

  Future<void> pump(
    WidgetTester tester, {
    bool crosshair = false,
    String selected = 'hostile',
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width * 3, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    log = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              // Harita ekranındaki gibi: sol sütunun sağında.
              padding: const EdgeInsets.only(left: 66, right: 8),
              child: PointDropperBar(
                selected: DropKind.byId(selected),
                nextName: 'DÜŞMAN-3',
                onSelect: (k) => log.add(k.id),
                onClose: () => log.add('kapat'),
                onDropAtCrosshair: crosshair ? () => log.add('imleç') : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void expectTappable(WidgetTester tester, String label) {
    final f = find.bySemanticsLabel(label);
    expect(f, findsOneWidget, reason: label);
    final size = tester.getSize(f);
    expect(size.width, greaterThanOrEqualTo(48), reason: label);
    expect(size.height, greaterThanOrEqualTo(44), reason: label);
  }

  testWidgets('Sadakat sekmesi: altı tür, seçili işaretli; sıradaki ad', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull); // 390 pt'ye taşmadan sığar
    for (final l in [
      'Dost',
      'Varsayılan dost',
      'Düşman',
      'Şüpheli',
      'Nötr',
      'Bilinmeyen',
    ]) {
      expectTappable(tester, l);
    }
    for (final l in ['Sekme: Sadakat', 'Sekme: Görev', 'Sekme: Tehlike']) {
      expectTappable(tester, l);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Düşman')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Sekme: Sadakat')),
      isSemantics(isSelected: true),
    );
    expect(find.text('Haritaya dokun → DÜŞMAN-3'), findsOneWidget);
    expect(find.text('İmlece bırak'), findsNothing);
  });

  testWidgets('sekmeler: Görev ve Tehlike türleri seçilir', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Sekme: Görev'));
    await tester.pump();
    for (final l in [
      'Nokta',
      'Gözetleme noktası',
      'Kontrol noktası',
      'Toplanma noktası',
      'Sensör',
    ]) {
      expectTappable(tester, l);
    }
    expect(find.bySemanticsLabel('Düşman'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Gözetleme noktası'));

    await tester.tap(find.bySemanticsLabel('Sekme: Tehlike'));
    await tester.pump();
    for (final l in ['Mayın', 'KBRN', 'Bariyer']) {
      expectTappable(tester, l);
    }
    await tester.tap(find.bySemanticsLabel('Mayın'));
    await tester.tap(find.byTooltip('Nokta bırakmayı kapat'));
    expect(log, ['observationPost', 'mine', 'kapat']);
  });

  testWidgets('açılışta seçili türün sekmesi görünür', (tester) async {
    await pump(tester, selected: 'cbrn');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Sekme: Tehlike')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('KBRN')),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('dar ekranda da taşmaz (yana kaydırılır)', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artı imleç açıksa "İmlece bırak"', (tester) async {
    await pump(tester, crosshair: true);
    await tester.tap(find.text('İmlece bırak'));
    expect(log, ['imleç']);
  });

  group('DropKind', () {
    test('Türkçe ad önekleri ve sıra numarası', () {
      String prefix(String id) => DropKind.byId(id).prefix;
      expect(prefix('hostile'), 'DÜŞMAN');
      expect(prefix('waypoint'), 'NOKTA');
      expect(prefix('observationPost'), 'GN');
      expect(prefix('checkpoint'), 'KN');
      expect(prefix('rallyPoint'), 'TN');
      expect(prefix('sensor'), 'SN');
      expect(prefix('assumedFriend'), 'V.DOST');
      // Noktalı önek de doğru sayılır.
      expect(
        nextSequentialName(prefix('assumedFriend'), ['V.DOST-2', 'VXDOST-9']),
        'V.DOST-3',
      );
    });

    test('tehlikeler düşman sadakatiyle ve kendi ikonuyla düşer', () {
      for (final (id, role) in [
        ('mine', SymbolRole.mine),
        ('cbrn', SymbolRole.cbrn),
        ('barrier', SymbolRole.barrier),
      ]) {
        final k = DropKind.byId(id);
        expect(k.affiliation, Affiliation.hostile, reason: id);
        expect(k.role, role, reason: id);
        expect(k.group, DropGroup.hazard, reason: id);
      }
    });

    test('eski sürümün kaydı (tür adı) okunur; bilinmeyen → düşman', () {
      for (final a in [
        Affiliation.friend,
        Affiliation.hostile,
        Affiliation.neutral,
        Affiliation.unknown,
        Affiliation.waypoint,
      ]) {
        expect(DropKind.byId(a.name).affiliation, a);
      }
      expect(DropKind.byId('eski-bir-sey'), DropKind.defaultKind);
      expect(DropKind.byId(null).affiliation, Affiliation.hostile);
    });

    test('kimlikler benzersiz; her tür bir sekmede', () {
      final ids = DropKind.all.map((k) => k.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final a in Affiliation.values) {
        expect(
          DropKind.all.where(
            (k) => k.affiliation == a && k.role == SymbolRole.none,
          ),
          hasLength(1),
          reason: a.name,
        );
      }
      for (final g in DropGroup.values) {
        expect(DropKind.inGroup(g).length, lessThanOrEqualTo(6));
      }
    });
  });
}
