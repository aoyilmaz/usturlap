/// Track kaydı için GPS doğruluk filtresi (saf, test edilebilir).
class TrackFilter {
  TrackFilter._();

  /// Bu eşikten (± metre) daha kötü doğruluğa sahip noktalar atlanır.
  static const double maxAccuracyMeters = 20.0;

  /// Filtre açıkken: doğruluk biliniyorsa ve eşikten kötüyse noktayı reddet.
  /// Doğruluk bilinmiyorsa (null) kabul edilir.
  static bool accuracyOk(double? accuracyMeters, bool filterOn) {
    if (!filterOn) return true;
    if (accuracyMeters == null) return true;
    return accuracyMeters <= maxAccuracyMeters;
  }
}
