#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

APP_NAME="Splash Monitor"
APP_DIR="$DIR/$APP_NAME.app"
VERSION="1.0.2-beta"
DMG_NAME="SplashMonitor-${VERSION}.dmg"
DMG_OUTPUT="$DIR/$DMG_NAME"
TEMP_DMG_DIR="$DIR/.dmg_temp"

# Asegurar que la app esté compilada
if [ ! -d "$APP_DIR" ]; then
    echo "🔨 La app no está compilada. Compilando primero..."
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

# Limpiar atributos extendidos y firmar la app dentro del DMG
echo "✍️  Firmando la app dentro del directorio temporal del DMG..."
xattr -cr "$TEMP_DMG_DIR"
codesign --force --deep --sign - "$TEMP_DMG_DIR/$APP_NAME.app"

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

echo "✅ DMG creado con éxito en: $DMG_OUTPUT"
ls -lh "$DMG_OUTPUT"
