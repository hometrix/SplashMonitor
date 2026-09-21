# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [1.0.0-beta] - 2026-09-20

### 🚀 Novedades y Características
- **Monitor y Dashboard en Vivo:** Monitoreo en tiempo real de inferencia local con Splash en Apple Silicon (velocidades de prefill/decode, KV Cache, DFlash 2, TTFT, ITL).
- **Gestión de Memoria Metal:** Visualización del uso de memoria unificada de la GPU y límites de contexto asignados.
- **Gestor de Modelos Hugging Face:** Descarga, verificación y arranque con 1 clic de modelos cuantizados oficiales y de la comunidad.
- **Lanzador de Agentes:** Integración y ejecución en terminal de Claude Code (`claude`), OpenCode (`opencode`), OpenAI Codex (`codex`) y Nous Hermes (`hermes`).
- **Soporte Multi-idioma:** Detección automática y conmutación entre Español (Dominicano 🇩🇴) e Inglés.
- **Experiencia Nativa macOS:** Barra de menú (*menu bar extra*), ventana principal con `NavigationSplitView` y atajos de teclado.
- **Instalación vía Homebrew Cask:** Soporte para instalación simplificada mediante `brew install --cask hometrix/tap/splash-monitor`.

### 🐛 Correcciones y Mejoras de Resiliencia (Hotfixes)
- **Corrección de sintaxis CLI (`splash serve`):** Se eliminó el argumento no admitido `--port` que provocaba el fallo `splash: error: unrecognized arguments` y salida con código 2.
- **Splash Bridge Launcher:** Implementación de ejecutor puente (`splash_launcher.py`) que permite ejecutar Splash en cualquier puerto personalizado (ej. 8005, 8080) sin modificar archivos del sistema de Homebrew.
- **Sugerencia y Detección Automática de Puertos:** 
  - Botón ✨ *Sugerir libre* para escanear y asignar automáticamente el primer puerto disponible en el sistema.
  - Indicador visual en tiempo real de disponibilidad del puerto (Libre / En uso).
  - Detección previa de conflictos con procesos de terceros (como Uvicorn, Django, Docker o Node.js) con modal interactivo que permite usar el puerto sugerido o liberar el puerto conflictivo con un solo clic.
- **Limpieza de Bloqueos Huérfanos:** Eliminación automática de archivos `serve.lock` huérfanos cuando el proceso de Splash previo haya terminado o crasheado.
- **Conectividad Robusta de Agentes:** Sincronización automática de variables de entorno (`ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`, `SPLASH_PORT`) al puerto activo para garantizar conexión inmediata con Claude y otros agentes.
