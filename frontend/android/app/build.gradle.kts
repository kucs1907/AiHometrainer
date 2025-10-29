// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // Flutter 플러그인은 반드시 가장 마지막에 선언
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aihometrainer"
    compileSdk = 35

    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.aihometrainer"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // ✅ Java 21로 맞춤
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    // ✅ Kotlin도 21로
    kotlinOptions {
        jvmTarget = "21"
    }
    // (선택) toolchain 명시 – 로컬에 21 없으면 자동 해결
    kotlin {
        jvmToolchain(21)
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
