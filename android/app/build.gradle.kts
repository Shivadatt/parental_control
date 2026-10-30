import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is opt-in: android/key.properties is gitignored and never
// committed. When it is absent (or incomplete) the release build keeps the
// debug keystore so `flutter run --release` and local builds still work.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreFile = keystorePropertiesFile.exists()
if (hasKeystoreFile) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val signingPropertyNames = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningProperties =
    signingPropertyNames.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val hasReleaseSigning = hasKeystoreFile && missingSigningProperties.isEmpty()

if (!hasReleaseSigning) {
    val reason = if (hasKeystoreFile) {
        "android/key.properties is missing ${missingSigningProperties.joinToString(", ")}. "
    } else {
        "android/key.properties not found (copy android/key.properties.example). "
    }
    logger.warn(
        "WARNING: release build signed with DEBUG key - not shippable. $reason"
    )
}

android {
    namespace = "com.parentcontrol.parent_control"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.parentcontrol.parent_control"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Real keystore when android/key.properties exists; otherwise the
            // debug key keeps local release runs possible (not shippable).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.security:security-crypto:1.1.0")
    implementation("androidx.core:core-ktx:1.17.0")
    testImplementation("junit:junit:4.13.2")
}
