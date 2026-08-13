pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9로 올리면 안드로이드 빌드가 깨진다 — file_picker는 AGP 9 이상에서
    // KGP를 스스로 적용하지 않아 built-in Kotlin을 켜야 하는데, desktop_drop은
    // kotlin-android를 무조건 적용해서 built-in Kotlin과 충돌한다.
    // 두 패키지 모두 최신이라 올려서 풀 수 없으므로 AGP를 8.x에 묶어둔다.
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // FCM — google-services.json 을 읽어 Firebase 설정을 빌드에 심는다.
    // **안드로이드에만 붙는다** (애플은 APNs 를 직접 친다).
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
