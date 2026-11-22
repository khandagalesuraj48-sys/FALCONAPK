// FALCON (si.sketchline.falcon). The release is signed with Sketchline's own key when the build is given it (GitHub secrets →
// FALCON_KEYSTORE_PATH and the passwords, in .github/workflows/build.yml); without it the file is signed with the debug key – it
// installs, but a later file signed with another key does not update it. No key is ever in this repository.
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
