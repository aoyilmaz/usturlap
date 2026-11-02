import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Bir widget'ı ekrana koymadan PNG'ye çevirir (Mapbox sembol resimleri için).
///
/// Widget ağaca bağlanmadan, kendi küçük render ağacında bir kez çizilir.
/// Yalnızca görsel widget'lar içindir (Icon, Container, CustomPaint …);
/// dokunma/animasyon içermemeli.
Future<ui.Image> rasterizeWidget(
  Widget widget, {
  required Size size,
  required double pixelRatio,
}) async {
  final boundary = RenderRepaintBoundary();
  final view = ui.PlatformDispatcher.instance.implicitView ??
      ui.PlatformDispatcher.instance.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();

  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(devicePixelRatio: pixelRatio),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox.fromSize(size: size, child: widget)),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  buildOwner
    ..buildScope(root)
    ..finalizeTree();
  pipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();

  return boundary.toImage(pixelRatio: pixelRatio);
}

/// [rasterizeWidget] + PNG kodlama.
Future<List<int>> rasterizeWidgetToPng(
  Widget widget, {
  required Size size,
  required double pixelRatio,
}) async {
  final image =
      await rasterizeWidget(widget, size: size, pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
