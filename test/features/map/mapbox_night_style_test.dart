import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/features/map/engine/mapbox_night_style.dart';

void main() {
  Map<String, Object> props(List<StyleEdit> edits, String id) => {
        for (final e in edits)
          if (e.layerId == id) e.property: e.value,
      };

  test('uydu (raster) siyah-beyaz ve karartılır', () {
    final edits = nightStyleEdits([(id: 'satellite', type: 'raster')]);
    final p = props(edits, 'satellite');
    expect(p['raster-saturation'], -1.0);
    expect(p['raster-brightness-max'], lessThanOrEqualTo(0.5));
  });

  test('yazılar kırmızı + siyah hale, yollar sönük kırmızı, zemin siyah', () {
    final edits = nightStyleEdits([
      (id: 'place-label', type: 'symbol'),
      (id: 'road', type: 'line'),
      (id: 'bg', type: 'background'),
    ]);
    expect(props(edits, 'place-label')['text-color'], nightTextColor);
    expect(props(edits, 'place-label')['text-halo-color'], '#000000');
    expect(props(edits, 'road')['line-color'], nightLineColor);
    expect(props(edits, 'bg')['background-color'], '#000000');
  });

  test('uygulamanın kendi katmanlarına dokunulmaz', () {
    final edits = nightStyleEdits(
      [(id: 'pz-lines', type: 'line'), (id: 'road', type: 'line')],
      keep: {'pz-lines'},
    );
    expect(edits.where((e) => e.layerId == 'pz-lines'), isEmpty);
    expect(edits.where((e) => e.layerId == 'road'), isNotEmpty);
  });

  test('gökyüzü söndürülür, bilinmeyen türler atlanır', () {
    final edits = nightStyleEdits([
      (id: 'pz-sky', type: 'sky'),
      (id: 'buildings', type: 'fill-extrusion'),
    ]);
    expect(props(edits, 'pz-sky')['sky-opacity'], 0.0);
    expect(edits.where((e) => e.layerId == 'buildings'), isEmpty);
  });
}
