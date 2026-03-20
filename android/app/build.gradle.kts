plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.coonch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.coonch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        compose = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    implementation("com.google.android.material:material:1.12.0")
    // Compose BOM – provides consistent Compose versions required by Stripe PaymentSheet
    implementation(platform("androidx.compose:compose-bom:2025.01.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-android")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-graphics-android")
    implementation("androidx.compose.ui:ui-text")
    implementation("androidx.compose.ui:ui-text-android")
    implementation("androidx.compose.ui:ui-unit")
    implementation("androidx.compose.ui:ui-unit-android")
    implementation("androidx.compose.ui:ui-util")
    implementation("androidx.compose.ui:ui-util-android")
    implementation("androidx.compose.ui:ui-geometry")
    implementation("androidx.compose.ui:ui-geometry-android")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.ui:ui-tooling-preview-android")
    implementation("androidx.compose.ui:ui-viewbinding")
    implementation("androidx.compose.material:material")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.activity:activity-compose")
}

flutter {
    source = "../.."
}
