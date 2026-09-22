# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [1.0.1-beta] - 2026-09-22

### 🐛 Correcciones

- **Puerto persistente entre sesiones:** El puerto seleccionado ahora se guarda en `@AppStorage` y se restaura al reiniciar la app o después de un upgrade de Splash. Antes, al ejecutar `brew upgrade splash`, la app perdía el puerto y quedaba desconectada.
- **Propagación de puerto al motor:** `startServer()` ahora SIEMPRE pasa `--port` al comando `splash serve`, eliminando el comportamiento inconsistente donde el puerto 8000 se ejecutaba sin la flag y puertos personalizados usaban un bridge launcher innecesario.
- **Reinicio automático al cambiar puerto:** Cuando el usuario escribe un nuevo puerto en el campo de texto y el servidor está corriendo, la app reinicia automáticamente el servidor en el nuevo puerto. No es necesario presionar "Reiniciar" manualmente.
- **Agentes conectan al puerto correcto:** `launchAgent()` ahora SIEMPRE configura `SPLASH_PORT`, `ANTHROPIC_BASE_URL` y `OPENAI_BASE_URL` con el puerto activo, eliminando el error "No ready Splash server" cuando el servidor corre en un puerto diferente al default.
- **Detección de puertos generalizada:** Se reemplazó el fallback hardcodeado a puerto 8005 por un scan flexible que prueba múltiples puertos comunes (`[8000, 8001, 8005, 8008, 8080, 8088, 8888, 9000, 9005]`), conectándose automáticamente al primero que responda.
- **Sincronización automática de entorno de terminal:** La app ahora escribe `~/.splash_monitor_env` con `SPLASH_PORT`, `ANTHROPIC_BASE_URL` y `OPENAI_BASE_URL` cada vez que detecta un cambio de puerto (incluyendo después de `brew upgrade splash`). Inyecta `source ~/.splash_monitor_env` en `~/.zshrc` una única vez. Los comandos `splash claude`, `splash codex`, etc. en terminales nuevas conectan automáticamente al puerto correcto.
- **Rutas dinámicas de Splash:** Se eliminaron los paths hardcodeados a versión `1.0` en `splashPythonPath` y `splashModelsScriptPath`. Ahora usa symlinks estables de Homebrew (`/opt/homebrew/opt/splash/`) con fallback a wildcard search en Cellar para cualquier versión.

### 🧹 Eliminado

- **Bridge Launcher (`splash_launcher.py`):** Se eliminó el script puente Python de ~80 LOC. Splash soporta `--port` nativamente desde su primera versión, making el bridge innecesario. Esto simplifica `startServer()` y `launchAgent()` eliminando dependencia de Python paths.

### ⚡️ Mejoras

- **Liberación de memoria al cerrar:** Se agregó `applicationWillTerminate` en `AppDelegate` que ejecuta `stopServerSync()` + `resetState()`, liberando toda la memoria de la app (historial de velocidad, modelos instalados, estado del servidor, timers) al cerrar la aplicación.
- **Liberación de memoria al detener servidor:** `stopServerAsync()` ahora limpia `speedHistory` y detiene el timer de polling, reduciendo la presión de memoria del sistema inmediatamente.
- **`resetState()` público:** Nuevo método que resetea TODO el estado publicado de `SplashService`, disponible para uso en `applicationWillTerminate` y futuras optimizaciones.

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
