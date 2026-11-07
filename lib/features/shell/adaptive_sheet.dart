import 'package:flutter/material.dart';

import 'panel_host.dart';

export 'panel_host.dart'
    show PanelHost, PanelHostState, isLandscape, sidePanelWidth;

/// Menü/liste açar: **dikeyde alttan**, **yatayda sağdan** panel (ATAK gibi).
///
/// Harita ekranında ([PanelHost] altında) panel **modal değildir**: harita
/// kullanılabilir kalır, `Navigator.pop` en üstteki paneli kapatır. Bkz.
/// [PanelHost] (hangi panelin hangisini kapattığı orada).
///
/// Barındırıcı yoksa (ör. bir diyalogdan çağrılırsa) eski davranış: modal
/// alttan sayfa / sağdan panel.
///
/// [id] + [toggle]: aynı düğme ikinci kez basılınca panel kapanır.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = false,
  String? id,
  bool toggle = false,
}) {
  final host = PanelHost.maybeOf(context);
  if (host != null) {
    return host
        .open(
          opener: context,
          builder: builder,
          id: id,
          toggle: toggle,
          showDragHandle: showDragHandle,
        )
        .then((_) => null);
  }

  if (!isLandscape(context)) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  final width = sidePanelWidth(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      final theme = Theme.of(context);
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color:
              theme.bottomSheetTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerLow,
          elevation: 8,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: SafeArea(
              left: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Kapat',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  // İçerik kendi kaydırmasını yapar (ListView); taşarsa kaydır.
                  Expanded(child: Builder(builder: builder)),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
