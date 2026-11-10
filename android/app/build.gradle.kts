import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key settings; empty when the file is missing (e.g. CI, a fresh clone).
val keyProperties: Properties =
    Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
        // Properties keeps trailing spaces, which would make a right password fail.
        stringPropertyNames().forEach { setProperty(it, getProperty(it).trim()) }
    }
// Keys that are absent or blank. Any entry stops a store release (below), but never a sideload build.
val missingKeyProperties: List<String> =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").filter {
        keyProperties.getProperty(it).isNullOrBlank()
    }

android {
    namespace = "com.pawlypaint.pawlypaint"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pawlypaint.pawlypaint"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Google Play's floor for new apps and updates; max() keeps a Flutter downgrade from lowering it.
        targetSdk = maxOf(flutter.targetSdkVersion, 36)
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // `sideload` is her current app and keeps its id so it keeps updating.
    // `store` is the Google Play build: its own id, so both install side by
    // side, and no fan art or private course (the Dart side reads the flavor).
    //
    // Signing: `sideload` keeps the Mac's debug key (her phone only accepts
    // updates signed by it). `store` signs with the upload key from the
    // git-ignored android/key.properties (docs/RUNBOOK.md, "Upload key").
    signingConfigs {
        if (missingKeyProperties.isEmpty()) {
            create("upload") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    flavorDimensions += "dist"
    productFlavors {
        create("sideload") {
            dimension = "dist"
            signingConfig = signingConfigs.getByName("debug")
        }
        create("store") {
            dimension = "dist"
            applicationId = "com.cjtech.pawlypaint"
            signingConfig = signingConfigs.findByName("upload")
        }
    }

    buildTypes {
        release {
            // No signingConfig here: a build type's would override the flavor's.
            // R8 strips methods the shared_preferences plugin calls through JNI,
            // which hangs the app on its splash screen; this app is small anyway.
            isMinifyEnabled = false
            isShrinkResources = false
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

// A store release without the upload key would ship unsigned; stop it before it is packaged.
if (missingKeyProperties.isNotEmpty()) {
    val missing = missingKeyProperties.joinToString()
    tasks.configureEach {
        if (name.contains("StoreRelease", ignoreCase = true) &&
            (name.startsWith("assemble") || name.startsWith("bundle") || name.startsWith("package") ||
                name.startsWith("sign"))
        ) {
            doFirst {
                throw GradleException(
                    "Store release needs android/key.properties with: $missing. " +
                        "See docs/RUNBOOK.md, \"Upload key\"."
                )
            }
        }
    }
}
