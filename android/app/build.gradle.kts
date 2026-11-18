import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase must initialize natively when Android starts the process for a push.
val firebaseConfigFile = file("google-services.json")
if (firebaseConfigFile.isFile) {
    apply(plugin = "com.google.gms.google-services")
}

apply(from = rootProject.file("validate-client-config.gradle"))
apply(from = rootProject.file("validate-release-obfuscation.gradle"))

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.isFile) { keyPropertiesFile.inputStream().use { keyProperties.load(it) } }
val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningProperties = requiredSigningProperties.filter { keyProperties.getProperty(it).isNullOrBlank() }
val hasSigningProperties = keyPropertiesFile.isFile && missingSigningProperties.isEmpty()

// Never produce an unsigned artifact for distribution. Debug builds do not
// require a release keystore.
fun requireReleaseConfiguration() {
    val validateObfuscation = extra["validateDartObfuscation"] as groovy.lang.Closure<*>
    validateObfuscation.call(
        project.findProperty("dart-obfuscation")?.toString().orEmpty(),
        project.findProperty("split-debug-info")?.toString().orEmpty()
    )
    // The admin entrypoint connects interactively; the user entrypoint requires
    // compile-time project values. Preserve the admin's existing setup flow.
    val entrypoint = file(project.findProperty("target")?.toString() ?: "../../lib/main.dart")
    if (entrypoint.canonicalFile != rootProject.file("../lib/admin_main.dart").canonicalFile) {
        val validate = extra["validateSupabaseDartDefines"] as groovy.lang.Closure<*>
        validate.call(project.findProperty("dart-defines")?.toString().orEmpty())
    }

    if (!firebaseConfigFile.isFile) {
        throw GradleException("Firebase configuration is required for release push notifications. Register space.freelan.app in Firebase and download android/app/google-services.json; see docs/USER_FEATURES.md.")
    }
    if (!keyPropertiesFile.isFile) {
        throw GradleException("Release signing is required. Configure android/key.properties and a release keystore; see README.md.")
    }
    if (missingSigningProperties.isNotEmpty()) {
        throw GradleException("Release signing configuration is incomplete: ${missingSigningProperties.joinToString()}. See README.md.")
    }
    if (!file(keyProperties.getProperty("storeFile")).isFile) {
        throw GradleException("Release keystore file does not exist. Check storeFile in android/key.properties.")
    }
}
val releasePackagingTasks = setOf("packageRelease", "packageReleaseBundle", "signReleaseBundle")
// Check the entire task graph so aggregate tasks such as `build` cannot bypass
// the check, and fail before compiling a release that cannot be distributed.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name in releasePackagingTasks }) {
        requireReleaseConfiguration()
    }
}

android {
    namespace = "space.freelan.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "space.freelan.app"
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
        if (hasSigningProperties) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            // Match Flutter's shrink flag, including its --no-shrink override.
            // Flutter supplies the optimized Android and Flutter R8 rules.
            val shrink = project.findProperty("shrink")?.toString()?.toBoolean() ?: true
            isMinifyEnabled = shrink
            isShrinkResources = shrink
            if (hasSigningProperties) signingConfig = signingConfigs.getByName("release")
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
