import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "anini.aninitools"
    compileSdk = 36  // Required by proximity_sensor plugin
    ndkVersion = "28.2.13676358"  // Required by jni plugin, 16KB compliant

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Application ID matches the original Kotlin app for consistent branding
        applicationId = "anini.aninitools"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Load keystore properties for release signing
    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))

                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release signing configuration for Play Store uploads
            signingConfig = signingConfigs.getByName("release")
            // R8: removes unused Java/Kotlin code (~4.4 MB smaller APK).
            // Android-side crash traces are obfuscated in Crashlytics unless the
            // Crashlytics Gradle plugin uploads the mapping file. Dart traces are unaffected.
            // Keep rules for Firebase are in proguard-rules.pro.
            isMinifyEnabled = true
            // Off on purpose: the AGP 9 resource shrinker deletes Crashlytics' RequireBuildId
            // flag (found by name), and the app then crashes at launch. It only saved ~250 KB.
            isShrinkResources = false
        }
    }
}

// Replaces the removed android { kotlinOptions { jvmTarget } } (Kotlin 2.4 / AGP 9).
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
