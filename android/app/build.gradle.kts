plugins {
    id("com.android.application")
}

android {
    namespace = "com.mygame.deathvacation"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.mygame.deathvacation"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // Постоянный отладочный ключ (стандартный пароль «android»): все сборки
    // подписаны одинаково, и новая версия ставится поверх старой с сохранениями.
    // Ключ публичный — для Google Play нужен свой, секретный.
    signingConfigs {
        getByName("debug") {
            storeFile = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Для установки «из файла» релиз подписывается отладочным ключом.
            // Для публикации в Google Play замените на собственный ключ.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Сама игра — это папка game/ в корне репозитория: она целиком
    // кладётся в assets и открывается во встроенном WebView.
    sourceSets {
        getByName("main") {
            assets.srcDir("../../game")
        }
    }
}

dependencies {
    implementation("androidx.webkit:webkit:1.12.1")
}
