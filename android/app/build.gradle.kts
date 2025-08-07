plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter 플러그인은 반드시 가장 마지막에 선언되어야 합니다
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aihometrainer"
    compileSdk = 35 // 혹은 33, 본인 flutter SDK에 맞게

    ndkVersion = "27.0.12077973"



    defaultConfig {
        applicationId = "com.example.aihometrainer"
        minSdk = 23 // Flutter 기본 최소 SDK
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true

    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.kakao.sdk:v2-user:2.21.5") // Java용 Kakao SDK 의존성

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
