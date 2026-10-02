#!/bin/bash
set -euo pipefail

# Splash Monitor — construcción del bundle .app
# La versión, el identificador de paquete y el número de compilación se leen de
# Sources/SplashMonitor/Services/Version.swift: única fuente de verdad (P-15).

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

VERSION_SWIFT="$DIR/Sources/SplashMonitor/Services/Version.swift"
if [ ! -f "$VERSION_SWIFT" ]; then
    echo "❌ No se encontró $VERSION_SWIFT" >&2
    exit 1
fi

APP_VERSION="$(sed -n 's/.*static let current = "\([^"]*\)".*/\1/p' "$VERSION_SWIFT" | head -1)"
BUNDLE_ID="$(sed -n 's/.*static let bundleIdentifier = "\([^"]*\)".*/\1/p' "$VERSION_SWIFT" | head -1)"
BUILD_NUMBER="$(sed -n 's/.*static let buildNumber = "\([^"]*\)".*/\1/p' "$VERSION_SWIFT" | head -1)"

if [ -z "$APP_VERSION" ] || [ -z "$BUNDLE_ID" ] || [ -z "$BUILD_NUMBER" ]; then
    echo "❌ No se pudieron extraer versión/identificador/compilación de Version.swift" >&2
    exit 1
fi

echo "🔨 Compilando SplashMonitor $APP_VERSION ($BUNDLE_ID) en modo Release..."
swift build -c release

APP_NAME="Splash Monitor"
BUILD_DIR="$DIR/.build/release"
APP_DIR="$DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creando bundle de macOS: $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copiar recursos
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    echo "🎨 Copiando icono de la aplicación (AppIcon.icns)..."
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Copiar binario
cp "$BUILD_DIR/SplashMonitor" "$MACOS_DIR/SplashMonitor"
chmod +x "$MACOS_DIR/SplashMonitor"

# Generar Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>es</string>
        <string>en</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>SplashMonitor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Splash Monitor utiliza Terminal para ejecutar el motor de inferencia local Splash y conectar agentes de código.</string>
</dict>
</plist>
EOF

# Firma ad-hoc. Se firma primero el binario y después el bundle, sin `--deep`:
# `--deep` está obsoleto y oculta problemas de firma en lugar de resolverlos (P-18).
# La firma ad-hoc NO acredita al autor: sirve para que macOS acepte el bundle.
echo "✍️  Firmando binario y bundle (firma ad-hoc, sin --deep)..."
codesign --force --sign - "$MACOS_DIR/SplashMonitor"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

echo "✅ App compilada con éxito en: $APP_DIR"
echo "🚀 Puedes iniciarla ejecutando: open '$APP_DIR'"
