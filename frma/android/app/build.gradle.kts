import java.util.Properties

// Top-level plugin declarations
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Function to read local properties safely
fun getLocalProperty(key: String, project: Project): String? {
    val localProperties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { reader ->
            localProperties.load(reader)
        }
    }
    return localProperties.getProperty(key)
}

// Read Flutter version info from local.properties or defaults
val flutterVersionCode: String = getLocalProperty("flutter.versionCode", project) ?: "1"
val flutterVersionName: String = getLocalProperty("flutter.versionName", project) ?: "1.0"

// Android specific configurations
android {
    namespace = "com.example.frma" // Make sure this matches your actual namespace
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.frma" // Ensure this is your unique ID
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        getByName("debug") {
            // Default debug signing config
        }
        // create("release") { ... add your release config here ... }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug") // Change for release
            // isMinifyEnabled = true
            // isShrinkResources = true
            // setProguardFiles(listOf(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"))
        }
    }

    ndkVersion = "27.0.12077973" // Or flutter.ndkVersion if defined
}

// Flutter specific configurations
flutter {
    source = "../.."
}

// Dependencies for the Android app module
dependencies {
    implementation(kotlin("stdlib-jdk7"))

    // --- UPDATE THIS LINE ---
    // Dependency for core library desugaring (Updated version)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // Use version 2.1.4 or higher

    // Add other dependencies if needed
}