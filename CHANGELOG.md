# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [1.0.5-beta] - 2026-10-02

Versión enfocada en la conectividad en red local (LAN) y dominios remotos/DDNS,
resolviendo la protección estricta contra DNS Rebinding de Splash y optimizando la
monitorización de clientes de red.

### 🚀 Novedades y Características

- **Soporte de Dominios y Hosts Permitidos (`--allowed-host`):** Nuevo campo de configuración en *Opciones del Motor de Inferencia* que permite declarar dominios DDNS (ej. DuckDNS, ngrok, Cloudflare Tunnel o nombres de host Bonjour `.local`). Los parámetros se sanitizan e inyectan automáticamente en `splash serve --allowed-host <host>`, resolviendo los bloqueos de seguridad HTTP 403 Forbidden por mitigación de DNS Rebinding.
- **Resolución Automática de IP de Red Local (LAN):** Nuevo módulo `NetworkInterfaceHelper` que resuelve la dirección IPv4 activa del Mac en interfaces de red primarias (`en0`, `en1`), evitando direcciones de bucle invertido (`127.x.x.x`) y enlace local (`169.254.x.x`).
- **Detección y Monitoreo de Clientes LAN:** Nueva categoría `AppCategory.lanClient` (`Cliente Remoto / Red LAN`) en `scanConnectedClients`, que reconoce e inspecciona conexiones entrantes remotas desde otros equipos o servidores de la red local, reflejándolas con su respectiva IP en la lista de apps activas e integrándolas en el contador total de sockets TCP.
- **Métricas y Tarjetas de Estado Dinámicas:** La tarjeta de *Sockets TCP Activos* en la pestaña *Apps Conectadas* ahora refleja dinámicamente si el motor está enlazado a la red local (`Conexiones LAN (IP)` / `0.0.0.0`) o en localhost (`Conexiones 127.0.0.1`), corrigiendo el texto estático anterior.
- **Endpoints de Integración y Guías de Conexión Adaptativas:** Los botones de copia rápida (`Copiar OpenAI URL` y `Copiar Env Vars`) y las tarjetas de la *Guía de Conexión* (Cursor IDE, VS Code/Cline, Claude Code CLI, Claude Desktop, Chatbox, Python, cURL) ahora adaptan automáticamente sus URLs y ejemplos al host preferido (dominio configurado o IP local) cuando el enlace LAN está habilitado.
- **Cobertura de Pruebas Ampliada:** Se añadieron nuevos casos de prueba en `ServerOptionsTests` para `preferredHostOrIP`, inyección de `--allowed-host` y propiedades de `lanClient`, totalizando 76 tests automatizados con 0 fallos.

## [1.0.4-beta] - 2026-10-02

Versión orientada a la integración nativa de agentes visuales y autónomos en macOS,
destacando el soporte oficial de **Claude Cowork** (modo colaborativo de Claude for Mac)
y la generación integral de capturas de pantalla de todos los módulos de la aplicación.

### 🚀 Novedades y Características

