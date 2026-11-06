import 'package:flutter/widgets.dart';

/// Altındaki bütün ağacı sıfırdan kurabilen kapsayıcı.
///
/// [restart] çağrılınca alt ağaç yeni bir anahtarla yeniden oluşturulur:
/// içerideki ProviderScope (riverpod'un kök kapsayıcısı) dahil bütün durum
/// atılır; provider'lar kapanır (veritabanı, konum akışı) ve yeniden açılır.
/// Acil veri silmeden sonra kullanılır (ATAK bu noktada uygulamadan çıkar).
class RestartScope extends StatefulWidget {
  const RestartScope({super.key, required this.child});

  final Widget child;

  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_RestartScopeState>()?._restart();

  @override
  State<RestartScope> createState() => _RestartScopeState();
}

class _RestartScopeState extends State<RestartScope> {
  Key _key = UniqueKey();

  void _restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
