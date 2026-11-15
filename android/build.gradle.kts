allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Bazı eklentiler (mapbox_maps_flutter_mobile, file_picker, battery_plus) AGP
// 9'da Kotlin desteğini AGP'nin yerleşik Kotlin'inden bekliyor ve kotlin-android'i
// uygulamıyor; Flutter şablonu ise yerleşik Kotlin'i kapatıyor
// (gradle.properties: android.builtInKotlin=false). Sonuç: Kotlin kaynakları
// derlenmiyor. Kotlin'i uygulamamış her Android kütüphanesine, kütüphane
// eklentisi uygulandığı anda kotlin-android'i biz ekleriz (zaten uygulayan
// eklentilerde sonraki "apply" etkisizdir).
subprojects {
    pluginManager.withPlugin("com.android.library") {
        if (!pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
