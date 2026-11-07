import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/toolbar_tool.dart';

void main() {
  group('ToolbarTool kalıcı biçim', () {
    test('kodla → çöz aynı listeyi verir (sıra korunur)', () {
      const tools = [
        ToolbarTool.record,
        ToolbarTool.maps,
        ToolbarTool.nightMode,
      ];
      expect(ToolbarTool.decode(ToolbarTool.encode(tools)), tools);
    });

    test('boş metin: çubukta yalnız ≡', () {
      expect(ToolbarTool.decode(''), isEmpty);
    });

    test('bilinmeyen ad ve tekrar atlanır', () {
      expect(ToolbarTool.decode('maps,eskiArac,maps, record'), [
        ToolbarTool.maps,
        ToolbarTool.record,
      ]);
    });

    test('en çok maxOnBar araç', () {
      final all = ToolbarTool.encode(ToolbarTool.values);
      expect(ToolbarTool.decode(all), hasLength(ToolbarTool.maxOnBar));
    });

    test('varsayılan çubuk sınıra sığar', () {
      expect(
        ToolbarTool.defaults.length,
        lessThanOrEqualTo(ToolbarTool.maxOnBar),
      );
    });
  });
}
