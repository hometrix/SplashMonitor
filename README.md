# Splash Monitor for macOS ⚡️

<div align="center">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B%20%7C%20Apple%20Silicon-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Hardware](https://img.shields.io/badge/Hardware-Apple%20Silicon%20(M3%20%7C%20M4%20%7C%20M5)-0071e3?style=for-the-badge)](https://inco.ai/blog/splash/)
[![Version](https://img.shields.io/badge/Version-1.0.0--beta-orange?style=for-the-badge)](https://github.com/hometrix/SplashMonitor/releases/tag/v1.0.0-beta)
[![Download DMG](https://img.shields.io/badge/Download-DMG%20Installer-success?style=for-the-badge&logo=apple)](https://github.com/hometrix/SplashMonitor/releases/download/v1.0.0-beta/SplashMonitor-1.0.0-beta.dmg)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Author](https://img.shields.io/badge/Author-JMGREP%20Developers%20%7C%20Joan%20Gregorio%20P%C3%A9rez-00205B?style=for-the-badge)](#autor--author)

**[Español 🇩🇴](#-español)** &nbsp;•&nbsp; **[English 🇬🇧](#-english)**

</div>

---

# 🇩🇴 Español

## 📋 Resumen del Proyecto

**Splash Monitor** es la primera aplicación gráfica de escritorio y monitor de barra de menú (*macOS Status Bar*) desarrollada específicamente para el motor de inferencia local de alto rendimiento **[Splash](https://inco.ai/blog/splash/)** creado por **Inco AI** para la arquitectura **Apple Silicon** (chips M3, M4 y M5).

Hasta el lanzamiento de esta herramienta, Splash se operaba exclusivamente desde la línea de comandos de la terminal. Splash Monitor convierte a Splash en una suite visual completa para desarrolladores y usuarios de macOS, permitiendo monitorizar el rendimiento de inferencia en tiempo real, descubrir e instalar modelos de Hugging Face con un solo clic, arrancar y alternar modelos de inteligencia artificial y lanzar agentes de código de forma inmediata.

---

## 🌟 Características Principales

### 1. 🖥️ Aplicación de Escritorio Completa y Monitor de Barra de Menú Opcional
- **Herramienta de Escritorio Completa**: Diseñada con `NavigationSplitView` nativa de SwiftUI para una experiencia de software premium, con gráficas expandidas, explorador de catálogos y paneles de control.
- **Selector de Ubicación Inteligente**: Al iniciar, la aplicación consulta al usuario si desea anclar un monitor interactivo en la barra superior de menús junto a los íconos del sistema (Bluetooth, Wi-Fi).
- **Modos de Visualización en Barra Superior**:
  - *Solo Ícono de Estado*.
  - *Ícono + Velocidad de Decodificación en tiempo real (`tok/s`)*.
  - *Ícono + Contador Acumulado de Tokens*.
  - *Ícono + Nombre del Modelo Activo*.

### 2. 📊 Monitoreo de Tokens y Rendimiento en Vivo
- **Velocidad de Decodificación y Prefill**: Métricas exactas en tiempo real calculadas en base al historial de inferencia del motor (`tok/s`), acompañadas de una gráfica visual *sparkline*.
- **Ahorro de Tokens por Prefix Caching KV**: Monitoreo del porcentaje de aciertos de caché (`hit_rate`) y contador de tokens ahorrados en contexto (`reused_tokens`).
- **Aceptación Especulativa DFlash 2**: Mide la eficiencia de aceleración especulativa con el porcentaje de aciertos del modelo borrador (`draft_acceptance_rate`).
- **Latencias de Inferencia**:
  - *TTFT (Time to First Token)*: Tiempo transcurrido hasta emitir el primer token (percentil p50).
  - *ITL (Inter-Token Latency)*: Tiempo medio entre la emisión de tokens consecutivos.
- **Hardware Metal y Memoria Unificada**: Barra interactiva de uso de memoria GPU Metal (ej. `23.7 GB / 55.6 GB`) y lectura del procesador Apple Silicon detectado.
- **Métricas de Peticiones**: Conteo en vivo de solicitudes completadas, en cola, canceladas y con error.
- **Firma de Autor**: Identificación oficial de `JMGREP Developers By Joan Gregorio Pérez - Ingeniero en software`.

### 3. 📦 Gestor e Instalador de Modelos (Hugging Face)
- **Modelos Locales Instalados**: Detecta automáticamente los modelos en disco (`~/Library/Application Support/Splash/models`), indicando su tamaño en GB y permitiendo activarlos o borrarlos.
- **Catálogo Hugging Face en Vivo**: Conexión directa a la API de Hugging Face para buscar y filtrar modelos optimizados para Splash (`incoai/*` y modelos comunitarios etiquetados con `splash`).
- **Instalador Integrado con Terminal en Tiempo Real**: Descarga cualquier repositorio `owner/repo` en segundo plano mostrando la salida de la consola en vivo, verificación de kernels Metal y cálculo de peso sin requerir scripts manuales.

### 4. 🕹️ Arranque y Control del Servidor Splash
- **Selector de Modelo para Iniciar**: Menú desplegable interactivo para elegir qué modelo arrancar entre los instalados o ingresar un identificador personalizado.
- **Cambio de Modelo en Caliente**: Cambia el modelo activo en un solo clic; el monitor detiene de forma limpia el servidor anterior e inicia el nuevo en el puerto deseado (`8005`, `8000`, etc.).
- **Lanzadores Rápidos de Agentes de Código**:
  - `splash claude` (Claude Code)
  - `splash opencode` (OpenCode)
  - `splash codex` (Codex)
  - `splash hermes` (Hermes)
- **Integración OpenAI**: Botones de un clic para copiar la URL base compatible con OpenAI (`http://127.0.0.1:8005/v1`) y comandos de exportación de variables de entorno para terminales.

### 5. 🌐 Detección Automática del Idioma del Sistema Operativo
- **Sincronización Dinámica con macOS**: La aplicación detecta el idioma del sistema (`Locale.preferredLanguages`). Si tu Mac está en español, la interfaz se configura en **Español 🇩🇴**; si está en inglés o cualquier otro idioma, se adapta a **English 🇬🇧**.
- **Observador en Tiempo Real**: Responde automáticamente a cambios de idioma en los *Ajustes del Sistema* de macOS sin necesidad de reiniciar.
- **Control Manual**: Permite forzar el idioma en cualquier momento desde la barra lateral o los ajustes.

### 6. 🎨 Ícono 3D Nativo con Silueta Transparente
- Diseñado como una gota de cristal líquido (*Splash*) con filamentos y esfera interna de energía neural en tonos cian y violeta.
- **Sin marco ni fondo cuadrado**: Canal alfa 100% transparente para integrarse con el Dock y la barra de macOS tanto en modo claro como en modo oscuro.

---

## 📦 Instalación (Fácil para Usuarios)

No necesitas instalar herramientas de desarrollo ni compilar código. Puedes instalar la aplicación directamente mediante el instalador `.dmg`:

1. **Descarga el instalador oficial**:
   👉 **[Descargar SplashMonitor-1.0.0-beta.dmg](https://github.com/hometrix/SplashMonitor/releases/download/v1.0.0-beta/SplashMonitor-1.0.0-beta.dmg)** *(4.3 MB)*
2. Haz doble clic en el archivo `.dmg` descargado.
3. Arrastra el ícono de **Splash Monitor** a la carpeta **Aplicaciones** (*Applications*).
4. Abre **Splash Monitor** desde Launchpad, Spotlight o tu carpeta de Aplicaciones.

> **Requisito Previo**: Asegúrate de tener instalado el motor Splash en tu Mac:
> ```bash
> brew install incoai/tap/splash
> ```

---

## 🛠️ Guía para Desarrolladores (Compilación desde Código Fuente)

Si eres desarrollador y deseas compilar o contribuir al proyecto:

### Requisitos
- Mac con procesador Apple Silicon (M3, M4, M5).
- macOS 13.0 o superior (optimizado para macOS 15 Sequoia y macOS 26 Tahoe).
- Xcode 15+ o Swift 6.0 Toolchain.

### Pasos de Compilación
```bash
# 1. Clonar el repositorio
git clone https://github.com/hometrix/SplashMonitor.git
cd SplashMonitor

# 2. Compilar la aplicación y generar el bundle .app
./scripts/build_app.sh

# 3. (Opcional) Generar el instalador DMG comprimido
./scripts/create_dmg.sh

# 4. Iniciar la aplicación compilada
open "Splash Monitor.app"
```

---

## 🏗️ Arquitectura del Proyecto

```
SplashMonitor/
├── Package.swift                    # Definición de dependencias y target ejecutable Swift SPM
├── LICENSE                          # Licencia de código abierto MIT
├── CONTRIBUTING.md                  # Guía de contribución para la comunidad
├── README.md                        # Documentación técnica bilingüe
├── Resources/
│   ├── AppIcon.icns                 # Ícono oficial multi-resolución para macOS
│   └── AppIcon.iconset/             # Conjunto de recursos de íconos (16px a 1024px)
├── scripts/
│   ├── build_app.sh                 # Script de compilación Release y armado del bundle .app
│   └── create_dmg.sh                # Script de empaquetado del instalador DMG con hdiutil
└── Sources/
    └── SplashMonitor/
        ├── SplashMonitorApp.swift   # Punto de entrada (WindowGroup + MenuBarExtra)
        ├── Models/
        │   └── SplashStatus.swift   # Estructuras Codable para /status de Splash y API de HF
        ├── Services/
        │   ├── SplashService.swift  # Servicio central singleton (polling, procesos, servidor)
        │   └── LocalizationService.swift # Detección del SO y traducción reactiva bilingüe
        └── Views/
            ├── MainWindowView.swift # Ventana de escritorio con NavigationSplitView y paneles
            ├── MenuBarView.swift    # Popover interactivo para la barra de menú superior
            ├── TokenMetricsView.swift # Gráficas sparkline, tarjetas de velocidad y memoria
            ├── ModelManagerView.swift # Gestor de modelos locales y explorador Hugging Face
            ├── ServerControlView.swift# Selector de modelo, control de proceso y agentes
            ├── AboutView.swift      # Créditos oficiales, insignias de autor y versión Beta
            ├── AppIconView.swift    # Componente visual para renderizar el ícono de la app
            └── DominicanEmblem.swift# Emblema gráfico patrio dominicano
```

---

## 👨‍💻 Autor y Créditos

**Splash Monitor** ha sido concebido, diseñado y programado por:

- **Empresa / Equipo**: **JMGREP Developers**
- **Ingeniero a cargo**: **Joan Gregorio Pérez** — *Ingeniero en software*
- **Origen**: 🇩🇴 **República Dominicana**
- **Versión**: `1.0.0-beta`

---

## 📄 Licencia

Este proyecto se distribuye bajo la **Licencia MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---
---

# 🇬🇧 English

## 📋 Project Overview

**Splash Monitor** is the world's first native macOS desktop application and menu bar monitor (*macOS Status Bar*) built specifically for the high-performance local inference engine **[Splash](https://inco.ai/blog/splash/)**, created by **Inco AI** for **Apple Silicon** architecture (M3, M4, and M5 chips).

Before this tool, Splash was operated exclusively through the terminal command-line interface. Splash Monitor transforms Splash into a complete, visual developer suite on macOS, allowing developers and AI enthusiasts to monitor inference throughput in real time, explore and install Hugging Face models with a single click, start and hot-swap active models, and launch code agents instantly.

---

## 🌟 Key Features

### 1. 🖥️ Full Desktop Application & Optional Menu Bar Extra
- **Full Desktop Suite**: Built with SwiftUI's native `NavigationSplitView` providing an expansive, responsive desktop workflow with sidebar navigation, metric dashboards, and catalog explorers.
- **Interactive Setup Prompt**: On launch, the application asks whether you want to pin an interactive monitor in the top macOS menu bar next to system icons (Bluetooth, Wi-Fi).
- **Menu Bar Display Modes**:
  - *Icon Only*.
  - *Icon + Real-time Decode Throughput (`tok/s`)*.
  - *Icon + Cumulative Token Counter*.
  - *Icon + Active Model Name*.

### 2. 📊 Real-Time Token Metrics & Performance Dashboard
- **Decode and Prefill Speeds**: Precise, live throughput measurements calculated from the inference engine's engine status (`tok/s`), accompanied by dynamic sparkline charts.
- **Prefix Caching KV Token Savings**: Real-time counter of context tokens reused (`reused_tokens`) and cache hit rate percentage (`hit_rate`).
- **DFlash 2 Speculative Acceptance Rate**: Live tracking of draft token acceptance efficiency (`draft_acceptance_rate`).
- **Inference Latencies**:
  - *TTFT (Time to First Token)*: P50 latency elapsed until the first generated token.
  - *ITL (Inter-Token Latency)*: P50 duration between consecutive generated tokens.
- **Metal GPU & Unified Memory**: Real-time memory pressure gauge (e.g., `23.7 GB / 55.6 GB`) and detected Apple Silicon GPU core counter.
- **Request State Counters**: Live tracking of completed, queued, cancelled, and failed requests.
- **Author Signature**: Official signature of `JMGREP Developers By Joan Gregorio Pérez - Ingeniero en software`.

### 3. 📦 Model Manager & Hugging Face Catalog
- **Local Installed Models**: Automatically detects downloaded models stored in `~/Library/Application Support/Splash/models`, displaying disk footprint in GB and enabling one-click switching.
- **Live Hugging Face Catalog**: Direct integration with the Hugging Face API to discover, filter, and review Splash-ready models (`incoai/*` and community models tagged with `splash`).
- **Integrated Background Installer**: Downloads any Hugging Face model (`owner/repo`) with live terminal log streaming, Metal kernel verification, and progress monitoring without running manual terminal commands.

### 4. 🕹️ Splash Server Controls & Active Model Selector
- **Interactive Model Selector**: Select which installed model to run using an interactive dropdown, or input custom model repository paths.
- **Hot-Swapping**: Switch active models with a single click; Splash Monitor cleanly shuts down the active instance and boots the newly chosen model on the configured port (`8005`, `8000`, etc.).
- **One-Click Code Agent Launchers**:
  - `splash claude` (Claude Code)
  - `splash opencode` (OpenCode)
  - `splash codex` (Codex)
  - `splash hermes` (Hermes)
- **OpenAI-Compatible Endpoints**: One-click copy for API endpoints (`http://127.0.0.1:8005/v1`) and terminal environment variable exports.

### 5. 🌐 macOS System Language Auto-Detection
- **Real-Time OS Sync**: Dynamically detects the system language (`Locale.preferredLanguages`). If your Mac is configured in Spanish, the UI automatically defaults to **Español 🇩🇴**; otherwise, it adapts to **English 🇬🇧**.
- **Live Locale Observer**: Reacts immediately to system language alterations made in macOS *System Settings* without requiring an application restart.
- **Manual Override**: Allows toggling between Spanish and English at any time via the sidebar or settings panel.

### 6. 🎨 Native 3D Liquid Silhouette App Icon
- Custom-designed crystal liquid splash droplet enclosing an iridescent cyan and violet neural energy sphere.
- **Transparent Alpha Channel**: Free of square container boxes or solid background tiles, seamlessly adapting to both Light and Dark Dock styles.

---

## 📦 Installation (End Users)

You do not need to compile code or install Xcode. You can install the prebuilt binary using the official `.dmg` installer:

1. **Download the installer**:
   👉 **[Download SplashMonitor-1.0.0-beta.dmg](https://github.com/hometrix/SplashMonitor/releases/download/v1.0.0-beta/SplashMonitor-1.0.0-beta.dmg)** *(4.3 MB)*
2. Double-click the downloaded `.dmg` file.
3. Drag the **Splash Monitor** icon into your **Applications** folder (*Drag & Drop*).
4. Launch **Splash Monitor** from Launchpad, Spotlight, or your Applications folder.

> **Prerequisite**: Ensure that Inco AI's Splash engine is installed on your Mac:
> ```bash
> brew install incoai/tap/splash
> ```

---

## 🛠️ Developer Guide (Building from Source)

If you are a developer looking to build or contribute to the project:

### Requirements
- Mac with Apple Silicon (M3, M4, M5).
- macOS 13.0 or later (tested on macOS 15 Sequoia and macOS 26 Tahoe).
- Xcode 15+ or Swift 6.0 Toolchain.

### Build Instructions
```bash
# 1. Clone the repository
git clone https://github.com/hometrix/SplashMonitor.git
cd SplashMonitor

# 2. Build the release binary and bundle .app
./scripts/build_app.sh

# 3. (Optional) Create the compressed DMG installer
./scripts/create_dmg.sh

# 4. Launch the application
open "Splash Monitor.app"
```

---

## 🏗️ Architecture

```
SplashMonitor/
├── Package.swift                    # Swift Package Manager manifest
├── LICENSE                          # MIT Open Source License
├── CONTRIBUTING.md                  # Contribution guidelines
├── README.md                        # Bilingual technical documentation
├── Resources/
│   ├── AppIcon.icns                 # Multi-resolution macOS icon bundle
│   └── AppIcon.iconset/             # Standard & Retina icon assets (16px to 1024px)
├── scripts/
│   ├── build_app.sh                 # Release build and .app bundling script
│   └── create_dmg.sh                # Automated DMG packaging script via hdiutil
└── Sources/
    └── SplashMonitor/
        ├── SplashMonitorApp.swift   # Main entry point (WindowGroup + MenuBarExtra)
        ├── Models/
        │   └── SplashStatus.swift   # Codable data structures for /status and HF API
        ├── Services/
        │   ├── SplashService.swift  # Singleton service (polling, process management)
        │   └── LocalizationService.swift # Dynamic OS language detection & reactive translations
        └── Views/
            ├── MainWindowView.swift # Desktop window with NavigationSplitView
            ├── MenuBarView.swift    # Top menu bar popover view
            ├── TokenMetricsView.swift # Real-time speed cards, charts, and Metal memory gauge
            ├── ModelManagerView.swift # Local model list and live Hugging Face catalog
            ├── ServerControlView.swift# Model selector, server controls, and agent launchers
            ├── AboutView.swift      # Author credits, badges, and Beta version details
            ├── AppIconView.swift    # Free-floating app icon presentation component
            └── DominicanEmblem.swift# Dominican Republic national emblem component
```

---

## 👨‍💻 Author & Credits

**Splash Monitor** was designed, architected, and built by:

- **Organization / Team**: **JMGREP Developers**
- **Lead Engineer**: **Joan Gregorio Pérez** — *Software Engineer*
- **Origin**: 🇩🇴 **Dominican Republic**
- **Version**: `1.0.0-beta`

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for complete details.
