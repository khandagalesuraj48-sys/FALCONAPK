// FALCON (si.sketchline.falcon). The release is signed with FALCON's permanent key (23-11-2026, his answer: kept like the ERP's –
// made once by the build and kept only in the private bucket "app-keys" of FALCON's Supabase; .github/workflows/build.yml gives it
// as FALCON_KEYSTORE_PATH and the passwords); without it the file is signed with the debug key – it installs, but a later file signed
// with another key does not update it. No key is ever in this repository.
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "si.sketchline.falcon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true   // (23-11-2026) ota_update asks for it – as the ERP app (rcl-mobile)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "si.sketchline.falcon"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val ks = System.getenv("FALCON_KEYSTORE_PATH")
    signingConfigs {
        if (ks != null && file(ks).exists()) {
            create("sketchline") {
                storeFile = file(ks)
                storePassword = System.getenv("FALCON_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("FALCON_KEY_ALIAS")
                keyPassword = System.getenv("FALCON_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (ks != null && file(ks).exists()) signingConfigs.getByName("sketchline") else signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")   // the same as the ERP app
    implementation("androidx.core:core:1.16.0")   // (23-11-2026) FileProvider – the update's file handed to Android's installer (UpdateKit.kt)
}
