#!/bin/bash
set -euo pipefail

# Splash Monitor — Aprovisionamiento de Perfil Óptimo Local
# Diseñado para Apple Silicon M4 Max (16 cores, 64 GB RAM)
# Dominio: do.jmgrep.splashmonitor

DOMAIN="do.jmgrep.splashmonitor"

echo "⚙️  Aplicando perfil de configuración de alto rendimiento para Apple M4 Max (64 GB)..."

# 1. Configuración de Inferencia y Splash 1.4.0
defaults write "$DOMAIN" stateFormat -string "bf16"
defaults write "$DOMAIN" thinkingTokenBudget -string "8K"
defaults write "$DOMAIN" persistentCache -bool true
defaults write "$DOMAIN" maxContext -string "128K"
defaults write "$DOMAIN" idleRelease -string "off"
defaults write "$DOMAIN" languageOnly -bool false
defaults write "$DOMAIN" maxMemory -string "auto"
defaults write "$DOMAIN" verifyRows -string "auto"
defaults write "$DOMAIN" expertMemory -string "auto"

# 2. Configuración de Red, Puerto y Dominios
defaults write "$DOMAIN" lastUsedPort -int 8005
defaults write "$DOMAIN" listenOnAllInterfaces -bool true
defaults write "$DOMAIN" allowedHosts -string "jmgrepdevsrl.duckdns.org"
defaults write "$DOMAIN" allowedOrigins -string "*"

# 3. Interfaz y Monitor del Sistema
defaults write "$DOMAIN" showMenuBarIcon -bool true
defaults write "$DOMAIN" autoReleaseOnMemoryPressure -bool true
defaults write "$DOMAIN" refreshInterval -float 1.5
defaults write "$DOMAIN" runInBackground -bool true

echo "✅ Perfil local aplicado con éxito en macOS UserDefaults ($DOMAIN):"
echo "   🧬 Estado GDN:        bf16 (-50% RAM)"
echo "   🤔 Thinking Budget:   8K"
echo "   💾 Caché SSD:         Persistente (--persistent-cache)"
echo "   🧠 Contexto:          128K"
echo "   ⏳ Inactividad:       off (Siempre en RAM)"
echo "   👁️  Modalidad:         Visión + Texto (Multimodal por defecto)"
echo "   🎯 Verificación MoE:  auto (+13% a +42% velocidad)"
echo "   💽 Memoria Expertos:  auto (Streaming dinámico MoE)"
echo "   🔌 Puerto:            8005"
echo "   🌐 Red / Hosts:       0.0.0.0 (jmgrepdevsrl.duckdns.org)"
echo "   🌍 Orígenes CORS:     * (Extensiones Chrome / Web Local)"
