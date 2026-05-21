#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔨 Building Android Client..."
cd "$ROOT_DIR/AndroidClient"

# Set JAVA_HOME, trying common locations
if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
elif [ -d "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
elif [ -d "/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

# Check if Java is available
if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    echo "❌ Java not found. Please install Android Studio or openjdk@17."
    exit 1
fi

./gradlew assembleDebug

echo ""
echo "✅ Build successful!"
echo ""
echo "📦 APK: $ROOT_DIR/AndroidClient/app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "To install on device:"
echo "  adb install -r $ROOT_DIR/AndroidClient/app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "Or run: ./scripts/install_android.sh"
