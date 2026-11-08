import 'package:latlong2/latlong.dart';

import '../../core/nav_math.dart';
import 'range_line.dart';

/// ETA rengine göre yakınlık: uzak (yeşil), yaklaşıyor (sarı), yakın
/// (kırmızı). Hız bilinmiyorsa (iki sabit nokta) seviye yok.
enum EtaLevel { far, near, close }

/// Bloodhound ETA eşikleri (ATAK, kılavuz s.18–19): ETA [alarm]'dan kısaysa
/// kırmızı, [warn]'dan kısaysa sarı, değilse yeşil.
class EtaThresholds {
  const EtaThresholds({
    this.warn = const Duration(minutes: 15),
    this.alarm = const Duration(minutes: 5),
  });

  final Duration warn;
  final Duration alarm;

  static const minMinutes = 1;
  static const maxMinutes = 120;

  EtaLevel level(Duration eta) {
    if (eta <= alarm) return EtaLevel.close;
    if (eta <= warn) return EtaLevel.near;
    return EtaLevel.far;
  }

  /// Dakika cinsinden değiştirir; sınırlar korunur (1–120 dk, kırmızı
  /// sarıdan en az 1 dk kısa).
  EtaThresholds withMinutes({int? warn, int? alarm}) {
    var w = (warn ?? this.warn.inMinutes).clamp(minMinutes + 1, maxMinutes);
    var a = (alarm ?? this.alarm.inMinutes).clamp(minMinutes, maxMinutes - 1);
    if (a >= w) {
      // Hangisi değiştiyse öteki ona uyar.
      if (alarm != null) {
        w = a + 1;
      } else {
        a = w - 1;
      }
    }
    return EtaThresholds(
      warn: Duration(minutes: w),
      alarm: Duration(minutes: a),
    );
  }

  Map<String, Object?> toJson() => {
    'warn': warn.inMinutes,
    'alarm': alarm.inMinutes,
  };

  static EtaThresholds fromJson(Object? json) {
    if (json is! Map) return const EtaThresholds();
    final w = json['warn'], a = json['alarm'];
    if (w is! int || a is! int) return const EtaThresholds();
    return const EtaThresholds().withMinutes(warn: w, alarm: a);
  }
}

/// Bir takip (ATAK Bloodhound): [from]'dan [to]'ya canlı kerteriz, mesafe
/// ve ETA. Uçlar R&B ucu gibi bağlı: ben yürüdükçe / nokta taşınınca
/// güncellenir. "Git" hedefi gibi yalnız bellekte tutulur.
class Bloodhound {
  const Bloodhound({required this.id, required this.from, required this.to});

  final int id;
  final RbEnd from;
  final RbEnd to;

  /// Hız yalnız kendi konumumdan bilinir: uçlardan biri bensem ETA var.
  bool get hasSpeed => from.isSelf || to.isSelf;
}

/// Bir takibin anlık okuması.
class BloodhoundReading {
  const BloodhoundReading({
    required this.meters,
    required this.bearing,
    this.eta,
    this.estimated = false,
    this.level,
  });

  /// [speedMps]: ilgili hız (benim hızım); null ise ETA hesaplanmaz.
  /// Duruyorsam ETA yürüyüş hızıyla tahmin edilir ([estimated]).
  factory BloodhoundReading.of(
    LatLng from,
    LatLng to, {
    required bool hasSpeed,
    double? speedMps,
    EtaThresholds thresholds = const EtaThresholds(),
  }) {
    final meters = NavMath.distance(from, to);
    final bearing = NavMath.bearing(from, to);
    if (!hasSpeed) {
      return BloodhoundReading(meters: meters, bearing: bearing);
    }
    final eta = NavMath.eta(meters, speedMps);
    return BloodhoundReading(
      meters: meters,
      bearing: bearing,
      eta: eta,
      estimated: speedMps == null || speedMps < 0.5,
      level: eta == null ? null : thresholds.level(eta),
    );
  }

  final double meters;
  final double bearing;
  final Duration? eta;

  /// ETA gerçek hızdan değil, yürüyüş hızı varsayımından.
  final bool estimated;
  final EtaLevel? level;
}
