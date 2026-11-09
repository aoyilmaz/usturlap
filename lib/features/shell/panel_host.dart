import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'atak_toolbar.dart';

/// Ekran yatay mı (genişlik > yükseklik). Yerleşim kararları için tek kaynak.
bool isLandscape(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width > s.height;
}

/// Yatay ekranda sağ yan panel genişliği.
double sidePanelWidth(BuildContext context) =>
    math.min(420.0, MediaQuery.sizeOf(context).width * 0.45);

/// ATAK yan panelleri (DropDown, kılavuz s.5): harita sayfasının üstünde ama
/// **modal değil**, panel açıkken harita kaydırılır, dokunulur, ölçülür
/// (karartma yok). Yatayda sağdan (ekranın ~%45'i, tam boy), dikeyde alttan
/// (en çok yarım ekran; tutamağı yukarı çekince büyür, aşağı çekince kapanır).
///
/// Paneller sayfanın geri yığınına (`LocalHistoryEntry`) eklenir: içerikteki
/// `Navigator.of(context).pop()` ve Android geri tuşu en üstteki paneli
/// kapatır. Eski modal sayfalarla aynı davranış; içerikler değişmez.
///
/// Açılış kuralı (ATAK gibi tek panel):
/// - Haritadan / araç çubuğundan açılan panel öncekileri kapatır.
/// - Bir panelin içinden açılan panel onun üstüne biner; kapanınca alttaki
///   geri gelir (ör. Katmanlar → Çevrimdışı bölgeler).
class PanelHost extends StatefulWidget {
  const PanelHost({super.key, required this.child});

  /// Harita ekranı (paneller bunun üstünde çizilir).
  final Widget child;

  static PanelHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<PanelHostState>();

  /// Panellerin haritadan kapladığı kenar: yatayda `right`, dikeyde `bottom`
  /// (panel yüksekliği, alttaki güvenli alan dahil). Harita ekranı köşe
  /// kutularını ve Mapbox logosunu buna göre kaydırır.
  static ValueListenable<EdgeInsets> insetsOf(BuildContext context) =>
      maybeOf(context)?.insets ?? const _NoInsets();

  @override
  State<PanelHost> createState() => PanelHostState();
}

/// Barındırıcı yoksa (ör. testte tek widget): hiç kayma yok.
class _NoInsets implements ValueListenable<EdgeInsets> {
  const _NoInsets();
  @override
  EdgeInsets get value => EdgeInsets.zero;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// Panel içeriğinin altına konur: içeriden açılan panel "iç içe" sayılır.
class _PanelScope extends InheritedWidget {
  const _PanelScope({required super.child});
  @override
  bool updateShouldNotify(_PanelScope oldWidget) => false;
}

class _Panel {
  _Panel({
    required this.id,
    required this.builder,
    required this.showHandle,
    required this.controller,
    this.menu = false,
  }) : curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

  final String? id;

  /// Menü paneli (≡ ızgarası): üstündeki panel "← Geri" dışında bir yolla
  /// kapanırsa (✕, haritaya götüren bir eylem, tutamak) menü de kapanır.
  final bool menu;

  /// "← Geri" ile kapatıldı: alttaki menüye dönülür.
  bool viaBack = false;
  final WidgetBuilder builder;
  final bool showHandle;
  final AnimationController controller;
  final CurvedAnimation curve;
  final Completer<void> done = Completer<void>();

  /// Panel kutusu (Positioned) için anahtar: liste değişince yeri korunur.
  final Key key = UniqueKey();

  /// İçerik için: ekran dönünce (sağ panel ↔ alt panel) durumu korunsun.
  final GlobalKey contentKey = GlobalKey();

  LocalHistoryEntry? history;
  bool closing = false;

  /// Dikeyde: tutamak yukarı çekildi → neredeyse tam ekran.
  bool expanded = false;

  /// Dikeyde ölçülen yükseklik (harita ekranı köşe kutularını kaydırır).
  double height = 0;

  /// Tutamak sürüklemesi (dikey toplam).
  double drag = 0;

