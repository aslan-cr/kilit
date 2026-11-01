plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    // Kaynak kodu kilit uygulamasıyla ortak (../app); R sınıfı için namespace aynı.
    namespace = "com.beranmeva.kilit"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.beranmeva.kullanimizle"
        minSdk = 26
        targetSdk = 34
        versionCode = 2
        versionName = "2.0"
        manifestPlaceholders["appLabel"] = "Kullanım İzle"
    }

    // Kilit ve Güncelleyici ile aynı sabit imza (yeni sürüm eskisinin üstüne kurulur).
    signingConfigs {
        getByName("debug") {
            storeFile = file("../app/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDir("../app/src/main/java")
            manifest.srcFile("../app/src/main/AndroidManifest.xml")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}
