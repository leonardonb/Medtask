plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.medtask"
    compileSdk = 34

    // >>> Corrige a versão do NDK conforme pedido pelos plugins
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // >>> Habilita desugaring para libs Java 8+
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.medtask"
        minSdk = 29
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // (Opcional) Mantém o bloco de packaging se desejar.
    // packaging {
    //     resources {
    //         excludes += setOf(
    //             "META-INF/LICENSE*",
    //             "META-INF/NOTICE*",
    //             "META-INF/AL2.0",
    //             "META-INF/LGPL2.1"
    //         )
    //     }
    // }
}

flutter {
    source = "../.."
}

dependencies {
    // >>> Dependência necessária quando coreLibraryDesugaring está habilitado
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