  void dispose() {
    curve.dispose();
    controller.dispose();
    if (!done.isCompleted) done.complete();
  }
}

class PanelHostState extends State<PanelHost> with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);

  final _panels = <_Panel>[];
  final _insets = ValueNotifier<EdgeInsets>(EdgeInsets.zero);
  EdgeInsets? _pendingInsets;
  ModalRoute<Object?>? _route;

  ValueListenable<EdgeInsets> get insets => _insets;

  /// Açık (kapanmakta olmayan) panel var mı.
  bool get hasOpenPanel => _top != null;

  /// [runStacked] içindeyken açılan paneller açık olanların üstüne biner.
  int _stackDepth = 0;
  int _openCount = 0;

  /// [f] içinde açılan panel, açık panellerin üstüne biner (≡ ızgarasından
  /// açılan araçlar; "← Geri" ile ızgaraya dönülür). [f] bir panel açtıysa
  /// true.
  bool runStacked(VoidCallback f) {
    final before = _openCount;
    _stackDepth++;
    try {
      f();
    } finally {
      _stackDepth--;
    }
    return _openCount != before;
  }

  /// [id]'li paneli kapatır (açık değilse bir şey yapmaz).
  void closeId(String id) {
    for (final p in _panels.reversed) {
      if (!p.closing && p.id == id) _close(p);
    }
  }

  /// [p]'nin altındaki (kapanmakta olmayan) panel.
  _Panel? _below(_Panel p) {
    for (var i = _panels.indexOf(p) - 1; i >= 0; i--) {
      if (!_panels[i].closing) return _panels[i];
    }
    return null;
  }

  _Panel? get _top {
    for (final p in _panels.reversed) {
      if (!p.closing) return p;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  /// Panel açar. [opener] çağıranın context'i: bir panelin içindeyse yeni
  /// panel onun üstüne biner, değilse açık paneller kapanır.
  /// [toggle] + [id]: en üstte aynı panel açıksa kapatır (araç çubuğu düğmesi
  /// ikinci kez basılınca, ATAK gibi).
  Future<void> open({
    required BuildContext opener,
    required WidgetBuilder builder,
    String? id,
    bool toggle = false,
    bool showDragHandle = true,
    bool menu = false,
  }) {
    final top = _top;
    if (toggle && id != null && top != null && top.id == id) {
      closeAll();
      return top.done.future;
    }
    final nested =
        _stackDepth > 0 ||
        opener.getInheritedWidgetOfExactType<_PanelScope>() != null;
    if (!nested) closeAll();
    _openCount++;

    final p = _Panel(
      id: id,
      builder: builder,
      showHandle: showDragHandle,
      menu: menu,
      controller: AnimationController(vsync: this, duration: _duration),
    );
    // Giriş bitince alttaki panel gizlenir (bkz. _visible).
    p.controller.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
    final route = _route;
    if (route != null) {
      final entry = LocalHistoryEntry(onRemove: () => _dismiss(p));
      p.history = entry;
      route.addLocalHistoryEntry(entry);
    }
    setState(() => _panels.add(p));
    p.controller.forward();
    return p.done.future;
  }

  /// En üstteki paneli kapatır.
  void closeTop() {
    final t = _top;
    if (t != null) _close(t);
  }

  /// Bütün panelleri kapatır.
  void closeAll() {
    for (final p in _panels.toList()) {
      _close(p);
    }
  }

  void _close(_Panel p) {
    final h = p.history;
    // Geri yığınından düşür; onRemove → _dismiss.
    if (h != null) h.remove();
    _dismiss(p);
  }

  /// Kapanış animasyonu; bitince listeden çıkar. Birden çok kez çağrılabilir.
  void _dismiss(_Panel p) {
    p.history = null;
    if (p.closing || !mounted) return;
    // Menünün üstündeki panel "← Geri" dışında kapandıysa menü de gider
    // (ör. "Haritada göster" sonrası harita üstünde menü kalmasın).
    final below = _below(p);
    setState(() => p.closing = true);
    if (!p.viaBack && below != null && below.menu) {
      // Geri yığını şu an bu paneli çıkarıyor olabilir (Navigator.pop);
      // iç içe çıkarma olmasın diye bir sonraki turda.
      scheduleMicrotask(() {
        if (mounted && !below.closing) _close(below);
      });
    }
    p.controller.reverse().then((_) {
      if (!mounted) return;
      setState(() => _panels.remove(p));
      p.dispose();
    });
  }

  @override
  void dispose() {
    for (final p in _panels) {
      p.dispose();
    }
    _insets.dispose();
    super.dispose();
  }

  /// Panel görünür mü: en üstteki ve kapanmakta olanlar. Üstteki panel
  /// girerken alttaki de görünür kalır (arada harita parlamasın).
  bool _visible(_Panel p, _Panel? top) {
    if (p.closing || identical(p, top)) return true;
    if (top == null || top.controller.status == AnimationStatus.completed) {
      return false;
    }
    for (var i = _panels.indexOf(top) - 1; i >= 0; i--) {
      if (!_panels[i].closing) return identical(_panels[i], p);
    }
    return false;
  }

  /// Kenar payını kare bittikten sonra yayınla (dinleyiciler setState eder;
  /// derleme sırasında olamaz).
  void _syncInsets(EdgeInsets v) {
    if (_pendingInsets == null) {
      if (v == _insets.value) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final x = _pendingInsets;
        _pendingInsets = null;
        if (mounted && x != null) _insets.value = x;
      });
    }
    _pendingInsets = v;
  }

  void _onDragEnd(_Panel p, DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dy = p.drag;
    p.drag = 0;
    if (dy < -24 || v < -300) {
      setState(() => p.expanded = true);
    } else if (dy > 24 || v > 300) {
      if (p.expanded) {
        setState(() => p.expanded = false);
      } else {
        _close(p);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape = isLandscape(context);
    final top = _top;
    _syncInsets(
      top == null
          ? EdgeInsets.zero
          : landscape
          ? EdgeInsets.only(right: sidePanelWidth(context))
          : EdgeInsets.only(bottom: top.height),
    );
    // Dış Scaffold: bilgi şeritleri (SnackBar) en dıştaki Scaffold'da
    // çizilir → panelin arkasında kalmaz (ör. koordinat panelinde
    // "Kopyalandı"). Klavye payını paneller kendisi uygular (resize yok).
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          for (final p in _panels)
            _positioned(context, p, landscape, visible: _visible(p, top)),
        ],
      ),
    );
  }

  Widget _positioned(
    BuildContext context,
    _Panel p,
    bool landscape, {
    required bool visible,
  }) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    Widget body = SlideTransition(
      position: Tween(
        begin: landscape ? const Offset(1, 0) : const Offset(0, 1),
        end: Offset.zero,
      ).animate(p.curve),
      child: _surface(context, p, landscape),
    );
    // Alttaki (gizli) panel durumunu korur ama çizilmez, dokunulmaz.
    body = TickerMode(
      enabled: visible,
      child: Offstage(offstage: !visible, child: body),
    );
    if (landscape) {
      return Positioned(
        key: p.key,
        top: 0,
        bottom: keyboard,
        right: 0,
        width: sidePanelWidth(context),
        child: body,
      );
    }
    return Positioned(
      key: p.key,
      left: 0,
      right: 0,
      bottom: keyboard,
      child: body,
    );
  }

  Widget _surface(BuildContext context, _Panel p, bool landscape) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    // İçeriğe giden ölçüler: panel klavyenin üstünde durduğu için klavye
    // payı yok; panelin dokunmadığı kenarın (dikeyde üst, yatayda sol)
    // güvenli alanı da yok, yoksa içerikteki SafeArea boşuna boşluk bırakır.
    final data = mq
        .removePadding(removeTop: !landscape, removeLeft: landscape)
        .removeViewInsets(removeBottom: true);

    final content = Flexible(
      fit: landscape ? FlexFit.tight : FlexFit.loose,
      child: _PanelScope(
        child: KeyedSubtree(
          key: p.contentKey,
          child: Builder(builder: p.builder),
        ),
      ),
    );

    Widget surface = Material(
      color:
          theme.bottomSheetTheme.backgroundColor ??
          theme.colorScheme.surfaceContainerLow,
      elevation: 8,
      borderRadius: landscape
          ? const BorderRadius.horizontal(left: Radius.circular(16))
          : const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery(
        data: data,
        child: SafeArea(
          child: Column(
            mainAxisSize: landscape ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_header(context, p, landscape), content],
          ),
        ),
      ),
    );
    if (landscape) return surface;

    // Dikey: içerik kadar, en çok yarım ekran (klavye açıkken ya da tutamak
    // yukarı çekilince araç çubuğunun altına kadar).
    final avail = mq.size.height - mq.viewInsets.bottom;
    final full = math.max(
      160.0,
      avail - mq.padding.top - kAtakToolbarHeight - 12,
    );
    final maxH = (p.expanded || mq.viewInsets.bottom > 0)
        ? full
        : math.min(full, avail * 0.5);
    surface = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: surface,
    );
    return _SizeReporter(
      onSize: (s) {
        if (!mounted || s.height == p.height) return;
        setState(() => p.height = s.height);
      },
      child: surface,
    );
  }

  /// "← Geri": bu paneli kapatıp alttakine (menüye) dön.
  void _back(_Panel p) {
    p.viaBack = true;
    _close(p);
  }

  /// Panel başlığı: dikeyde sürükleme tutamağı; altta panel varsa solda
  /// "← Geri"; sağda ✕ (bütün panelleri kapatır).
  Widget _header(BuildContext context, _Panel p, bool landscape) {
    final close = Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        tooltip: 'Kapat',
        icon: const Icon(Icons.close),
        onPressed: closeAll,
      ),
    );
    final back = _below(p) == null
        ? null
        : Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Geri',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _back(p),
            ),
          );
    if (landscape) {
      return SizedBox(
        height: 48,
        child: Stack(children: [?back, close]),
      );
    }
    final handleColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => p.drag = 0,
      onVerticalDragUpdate: (d) => p.drag += d.delta.dy,
      onVerticalDragEnd: (d) => _onDragEnd(p, d),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            if (p.showHandle)
              Center(
                child: Semantics(
                  label: 'Panel tutamağı',
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ?back,
            close,
          ],
        ),
      ),
    );
  }
}

/// Çocuğunun boyutu değişince (yerleşimden sonra, kare sonunda) bildirir.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final s = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(s));
  }
}
