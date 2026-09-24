#!/bin/bash
set -e

# Splash Monitor — 1-Line Installer for macOS
# Developed by JMGREP Developers (Joan Gregorio Pérez)

REPO="hometrix/SplashMonitor"
TAG="v1.0.2-beta"
DMG_URL="https://github.com/${REPO}/releases/download/${TAG}/SplashMonitor-${TAG#v}.dmg"
TEMP_DMG="/tmp/SplashMonitor-installer.dmg"
MOUNT_DIR="/tmp/SplashMonitor-mount"

echo "🌊 Instalando Splash Monitor (${TAG}) para macOS..."

# 1. Descargar DMG oficial desde GitHub Releases
echo "⬇️  Descargando instalador desde GitHub..."
curl -fL --progress-bar "$DMG_URL" -o "$TEMP_DMG"

# 2. Montar imagen de disco
echo "💿 Montando imagen de disco..."
mkdir -p "$MOUNT_DIR"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

# 3. Copiar a /Applications
echo "📦 Instalando en /Applications..."
rm -rf "/Applications/Splash Monitor.app"
cp -R "$MOUNT_DIR/Splash Monitor.app" "/Applications/"

# 4. Desmontar y limpiar
echo "🧹 Limpiando archivos temporales..."
hdiutil detach "$MOUNT_DIR" -quiet || true
rm -rf "$MOUNT_DIR" "$TEMP_DMG"

# 5. Remover atributo de cuarentena de descarga
xattr -cr "/Applications/Splash Monitor.app"

echo "✅ ¡Instalación completada con éxito!"
echo "🚀 Abriendo Splash Monitor..."
open "/Applications/Splash Monitor.app"
