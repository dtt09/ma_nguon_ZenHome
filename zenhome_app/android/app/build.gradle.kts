import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.example.zenhome_app"
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.zenhome_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    }

    signingConfigs {
        create("release") {
            val keyPath = System.getenv("ANDROID_RELEASE_STORE_FILE") ?: keystoreProperties.getProperty("storeFile")
            val resolvedFile = when {
                keyPath.isNullOrEmpty() -> null
                file(keyPath).exists() -> file(keyPath)
                rootProject.file(keyPath).exists() -> rootProject.file(keyPath)
                file("app/$keyPath").exists() -> file("app/$keyPath")
                else -> null
            }
            if (resolvedFile != null && resolvedFile.exists()) {
                keyAlias = System.getenv("ANDROID_RELEASE_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
                keyPassword = System.getenv("ANDROID_RELEASE_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")
                storeFile = resolvedFile
                storePassword = System.getenv("ANDROID_RELEASE_STORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = releaseConfig
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

tasks.matching { it.name.contains("NativeSymbolTables") }.configureEach {
    enabled = false
}

tasks.matching { it.name.contains("uploadCrashlyticsMappingFile") }.configureEach {
    enabled = false
}

tasks.matching { it.name.startsWith("cleanMerge") }.configureEach {
    enabled = false
}
