import java.util.Properties

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

/*
 * Repository structure:
 *
 * repository/
 *   .github/scripts/
 *   android/
 *     android/app/build.gradle.kts
 */

val repositoryRoot = rootProject.projectDir
    .parentFile
    .parentFile

val espeakSourceScript = repositoryRoot.resolve(
    ".github/scripts/prepare-espeak.sh"
)

val espeakDataScript = repositoryRoot.resolve(
    ".github/scripts/prepare-espeak-data.sh"
)

/**
 * Download the pinned eSpeak NG source before CMake
 * attempts to configure the Android native targets.
 */
val prepareEspeakSource = tasks.register<Exec>(
    "prepareEspeakSource"
) {
    group = "otakudub"
    description = "Prepare the eSpeak NG native dependency"

    workingDir = repositoryRoot

    doFirst {
        check(espeakSourceScript.isFile) {
            "Missing script: ${espeakSourceScript.path}"
        }
    }

    commandLine(
        "bash",
        espeakSourceScript.absolutePath
    )
}

/**
 * Compile eSpeak language data on the Linux build host.
 *
 * The resulting assets are packaged into the APK and
 * installed into private storage by EspeakDataInstaller.
 */
val prepareEspeakData = tasks.register<Exec>(
    "prepareEspeakData"
) {
    group = "otakudub"
    description = "Compile offline eSpeak NG language data"

    dependsOn(prepareEspeakSource)

    workingDir = repositoryRoot

    doFirst {
        check(espeakDataScript.isFile) {
            "Missing script: ${espeakDataScript.path}"
        }
    }

    commandLine(
        "bash",
        espeakDataScript.absolutePath
    )
}

val releaseSigning = Properties()
val releaseSigningFile = rootProject.file("signing.properties")
if (releaseSigningFile.isFile) {
    releaseSigningFile.inputStream().use { releaseSigning.load(it) }
}

android {
    namespace = "co.parikshit.otakudub"

    compileSdk = 36

    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "co.parikshit.otakudub.release"

        minSdk = 26

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }

        externalNativeBuild {
            cmake {
                cppFlags.add("-std=c++17")
                abiFilters.add("arm64-v8a")
                // Build only JNI libraries; upstream eSpeak ALL targets run an
                // ARM64 executable to generate data and cannot run on Linux.
                targets.add("otakudub_native")
                targets.add("otakudub_phonemizer")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("otakudubRelease") {
            if (releaseSigningFile.isFile) {
                storeFile = rootProject.file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // ONNX Runtime JNI looks up tensor wrapper classes by name.
            // Keep shrinking disabled while diagnosing the release-only JNI abort.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("otakudubRelease")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(
        "com.microsoft.onnxruntime:onnxruntime-android:1.20.0"
    )
    testImplementation("junit:junit:4.13.2")
}

/*
 * Dependency preparation must finish before native
 * configuration or Android asset processing begins.
 */
tasks.configureEach {
    if (
        name == "preBuild" ||
        name.startsWith("configureCMake") ||
        name.startsWith("generateJsonModel") ||
        name.startsWith("merge") &&
        name.endsWith("Assets")
    ) {
        dependsOn(prepareEspeakData)
    }
}

flutter {
    source = "../.."
}
