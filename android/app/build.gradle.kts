import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리즈 서명 정보 — android/key.properties 에서 읽는다.
//
// 이 파일과 키스토어(.jks)는 **gitignore 되어 레포에 없다.** 잃어버리면 복구가
// 안 되고 그 앱에 영영 업데이트를 못 올리므로 따로 백업해 둔다.
//
// 파일이 없는 컴퓨터에서는 예전처럼 디버그 키로 떨어진다 —
// `flutter run --release` 가 거기서도 돌아야 하기 때문이다.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.hifis.hifis"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.hifis.hifis"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // key.properties 의 storeFile 은 이 모듈(android/app) 기준이다
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Play 는 디버그 키로 서명한 것을 안 받는다.
            // 키스토어가 없는 컴퓨터에서는 디버그 키로 떨어진다 (스토어에는 못 올린다)
            signingConfig = signingConfigs.getByName(
                if (hasKeystore) "release" else "debug",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
