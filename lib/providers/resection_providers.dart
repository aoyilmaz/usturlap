import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/resection.dart';

/// Geriden kestirme panelinin haritada gösterdiği önizleme: nişan
/// çizgileri, hata alanı ve bulunan konum. Panel kapanınca temizlenir.
class ResectionPreview {
  const ResectionPreview(this.sightings, this.result);

  final List<Sighting> sightings;
  final ResectionResult result;
}

class ResectionPreviewNotifier extends Notifier<ResectionPreview?> {
  @override
  ResectionPreview? build() => null;

  /// Panel kapanırken (bir sonraki turda) çağrılır; o arada kapsam da
  /// kapandıysa (test sonu) dokunulmaz.
  void show(ResectionPreview? p) {
    if (ref.mounted) state = p;
  }
}

final resectionPreviewProvider =
    NotifierProvider<ResectionPreviewNotifier, ResectionPreview?>(
      ResectionPreviewNotifier.new,
    );
