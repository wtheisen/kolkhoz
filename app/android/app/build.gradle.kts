plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = project.findProperty("KOLKHOZ_ANDROID_KEYSTORE_PATH") as String?
val releaseKeystorePassword = project.findProperty("KOLKHOZ_ANDROID_KEYSTORE_PASSWORD") as String?
val releaseKeyAlias = project.findProperty("KOLKHOZ_ANDROID_KEY_ALIAS") as String?
val releaseKeyPassword = project.findProperty("KOLKHOZ_ANDROID_KEY_PASSWORD") as String?

android {
    namespace = "com.williamtheisen.kolkhoz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.williamtheisen.kolkhoz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField(
            "String",
            "PLAY_GAMES_SERVER_CLIENT_ID",
            "\"${project.findProperty("KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_ID") ?: ""}\"",
        )
    }

    signingConfigs {
        create("release") {
            if (releaseKeystorePath != null) {
                storeFile = file(releaseKeystorePath)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
                require(
                    listOf(
                        releaseKeystorePath,
                        releaseKeystorePassword,
                        releaseKeyAlias,
                        releaseKeyPassword,
                    ).all { !it.isNullOrBlank() }
                ) { "Android release signing properties are required; refusing a debug-signed release." }
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-games-v2:21.0.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
