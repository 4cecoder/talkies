import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val talkiesSigningStore = providers.environmentVariable("TALKIES_ANDROID_KEYSTORE_PATH").orNull

android {
    namespace = "com.talkies.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.talkies.android"
        // Fire OS 7 tablets are based on Android 9 (API 28); Fire OS 8 is API 30.
        minSdk = 28
        targetSdk = 35
        versionCode = providers.gradleProperty("talkiesVersionCode").orElse("2").get().toInt()
        versionName = providers.gradleProperty("talkiesVersionName").orElse("0.1.5").get()
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }

    if (talkiesSigningStore != null) {
        signingConfigs {
            create("talkiesRelease") {
                storeFile = file(talkiesSigningStore)
                storePassword = providers.environmentVariable("TALKIES_ANDROID_KEYSTORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("TALKIES_ANDROID_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("TALKIES_ANDROID_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (talkiesSigningStore != null) {
                signingConfig = signingConfigs.getByName("talkiesRelease")
            }
        }
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    implementation(project(":core"))
    implementation(project(":inference"))
    // Pure-Java SSH transport; passwords remain in memory for the lifetime of a connection.
    implementation("com.github.mwiede:jsch:2.27.7")
    implementation("org.bouncycastle:bcprov-jdk18on:1.86")
    implementation("org.connectbot:termlib:0.0.9")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    val composeBom = platform("androidx.compose:compose-bom:2025.10.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
