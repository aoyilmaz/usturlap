import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/cot/cot_mapper.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/features/symbols/nato_symbol.dart';

/// D3h: her tür tek widget'tan çizilir.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Center(child: child)));

  testWidgets('bütün tür × ana ikon birleşimleri hatasız çizilir', (
    tester,
  ) async {
    await pump(
      tester,
      Wrap(
        children: [
          for (final a in Affiliation.values)
            for (final r in SymbolRole.values)
              PointSymbol(
                affiliation: a,
                role: r,
                echelon: Echelon.squad,
                size: 34,
              ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sade nokta iğne, görev noktası rozet, sadakat çerçeve', (
    tester,
  ) async {
    await pump(tester, const PointSymbol(affiliation: Affiliation.waypoint));
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.byType(NatoSymbol), findsNothing);

    await pump(
      tester,
      const PointSymbol(affiliation: Affiliation.observationPost),
    );
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byType(NatoSymbol), findsNothing);

    await pump(tester, const PointSymbol(affiliation: Affiliation.suspect));
    expect(find.byType(NatoSymbol), findsOneWidget);
  });

  test('görev noktası ikonları birbirinden farklı', () {
    final icons = {
      for (final a in Affiliation.values.where((a) => a.isMission))
        missionIcon(a),
    };
    expect(icons, hasLength(4));
  });

  test('ATAK\'a giden görev rengi Pusula\'daki rozetle aynı', () {
    expect(missionColor.toARGB32(), CotMapper.missionColor);
  });

  test('tür grupları: her tür tam olarak bir grupta', () {
    for (final a in Affiliation.values) {
      final groups = [
        a == Affiliation.waypoint,
        a.isMission,
        a.isNato,
      ].where((g) => g);
      expect(groups, hasLength(1), reason: a.name);
    }
    expect(Affiliation.values.where((a) => a.isUncertain), [
      Affiliation.assumedFriend,
      Affiliation.suspect,
    ]);
  });
}
