import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. local.properties에서 키를 읽어오기 위한 로직 추가
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

android {
    namespace = "com.example.easy_care"
    // 권장에 따라 36 유지 (최신 SDK)
    compileSdk = 36 

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.easy_care"
        
        // Firestore 및 최신 라이브러리 호환성을 위해 유지
        minSdk = flutter.minSdkVersion 
        targetSdk = 36 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 2. AndroidManifest.xml에서 사용할 변수 등록 (v1.6 보안 규칙)
        // local.properties에 정의된 kakaoNativeAppKey를 매니페스트로 넘겨줍니다.
        val kakaoKey = localProperties.getProperty("kakaoNativeAppKey") ?: ""
        manifestPlaceholders["kakaoNativeAppKey"] = kakaoKey
    }

    buildTypes {
        release {
            // 프로젝트 완성 후에는 실제 릴리즈 키로 변경이 필요합니다.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}