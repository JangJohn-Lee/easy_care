import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. 로컬 보안키 설정 (카카오 로그인 등)
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

android {
    namespace = "com.example.easy_care"
    compileSdk = 36 

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.easy_care"
        minSdk = flutter.minSdkVersion 
        targetSdk = 36 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 카카오 네이티브 키 설정 (RULES.md 보안 규칙 준수) [cite: 3, 4]
        val kakaoKey = localProperties.getProperty("kakaoNativeAppKey") ?: ""
        manifestPlaceholders["kakaoNativeAppKey"] = kakaoKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// --- 이 부분이 추가된 핵심 내용입니다 ---
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // 한국어 OCR 인식 모델 엔진 (v1.6 필수 사항) 
    implementation("com.google.mlkit:text-recognition-korean:16.0.0")
}