- **Lanzador Oficial de Claude Cowork:** Integración del nuevo botón interactivo en el panel de *Servidor y Agentes*, con activación nativa de `/Applications/Claude.app` mediante AppKit (`NSWorkspace.shared.openApplication`).
- **Mapeo de Aliases de Modelo en Splash (`--served-model-name`):** `startServer()` ahora inyecta automáticamente los nombres de modelo de sondeo requeridos por Claude Desktop y Cowork (`claude-haiku-4-5`, `claude-3-5-sonnet-latest`, `claude-sonnet-4-5`). Esto elimina los errores HTTP 404 de "Model not found" que ocurrían al conectar el Gateway local.
- **Detección Automática de Claude Desktop / Cowork:** El monitor de conexiones activas (`scanConnectedClients`) ahora reconoce el proceso `com.anthropic.claudefordesktop`, clasificándolo como Agente de Código Autónomo con su icono oficial de macOS y estadísticas de sockets TCP.
- **Tarjeta de Guía de Integración para Claude Gateway:** Se añadió una tarjeta dedicada en la pestaña de Guía de Conexión de *Apps Conectadas* explicando cómo configurar el Gateway local en Claude for Mac (`http://127.0.0.1:<puerto>`).
- **Galería Visual de Todos los Módulos:** Se añadieron capturas de pantalla en alta resolución para cada módulo en el repositorio con documentación explicativa.
- **Enlace de Red Configurable (Acceso LAN con `--host 0.0.0.0`):** Selector interactivo y persistente para alternar entre enlace local (`127.0.0.1`) o exponer el motor a la red local (`0.0.0.0`), permitiendo que otros dispositivos o agentes en la LAN utilicen la inferencia del Mac (atiende [Issue #1](https://github.com/hometrix/SplashMonitor/issues/1)).
- **Límite de Ventana de Contexto (`--max-context`):** Selector configurable (`Auto`, `16K`, `32K`, `64K`, `128K`, `256K`) con sanitización estricta de parámetros para ajustar la memoria reservada al historial de tokens (atiende [Issue #1](https://github.com/hometrix/SplashMonitor/issues/1)).
- **Ampliación de Pruebas Unitarias:** Se añadieron suites de prueba automáticas (`AgentLaunchTests`, `ScreenshotGeneratorTests` y `ServerOptionsTests`), alcanzando 73 pruebas automatizadas passing.

### 🐛 Correcciones y Mejoras de Comunidad

- **Legibilidad de la Consola de Descarga en Modo Claro:** Corrección de contraste en `ModelManagerView` usando texto blanco de alta opacidad sobre fondo oscuro en lugar de `.primary`, incremento de fuente a 10 pt monoespaciada, mayor altura de visualización (90 pt) y habilitación de `.textSelection(.enabled)` para copiar errores o rutas. Agradecimientos a [@ajaxharg](https://github.com/ajaxharg) (PR [#2](https://github.com/hometrix/SplashMonitor/pull/2)).

## [1.0.3-beta] - 2026-09-24

Versión de corrección derivada de la auditoría integral de la 1.0.2-beta. Se corrigieron
los cuatro defectos bloqueantes, se añadió la red de pruebas que faltaba (no existía
ninguna) y se cerró la clase de errores de distribución que publicaba artefactos con la
versión equivocada.

### 🔒 Seguridad

- **Inyección de comandos por identificador de modelo (P-03, crítico):** `startServer()` interpolaba el identificador de modelo dentro de un script de shell. Un valor como `incoai/x" ; touch /tmp/testigo ; echo "` cerraba el entrecomillado y ejecutaba comandos arbitrarios con los privilegios del usuario; verificado en la auditoría con un fichero testigo. Ahora todo identificador se valida (`ModelIDValidator`) con las mismas restricciones que impone el motor a sus alias, y la interfaz avisa antes de intentar arrancar. La misma validación protege `installModel` y `deleteModel`, donde un valor con `../` borraba archivos fuera del directorio de modelos.
- **Se dejó de matar procesos ajenos (P-01, crítico):** al detener el servidor se ejecutaba `lsof -ti :<puerto>` seguido de `SIGKILL` a **todos** los PIDs devueltos, incluidos los clientes conectados (agentes, IDEs, túneles SSH y cualquier otro proceso que escuchara en ese puerto). Medido: con un servidor y un cliente en procesos distintos, `lsof -ti :<puerto>` devuelve los dos. Ahora solo se señalizan **escuchas verificadas** (`lsof -tiTCP:<puerto> -sTCP:LISTEN`) cuya línea de comandos pertenezca al motor, con escalada `SIGINT` → `SIGTERM` → `SIGKILL`.
- **Fin de los `pkill -f` genéricos (P-06):** se eliminaron `pkill -INT -f "splash serve"`, `pkill -f server.py` y `pkill -9`, que alcanzan cualquier proceso del sistema cuya línea de comandos contenga esos patrones, incluidos servidores de otros proyectos.
- **Terminación de apps conectadas con verificación y confirmación (P-04):** el botón «Terminar» enviaba `SIGTERM` al primer clic, sin confirmación y sin comprobar que el PID siguiera siendo la misma aplicación (un PID reciclado apuntaba a otro proceso). Ahora pide confirmación, reverifica el bundle identifier y nunca actúa sobre el propio monitor.
- **Escritura en `~/.zshrc` con consentimiento y reversible (P-09):** la app modificaba el perfil del shell sin avisar y sin forma de deshacerlo. Ahora pide permiso la primera vez (con opción «no volver a preguntar»), y Configuración ofrece deshacer con una reversión exacta de la inyección. El fichero `~/.splash_monitor_env` se sigue escribiendo siempre, porque los agentes de terminal lo necesitan.
- **Liberación de puerto con reverificación de identidad:** al resolver un conflicto de puerto se comprueba que el PID siga siendo el proceso detectado antes de señalizarlo, y se usa `SIGTERM` antes de `SIGKILL`.

### 🐛 Correcciones

- **El panel dejaba de actualizarse para siempre (P-02, crítico):** `stopServerAsync()` invalidaba el temporizador de sondeo y **ninguna ruta lo recreaba**. Tras pulsar «Detener Servidor» una sola vez, la aplicación dejaba de reflejar el estado durante el resto de la sesión, y un motor arrancado después (desde la terminal o por un agente) nunca se detectaba. Ahora, al detener el servidor queda armado un vigía de recuperación que rearma el sondeo en cuanto aparece un motor vivo.
- **Comparación de versiones rota (P-07):** se comparaban versiones con `String >` (orden lexicográfico), de modo que `1.0.10-beta` se consideraba **anterior** a `1.0.2-beta` y la app dejaba de anunciar actualizaciones a partir de la décima revisión. Ahora hay comparación semántica real (`SemanticVersion`).
- **Bloqueo del motor que nunca se leía (P-08):** la app buscaba `runtime/serve.lock`, pero el motor 1.0.2 escribe `runtime/serve-<puerto>.lock`; el fichero histórico llega con 0 bytes, de modo que la lectura siempre devolvía `nil`. Ahora se consideran ambos nombres, se ignora lo vacío o corrupto y se limpian los bloqueos huérfanos (con un margen de 5 minutos para no tocar un motor en arranque).
- **E/S síncrona del sondeo (P-12):** cada ciclo de 1,5 s reescaneaba el árbol de modelos resolviendo symlinks desde el `@MainActor`. Medido sobre los modelos reales del equipo (3 modelos, 215 ficheros, 55,7 GB): 7,5 ms por ciclo, unas 430 s de E/S síncrona acumulada en 24 h con la app abierta. Ahora los tamaños se cachean por modelo y se invalidan al cambiar el enlace, y el catálogo se reescanea como mucho una vez cada 10 ciclos.
- **Regla contradictoria del entorno (P-13):** `startServer()` borraba `~/.splash_monitor_env` cuando el puerto era 8000 mientras `checkServerStatus()` lo escribía para ese mismo puerto. Queda una política única: se sincroniza siempre.
- **Detección de agentes en segundo plano:** el escaneo de conexiones TCP ahora ejecuta solo el comando externo fuera del actor principal y consulta AppKit (`NSRunningApplication`) donde corresponde, en lugar de hacerlo desde un hilo de fondo.
- **Residuos de versiones anteriores (P-17):** al arrancar se elimina `splash_launcher.py`, el *bridge launcher* retirado en 1.0.1 que seguía en disco tras actualizar.

### 📦 Distribución

- **Versión única (P-15):** la versión se declaraba en cinco lugares (servicio Swift, `Info.plist`, DMG, instalador y README) y ya había divergido entre sí: el README anunciaba 1.0.0-beta y el binario compilaba 1.0.2-beta. Ahora `Sources/SplashMonitor/Services/Version.swift` es la única fuente, y los tres scripts extraen de ahí la versión, el identificador de paquete y el número de compilación.
- **Instalador sin versión fija (P-05):** `install.sh` fijaba `v1.0.2-beta`. Ahora consulta la última publicación, permite fijar una versión con `SPLASH_MONITOR_TAG` y **verifica la suma SHA-256** de la descarga contra el fichero `SHA256SUMS` publicado, abortando si no coincide. El README advierte de que el cask del tap puede quedarse atrás.
- **Suma de verificación publicable (P-18):** `create_dmg.sh` genera `SHA256SUMS` junto al DMG y comprueba que el bundle contiene la misma versión que declara el código, recompilando si no coincide. Se eliminó `codesign --deep` (obsoleto) y la firma se aplica en orden: binario y después bundle.
- **Identificador de paquete propio (P-11):** `com.incoai.splashmonitor` reclamaba el espacio de nombres de IncoAI para un monitor que es software independiente. Ahora es `do.jmgrep.splashmonitor`.
- **Integración continua:** nuevo flujo de GitHub Actions que compila, ejecuta las pruebas, valida el modo Swift 6, construye el bundle y el DMG, y verifica la suma publicada.

### 🧪 Pruebas

- **Se pasó de 0 a 65 pruebas automatizadas** (`swift test`). La aplicación no tenía ninguna. Las pruebas son herméticas: transporte de estado simulado, terminador de procesos simulado, directorio temporal propio y `bootstrapNetwork: false` (sin tráfico a Hugging Face ni a GitHub). Ninguna prueba envía señales a procesos reales ni escribe en el `~/.zshrc` del usuario.
- **Modo Swift 6:** el paquete compilaba con 5 errores de concurrencia (`Localization.shared` y `ConnectedApp` no `Sendable`) y ahora compila limpio en modo Swift 6 (`swift build -Xswiftc -swift-version -Xswiftc 6`), verificado también en la batería de pruebas. No se cambió la versión del manifiesto para no romper Xcode 15.
- Cada corrección tiene una prueba que la protege y se verificó en rojo→verde: se reintrodujo cada defecto original en el código, se comprobó que la prueba falla, y se restauró el fichero verificando su hash (**10/10 defectos detectados**).

### ⚠️ Limitaciones conocidas

- **La firma es ad-hoc.** No hay notarización de Apple: el primer arranque requiere el paso manual de «Abrir de todas formas» descrito en el README. La firma ad-hoc no acredita autoría criptográficamente.
- **El cask de Homebrew** vive en el repositorio del tap (`hometrix/homebrew-tap`) y debe actualizarse por separado; el README ahora lo advierte y las Opciones B y C no dependen de él.
- **El paquete de disciplina de prompt** para modelos pequeños no se ha incorporado: es un cambio de comportamiento del motor (no de la app) y requiere una decisión aparte. El motor no admite instrucciones del lado del servidor, así que solo puede aplicarse como primer mensaje `role: "system"` del cliente.

## [1.0.2-beta] - 2026-09-24

### 🚀 Novedades y Características

- **Panel de Apps Conectadas (`ConnectedAppsView`):** Nuevo apartado en el menú lateral para monitorear en tiempo real todas las aplicaciones, editores, agentes autónomos y procesos locales de macOS que están consumiendo el motor de inferencia Splash en el puerto activo (`127.0.0.1:puerto`).
- **Detección Automática de Conexiones TCP:** Inspección en segundo plano de sockets TCP activos (`lsof -iTCP:<puerto> -sTCP:ESTABLISHED`) con resolución automática de metadatos de apps mediante `NSRunningApplication` (nombre oficial, bundle identifier e ícono de alta resolución de macOS).
- **Identificación Inteligente de Categorías:** Clasificación visual automática de clientes en:
  - 🟣 **IDEs / Editores:** Cursor, Visual Studio Code, Xcode, Zed, JetBrains, etc.
  - 🟠 **Agentes Autónomos:** Claude Code, OpenCode, Codex, Hermes, Aider.
  - 🟢 **Chatbots y WebUIs:** Chatbox, NextChat, OpenWebUI, LM Studio, Ollama apps.
  - 🔵 **Terminales:** Terminal macOS, iTerm2, Warp, Kitty, Alacritty.
  - 🔷 **Scripts y Automatizaciones:** Python (OpenAI SDK / LangChain), Node.js, cURL.
- **Acciones Rápidas por Aplicación:**
  - 🚀 Traer la aplicación cliente directamente al frente (`activateApp`).
  - 📂 Mostrar el paquete o binario en el Finder de macOS (`revealAppInFinder`).
  - 🛑 Terminar el proceso cliente (`terminateApp`).
- **Hub de Integración y Guía Rápida (Quick Connect):** Pestaña interactiva con guías paso a paso y botones para copiar con 1-clic las configuraciones de API y variables de entorno para Cursor, VS Code (Continue/Cline), Claude Code CLI, Chatbox, scripts de Python y cURL.
- **Insignia Reactiva en el Menú Lateral:** Conteo en tiempo real de aplicaciones activas en la barra de navegación lateral de la aplicación principal.
- **Barra de Apps Conectadas en el Dashboard:** Mini-resumen horizontal integrado en el Dashboard de Tokens (`TokenMetricsView`) con los íconos de las apps que están generando peticiones en la sesión actual.

## [1.0.1-beta] - 2026-09-22

### 🐛 Correcciones

- **Crash por bloqueo del main thread en detección de agentes:** `isAgentInstalled()` ejecutaba `Process.waitUntilExit()` desde el body de SwiftUI, bloqueando el main thread durante el layout y causando `EXC_BAD_ACCESS (SIGSEGV)`. Se reemplazó por detección asíncrona con cache en `installedAgents: Set<String>`, verificada solo vía filesystem sin usar Process.
- **Puerto persistente entre sesiones:** El puerto seleccionado ahora se guarda y se restaura al reiniciar la app o después de un upgrade de Splash. Antes, al ejecutar `brew upgrade splash`, la app perdía el puerto y quedaba desconectada.
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

### 🚀 Novedades

- **Detección Automática de Actualizaciones:** La app consulta GitHub Releases al iniciar y muestra un banner verde cuando hay una nueva versión disponible. Botón "Buscar actualizaciones" en Configuración con enlace directo a la descarga.

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
