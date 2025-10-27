#!/usr/bin/env bash
set -euo pipefail

APP_ID="${1:-com.example.min}"
APP_NAME="${2:-ComposeMin}"

# Tentukan nama folder proyek:
#  - arg ke-3 override
#  - else slug dari APP_NAME (kebab-case, alnum saja)
#  - else pakai segmen terakhir dari APP_ID
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

if [ "${3-}" != "" ]; then
  PRJ="$3"
else
  PRJ="$(slugify "$APP_NAME")"
  if [ -z "$PRJ" ]; then
    PRJ="$(printf '%s' "$APP_ID" | awk -F. '{print $NF}')"
  fi
fi

PKG_PATH="${APP_ID//./\/}"

unalias gradle 2>/dev/null || true

# Stop kalau folder sudah ada, biar nggak numpuk sampah
if [ -e "$PRJ" ]; then
  echo "[err] Folder '$PRJ' sudah ada. Jalankan lagi dengan nama lain (arg ke-3)."
  exit 1
fi

mkdir -p "$PRJ"
cd "$PRJ"

# settings.gradle.kts: pakai nama project dinamis
cat > settings.gradle.kts <<EOF
pluginManagement { repositories { google(); mavenCentral() } }
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories { google(); mavenCentral() }
}
rootProject.name = "$PRJ"
include(":app")
EOF


# 2) Root build.gradle.kts, sudah include Compose plugin untuk Kotlin 2.0
cat > build.gradle.kts <<'EOF'
plugins {
  id("com.android.application") version "8.7.2" apply false
  kotlin("android") version "2.0.20" apply false
  id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
EOF

# 3) gradle.properties
cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
EOF

# 4) Modul app, Compose aktif, tanpa composeOptions lawas
mkdir -p app
cat > app/build.gradle.kts <<EOF
plugins {
  id("com.android.application")
  kotlin("android")
  id("org.jetbrains.kotlin.plugin.compose")
}

android {
  namespace = "$APP_ID"
  compileSdk = 35

  defaultConfig {
    applicationId = "$APP_ID"
    minSdk = 24
    targetSdk = 35
    versionCode = 1
    versionName = "1.0"
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }

  buildTypes {
    debug { isMinifyEnabled = false }
    release {
      isMinifyEnabled = true
      proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro"
      )
    }
  }

  buildFeatures { compose = true }
  packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
  val bom = platform("androidx.compose:compose-bom:2024.10.01")
  implementation(bom)
  androidTestImplementation(bom)

  implementation("androidx.activity:activity-compose:1.9.3")
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.ui:ui-tooling-preview")
  implementation("androidx.compose.material3:material3:1.3.0")
  debugImplementation("androidx.compose.ui:ui-tooling")

  testImplementation("junit:junit:4.13.2")
  androidTestImplementation("androidx.test.ext:junit:1.2.1")
  androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
  androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
EOF

# 5) Manifest minimal valid, TANPA attribute package=
mkdir -p app/src/main
cat > app/src/main/AndroidManifest.xml <<EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application
    android:label="$APP_NAME"
    android:icon="@mipmap/ic_launcher">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF

# 6) Resource minimal untuk @mipmap/ic_launcher
mkdir -p app/src/main/res/mipmap-anydpi-v26 \
         app/src/main/res/drawable \
         app/src/main/res/values

cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

cat > app/src/main/res/values/colors.xml <<'EOF'
<resources>
  <color name="ic_launcher_background">#121212</color>
</resources>
EOF

cat > app/src/main/res/drawable/ic_launcher_foreground.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
  android:width="108dp"
  android:height="108dp"
  android:viewportWidth="108"
  android:viewportHeight="108">
  <group
    android:scaleX="0.9"
    android:scaleY="0.9"
    android:translateX="5.4"
    android:translateY="5.4">
    <path
      android:fillColor="#FFFFFF"
      android:pathData="M54,18 L66,54 L54,90 L42,54 z"/>
  </group>
</vector>
EOF

# 7) strings.xml minimal
mkdir -p app/src/main/res/values
cat > app/src/main/res/values/strings.xml <<EOF
<resources>
  <string name="app_name">$APP_NAME</string>
</resources>
EOF

# 8) MainActivity
mkdir -p "app/src/main/java/$PKG_PATH"
cat > "app/src/main/java/$PKG_PATH/MainActivity.kt" <<EOF
package $APP_ID

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContent { App() }
  }
}

@Composable
fun App() {
  MaterialTheme { Text("Hello $APP_NAME") }
}
EOF

# 9) .gitignore
cat > .gitignore <<'EOF'
/.gradle
/local.properties
/build
/.idea
/app/build
.cxx
*.iml
.DS_Store
EOF

# 10) Gradle wrapper: lokal atau Docker
if command -v gradle >/dev/null 2>&1; then
  gradle wrapper --gradle-version 8.10.2 --distribution-type=bin --no-daemon
elif command -v docker >/dev/null 2>&1; then
  echo "[info] gradle tidak ada; pakai container untuk generate wrapper"
  docker run --rm -u "$(id -u)":"$(id -g)" \
    -v "$PWD":/home/gradle/project -w /home/gradle/project \
    gradle:8.10.2 gradle wrapper --gradle-version 8.10.2 --distribution-type=bin --no-daemon
else
  echo "[err] gradle tidak ditemukan dan docker tidak ada. Install gradle (SDKMAN disarankan)."
  exit 1
fi

chmod +x gradlew

printf '%s\n' \
  "" \
  "Bootstrap kelar." \
  "  ./gradlew assembleDebug" \
  "  ./gradlew installDebug && adb shell am start -n $APP_ID/.MainActivity"

