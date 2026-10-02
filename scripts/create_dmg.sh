#!/bin/bash
set -euo pipefail

# Splash Monitor — creación del DMG de distribución.
# La versión se lee de Sources/SplashMonitor/Services/Version.swift (P-15) y el
# resultado incluye SHA256SUMS para que el instalador pueda verificar la descarga (P-18).

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

VERSION_SWIFT="$DIR/Sources/SplashMonitor/Services/Version.swift"
APP_VERSION="$(sed -n 's/.*static let current = "\([^"]*\)".*/\1/p' "$VERSION_SWIFT" | head -1)"
if [ -z "$APP_VERSION" ]; then
    echo "❌ No se pudo extraer la versión de $VERSION_SWIFT" >&2
    exit 1
fi

APP_NAME="Splash Monitor"
APP_DIR="$DIR/$APP_NAME.app"
DMG_NAME="SplashMonitor-${APP_VERSION}.dmg"
DMG_OUTPUT="$DIR/$DMG_NAME"
CHECKSUM_OUTPUT="$DIR/SHA256SUMS"
TEMP_DMG_DIR="$DIR/.dmg_temp"

# La app debe estar compilada con la misma versión que el DMG.
if [ ! -d "$APP_DIR" ]; then
    echo "🔨 La app no está compilada. Compilando primero..."
    "$DIR/scripts/build_app.sh"
fi

BUNDLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo "")"
if [ "$BUNDLED_VERSION" != "$APP_VERSION" ]; then
    echo "⚠️  El bundle contiene la versión '$BUNDLED_VERSION' y Version.swift declara '$APP_VERSION'."
    echo "    Recompilando para evitar un DMG con versión incorrecta (defecto de 1.0.2-beta)..."
    "$DIR/scripts/build_app.sh"
fi

echo "📦 Creando instalador DMG para macOS ($DMG_NAME)..."
rm -rf "$TEMP_DMG_DIR" "$DMG_OUTPUT"
mkdir -p "$TEMP_DMG_DIR"

# Copiar la aplicación al directorio temporal del DMG
cp -R "$APP_DIR" "$TEMP_DMG_DIR/"

# Crear acceso directo simbólico a /Applications
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Si existe el icono, asignarlo como icono del volumen
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$TEMP_DMG_DIR/.VolumeIcon.icns"
fi

# Limpiar atributos extendidos y firmar la app dentro del DMG (sin --deep, P-18)
echo "✍️  Firmando la app dentro del directorio temporal del DMG..."
xattr -cr "$TEMP_DMG_DIR"
codesign --force --sign - "$TEMP_DMG_DIR/$APP_NAME.app/Contents/MacOS/SplashMonitor"
codesign --force --sign - "$TEMP_DMG_DIR/$APP_NAME.app"
codesign --verify --strict --verbose=2 "$TEMP_DMG_DIR/$APP_NAME.app"

# Generar el archivo DMG comprimido UDZO
echo "💿 Empaquetando imagen de disco con hdiutil..."
hdiutil create -volname "Splash Monitor" \
               -srcfolder "$TEMP_DMG_DIR" \
               -ov \
               -format UDZO \
               "$DMG_OUTPUT"

# Limpiar directorio temporal
rm -rf "$TEMP_DMG_DIR"

# Firmar el archivo DMG resultante
echo "✍️  Firmando el archivo DMG..."
codesign --force --sign - "$DMG_OUTPUT"

# Suma de verificación publicable junto al DMG (P-18)
echo "🔐 Calculando suma SHA-256..."
( cd "$DIR" && shasum -a 256 "$DMG_NAME" > "$CHECKSUM_OUTPUT" )

echo "✅ DMG creado con éxito en: $DMG_OUTPUT"
ls -lh "$DMG_OUTPUT"
echo "✅ Suma de verificación en: $CHECKSUM_OUTPUT"
cat "$CHECKSUM_OUTPUT"
