import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/ports/alert_output.dart';

/// Cihazın konuşma sentezi (iOS AVSpeechSynthesizer) ile Türkçe okuma.
///
/// iOS ses oturumu "playback": ses medya ses düzeyiyle çıkar, sessiz
/// düğmesinden etkilenmez (ATAK'ın Android'deki davranışı); başka ses
/// (müzik) çalıyorsa kısılır, sonra geri gelir. Kapatmak için Ayarlar.
class TtsSpeaker implements Speaker {
  TtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _ready;

  Future<void> _init() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.5);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
    } catch (_) {
      // Ayar yapılamadıysa varsayılanla okunur.
    }
  }

  @override
  Future<void> speak(String text) async {
    try {
      await (_ready ??= _init());
      // Yeni uyarı eskisini keser (sıra birikmesin).
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      // Ses yoksa uyarı yine ekranda ve titreşimle verilir.
      debugPrint('Sesli uyarı okunamadı: $e');
    }
  }
}
