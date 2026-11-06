import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ekran yatay mı (genişlik > yükseklik). Yerleşim kararları için tek kaynak.
bool isLandscape(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width > s.height;
}

/// Yatay ekranda sağ yan panel genişliği.
double sidePanelWidth(BuildContext context) =>
    math.min(420.0, MediaQuery.sizeOf(context).width * 0.45);

/// Menü/liste açar: **dikeyde alttan sayfa**, **yatayda sağdan yan panel**
/// (ATAK gibi — haritanın solu görünür kalır).
///
/// `showModalBottomSheet` ile aynı imza (showDragHandle/isScrollControlled
/// dikey modda aynen uygulanır), böylece çağıranlar yalnızca adı değiştirir.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = false,
}) {
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
          color: theme.bottomSheetTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerLow,
          elevation: 8,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
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
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
