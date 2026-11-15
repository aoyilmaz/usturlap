import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Sürüm imzası: önce android/key.properties (yerel, git'e girmez), yoksa ortam
// değişkenleri (GitHub Actions). İkisi de yoksa debug imzası kullanılır; böylece
// geliştirici derlemeleri anahtar deposu olmadan da çalışır.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun signingValue(prop: String, env: String): String? =
    keyProps.getProperty(prop) ?: System.getenv(env)

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "com.aoyilmaz.usturlap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications eski Android'lerde java.time için ister.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Kalıcı uygulama kimliği (iOS paket kimliğiyle aynı).
        applicationId = "com.aoyilmaz.usturlap"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // MainActivity'deki telemetri ayarı için yalnız derlemede gerekir; çalışma
    // anında kütüphaneyi mapbox_maps_flutter getirir. Mapbox eklentisi
    // güncellenince sürüm, onun çektiği common-ndk27 sürümüyle eşleştirilmeli
    // (mapbox_maps_flutter_mobile 3.34.1 → Maps 11.34.1 → Common 24.34.1).
    compileOnly("com.mapbox.common:common-ndk27:24.34.1")
}

flutter {
    source = "../.."
}
