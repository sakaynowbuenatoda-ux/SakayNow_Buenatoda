import java.io.File

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun readEnvValue(key: String): String {
    val candidates = listOf(
        file("../../.env"),
        file("../../../.env"),
        rootProject.file("../.env"),
        rootProject.file("../../.env")
    )

    val fromFile = candidates
        .asSequence()
        .filter { it.exists() }
        .mapNotNull { envFile ->
            envFile.readLines().firstOrNull { line ->
                val trimmedLine = line.trim()
                trimmedLine.startsWith("$key=") && !trimmedLine.startsWith("#")
            }?.substringAfter("=")?.trim()
        }
        .firstOrNull()
        ?.removeSurrounding("\"")
        ?.removeSurrounding("'")

    return providers.gradleProperty(key).orNull
        ?: System.getenv(key)
        ?: fromFile
        ?: ""
}

android {
    namespace = "com.example.sakaynow_buenatoda"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.0.13004108"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.sakaynow_buenatoda"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleServicesApiKey"] = readEnvValue("GOOGLE_SERVICES_API_KEY")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
