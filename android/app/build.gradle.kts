plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.med_remind_app"
    // Literal, not flutter.compileSdkVersion: flutter_local_notifications
    // 22.3.0 requires compileSdk 36 and the Gradle default is not
    // guaranteed to match it.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications 22.3.0. Its README states
        // desugaring is needed "even if they don't use scheduled
        // notifications", so this is not optional for us and not deferrable to
        // Epic 3 -- without it the Android build breaks the first time the
        // plugin is exercised.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.med_remind_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Literal, not flutter.minSdkVersion: flutter_local_notifications
        // 22.3.0 requires API 24.
        minSdk = 24
        // Literal, and pinned to compileSdk. Left as
        // flutter.targetSdkVersion, a Flutter upgrade could raise targetSdk
        // above the compileSdk pinned above, which fails the Gradle build.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Backport of the java.time APIs flutter_local_notifications 22.3.0 needs
    // on API 24. 2.1.5 is the current release on Google's Maven repo
    // (verified 2026-09-04); the plugin README's example still says 2.1.4.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
