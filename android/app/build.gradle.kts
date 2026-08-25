import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

extensions.configure<ApplicationExtension>("android") {
    namespace = "com.devsheep.snap_fit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.devsheep.snap_fit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] = "34ecdf62d2b450c00c1d525d0cffa4df"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

tasks.withType<JavaCompile>().configureEach {
    val variantName = name.removePrefix("compile").removeSuffix("JavaWithJavac")
    val variantDir = variantName.replaceFirstChar { it.lowercase() }

    val firebaseStorageKotlinClasses = files(
        rootProject.layout.buildDirectory.dir("firebase_storage/tmp/kotlin-classes/$variantDir"),
    )

    classpath = (classpath ?: files()) + firebaseStorageKotlinClasses
    dependsOn(":firebase_storage:compile${variantName}Kotlin")
}
