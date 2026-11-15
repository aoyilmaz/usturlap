package com.aoyilmaz.usturlap

import android.os.Bundle
import com.mapbox.common.TelemetryUtils
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        disableMapboxTelemetryByDefault()
        super.onCreate(savedInstanceState)
    }

    /**
     * Mapbox'ın isteğe bağlı kullanım / konum telemetrisi varsayılan olarak
     * kapalı başlar (iOS'ta AppDelegate aynısını yapar). Yalnız ilk açılışta
     * çağrılır: kullanıcı haritanın (i) menüsünden telemetriyi açarsa seçimi
     * korunur. Faturalandırma için zorunlu harita yükleme sayımı etkilenmez.
     */
    private fun disableMapboxTelemetryByDefault() {
        val prefs = getSharedPreferences("usturlap", MODE_PRIVATE)
        if (prefs.getBoolean(TELEMETRY_DEFAULT_SET, false)) return
        try {
            TelemetryUtils.setEventsCollectionState(false, null)
            prefs.edit().putBoolean(TELEMETRY_DEFAULT_SET, true).apply()
        } catch (e: Throwable) {
            // Mapbox henüz yüklenemediyse sonraki açılışta yeniden denenir.
        }
    }

    private companion object {
        const val TELEMETRY_DEFAULT_SET = "mapbox_telemetry_default_set"
    }
}
