#!/bin/bash
set -euo pipefail

# Splash Monitor — instalador de una línea para macOS
# Desarrollado por JMGREP Developers (Joan Gregorio Pérez)
#
# La versión ya no se fija aquí (P-05/H-06: el cask de Homebrew servía 1.0.0-beta
# mientras el proyecto publicaba 1.0.2-beta). Se consulta la última publicación y su
# suma SHA-256 se verifica antes de instalar (P-18).

REPO="hometrix/SplashMonitor"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
TAG_FALLBACK="v1.0.6-beta"
TEMP_DMG="/tmp/SplashMonitor-installer-$$.dmg"
CHECKSUM_FILE="/tmp/SplashMonitor-SHA256SUMS-$$"
MOUNT_DIR="/tmp/SplashMonitor-mount-$$"

echo "🌊 Splash Monitor — instalador para macOS"

# 1. Resolver la publicación más reciente (con reserva si la API no responde)
TAG="${SPLASH_MONITOR_TAG:-}"
if [ -z "$TAG" ]; then
    echo "🔎 Consultando la última publicación..."
    TAG="$(curl -fsSL "$API_URL" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)"
fi
if [ -z "$TAG" ]; then
    echo "⚠️  No se pudo consultar la API de GitHub. Usando la versión conocida ${TAG_FALLBACK}."
    TAG="$TAG_FALLBACK"
fi
VERSION="${TAG#v}"
DMG_NAME="SplashMonitor-${VERSION}.dmg"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
echo "📌 Versión a instalar: ${TAG}"

# 2. Descargar el DMG y su suma de verificación
echo "⬇️  Descargando instalador desde GitHub..."
curl -fL --progress-bar "${BASE_URL}/${DMG_NAME}" -o "$TEMP_DMG"

cleanup() {
    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
    rm -rf "$MOUNT_DIR" "$TEMP_DMG" "$CHECKSUM_FILE"
}
trap cleanup EXIT

if curl -fsSL "${BASE_URL}/SHA256SUMS" -o "$CHECKSUM_FILE" 2>/dev/null; then
    echo "🔐 Verificando suma SHA-256..."
    EXPECTED="$(sed -n "s/^\([0-9a-f]\{64\}\)  *${DMG_NAME}\$/\1/p" "$CHECKSUM_FILE" | head -1)"
    if [ -z "$EXPECTED" ]; then
        echo "❌ La suma publicada no incluye ${DMG_NAME}. Instalación abortada." >&2
        exit 1
    fi
    ACTUAL="$(shasum -a 256 "$TEMP_DMG" | awk '{print $1}')"
    if [ "$ACTUAL" != "$EXPECTED" ]; then
        echo "❌ La suma SHA-256 no coincide. Descarga corrupta o manipulada." >&2
        echo "   esperada: $EXPECTED" >&2
        echo "   obtenida: $ACTUAL" >&2
        exit 1
    fi
    echo "✅ Suma verificada."
else
    echo "⚠️  No se publicó SHA256SUMS para ${TAG}: instalación sin verificación de integridad."
fi

# 3. Montar imagen de disco
echo "💿 Montando imagen de disco..."
mkdir -p "$MOUNT_DIR"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

# 4. Copiar a /Applications
echo "📦 Instalando en /Applications..."
rm -rf "/Applications/Splash Monitor.app"
cp -R "$MOUNT_DIR/Splash Monitor.app" "/Applications/"

# 5. Remover atributo de cuarentena de descarga
xattr -cr "/Applications/Splash Monitor.app"

echo "✅ ¡Instalación completada con éxito!"
echo "🚀 Abriendo Splash Monitor..."
open "/Applications/Splash Monitor.app"
