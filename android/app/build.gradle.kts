import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================
// 🔹 Helper Function: Read local.properties
// ============================
fun getLocalProperty(key: String, project: org.gradle.api.Project): String {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")

    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.inputStream())
    }

    return properties.getProperty(key, "") // Returns empty string if the key is missing
}

// ============================
// 🚀 Flutter Version Details
// ============================
val flutterVersionCode: Int = getLocalProperty("flutter.versionCode", project).toIntOrNull() ?: 1
val flutterVersionName: String = getLocalProperty("flutter.versionName", project).ifEmpty { "1.0" }

android {
    compileSdk = 35
    namespace = "com.example.tasknova_flutter"
    ndkVersion = "27.0.12077973"  // ⚡ Keep your required NDK version

    defaultConfig {
        applicationId = "com.example.tasknova_flutter"
        minSdk = 23  // 🔹 Updated minimum SDK based on Flutter 3.29.2 recommendations
        targetSdk = 34  // 🔹 Updated target SDK version
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17  // 🔹 Aligning with Flutter's recommended Java version
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"  // 🔹 Updated to match Java 17 for improved performance
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }
}

// ============================
// 🔹 Flutter SDK Configuration
// ============================
flutter {
    source = "../.."
}

// ============================
// 📦 Dependencies
// ============================
dependencies {
    implementation(kotlin("stdlib"))
    implementation("androidx.core:core-ktx:1.12.0")  // 🔹 Updated to latest androidx.core
    implementation("androidx.appcompat:appcompat:1.6.1")  // 🔹 Updated AppCompat
    implementation("androidx.activity:activity-ktx:1.8.0")  // 🔹 Latest Activity KTX
}
