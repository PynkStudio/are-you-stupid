import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// Bumps pubspec.yaml's build number before a release build reads it into
// versionCode/versionName below — the Xcode-archive equivalent for Android.
// Must run before `android { defaultConfig { ... } }` is evaluated, since
// `flutter.versionCode`/`versionName` are read at configuration time.
val releaseBuildTasks = setOf("assembleRelease", "bundleRelease")
val isReleaseBuild = gradle.startParameter.taskNames.any { taskName ->
    releaseBuildTasks.any { taskName == it || taskName.endsWith(":$it") }
}
if (isReleaseBuild) {
    // Plain `ProcessBuilder` instead of Gradle's `Project.exec {}` — the
    // latter was removed in Gradle 9 (this project runs 9.3.1/AGP 9.1.0),
    // which broke every Android build, debug included, since a Kotlin
    // build script fails to *compile* on an unresolved `exec` reference
    // regardless of whether `isReleaseBuild` is true at run time. A plain
    // JVM API has no Gradle-version surface to break against. See
    // docs/Meta/Decision Log.md.
    ProcessBuilder("bash", "${rootProject.projectDir}/../scripts/bump_build_number.sh")
        .inheritIO()
        .start()
        .waitFor()
}

android {
    namespace = "com.ays.are_you_stupid"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ays.are_you_stupid"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing when key.properties is absent (e.g. CI
            // checkouts without the upload keystore) so `flutter run --release`
            // still works; a real release build needs android/key.properties.
            signingConfig = if (keystorePropertiesFile.exists()) {
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
