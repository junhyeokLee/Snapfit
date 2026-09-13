import java.util.Properties
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// The upload key is supplied locally and is never included in source control.
val releaseSigningFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningFile.isFile) {
        releaseSigningFile.inputStream().use { load(it) }
    }
}
fun signingProperty(name: String): String {
    val value = releaseSigningProperties.getProperty(name)
    require(!value.isNullOrEmpty()) { "Missing $name in android/key.properties" }
    return value
}

android {
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

    signingConfigs {
        if (releaseSigningFile.isFile) {
            create("release") {
                storeFile = rootProject.file(signingProperty("storeFile"))
                storePassword = signingProperty("storePassword")
                keyAlias = signingProperty("keyAlias")
                keyPassword = signingProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without an upload key, local release compilation produces an unsigned artifact.
            signingConfig = if (releaseSigningFile.isFile) signingConfigs.getByName("release") else null
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
