# Splash Monitor for macOS 🇩🇴 ⚡️

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black?style=flat-square&logo=apple)](https://apple.com)
[![Swift 6](https://img.shields.io/badge/language-Swift%206-orange?style=flat-square&logo=swift)](https://swift.org)
[![Apple Silicon](https://img.shields.io/badge/hardware-Apple%20Silicon%20(M3%2F%20M4%2F%20M5)-green?style=flat-square)](https://inco.ai/blog/splash/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/badge/version-1.0.0-purple.svg?style=flat-square)](#)
[![Author](https://img.shields.io/badge/author-JMGREP%20Developers%20--%20Joan%20Gregorio%20P%C3%A9rez-red.svg?style=flat-square)](#autor--author)

**Splash Monitor** es la primera aplicación visual y herramienta de escritorio/barra de menú nativa para macOS creada para el motor de inferencia local de alto rendimiento **[Splash](https://inco.ai/blog/splash/)** de **Inco AI** en Apple Silicon.

*English: **Splash Monitor** is the world's first native macOS visual desktop tool and menu bar monitor built specifically for Inco AI's **Splash** local inference engine on Apple Silicon.*

---

## 🌟 Características Destacadas / Key Features

### 1. 🖥️ Herramienta Completa de Escritorio y Barra de Menú Opcional
- **Ventana de Escritorio Completa**: Disfruta de un software con navegación lateral (`NavigationSplitView`), gráficas amplias y controles completos.
- **Ícono Opcional en la Barra Superior (Menu Bar)**: Al iniciar, la app te consulta si deseas colocar un monitor en la barra de menú superior (junto a Bluetooth y Wi-Fi) para vigilar la velocidad y el uso de tokens sin interrumpir tu flujo de trabajo.

### 2. 📊 Monitoreo de Tokens en Tiempo Real / Real-time Metrics
- **Velocidad de Inferencia**: Medición precisa en vivo de velocidad de Decode (`tok/s`) y Prefill (`tok/s`) con gráfica histórica (*sparkline*).
- **Ahorro por Prefix Caching KV**: Contador de tokens reutilizados en el contexto (`cache.reused_tokens`) y porcentaje de aciertos de caché (`cache.hit_rate`).
- **Especulación DFlash 2**: Monitoreo de la tasa de aceptación de tokens del modelo de borrador (`draft_acceptance_rate`).
- **Latencias**: TTFT (*Time to First Token*) percentil p50 y ITL (*Inter-Token Latency*).
- **Hardware Metal**: Consumo de memoria unificada en GB frente al límite recomendado del chip Apple Silicon (M3, M4, M5).

### 3. 📦 Gestor e Instalador de Modelos / Model Manager
- **Modelos Instalados**: Detección automática en `~/Library/Application Support/Splash/models` con tamaño en disco y botón para activar o cambiar modelo al instante.
- **Explorador de Hugging Face en Vivo**: Descubre los modelos oficiales de Inco AI y cualquier modelo de la comunidad con etiqueta `splash`.
- **Instalador Integrado**: Descarga y verifica paquetes Splash directamente desde Hugging Face (`owner/repo`) con consola de terminal en tiempo real y sin comandos manuales.

### 4. 🛠️ Arranque y Control del Servidor / Server Controls
- **Selector de Modelo para Arrancar**: Elige qué modelo iniciar desde un menú desplegable interactivo.
- **Cambio de Modelo en Caliente**: Cambia de modelo activo en un solo clic; el monitor detiene el anterior y levanta el nuevo en el puerto especificado.
- **Lanzadores de Agentes de Código**:
  - `splash claude` (Claude Code)
  - `splash opencode` (OpenCode)
  - `splash codex` (Codex)
  - `splash hermes` (Hermes)
- **Copia de Endpoints**: URLs compatibles con OpenAI (`http://127.0.0.1:8005/v1`) y exportación de variables de entorno con un clic.

### 5. 🌐 Bilingüe Nativo / Bilingual Support
- Cambio instantáneo con un solo clic entre **Español 🇩🇴** e **Inglés 🇬🇧**.

---

## 🚀 Instalación y Compilación / Installation & Build

### Requisitos / Prerequisites
- Mac con **Apple Silicon** (M3, M4, M5 y versiones Pro/Max/Ultra).
- macOS 13.0 o superior (optimizado para macOS 26 Tahoe).
- Motor Splash instalado (`brew install incoai/tap/splash`).

### Compilar y Ejecutar / Build and Run
Clona este repositorio y ejecuta el script de empaquetado:

```bash
git clone https://github.com/hometrix/SplashMonitor.git
cd SplashMonitor
./scripts/build_app.sh
```

Esto generará el bundle `Splash Monitor.app`. Para iniciarlo:
```bash
open "Splash Monitor.app"
```

Para instalarlo permanentemente en tu sistema:
```bash
cp -R "Splash Monitor.app" /Applications/
```

---

## 🏗️ Arquitectura del Proyecto / Architecture

```
SplashMonitor/
├── Package.swift               # Definición Swift Package Manager
├── LICENSE                     # Licencia MIT (Joan Ml. Gregorio P.)
├── CONTRIBUTING.md             # Guía para colaboradores
├── scripts/
│   └── build_app.sh            # Script de compilación Release y empaquetado macOS
└── Sources/
    └── SplashMonitor/
        ├── SplashMonitorApp.swift           # Entry point (WindowGroup + MenuBarExtra)
        ├── Models/
        │   └── SplashStatus.swift           # Modelos de datos Codable para /status y HF
        ├── Services/
        │   ├── SplashService.swift          # Servicio central de sondeo, server y modelos
        │   └── LocalizationService.swift    # Motor de traducción bilingüe (ES 🇩🇴 / EN 🇬🇧)
        └── Views/
            ├── MainWindowView.swift         # Ventana principal de escritorio
            ├── MenuBarView.swift            # Menú emergente de la barra superior
            ├── TokenMetricsView.swift       # Gráficas y tarjetas de tokens y memoria
            ├── ModelManagerView.swift       # Catálogo e instalador de Hugging Face
            ├── ServerControlView.swift      # Selector de modelo y control de servidor
            ├── AboutView.swift              # Acerca de y créditos de autoría
            └── DominicanEmblem.swift        # Emblema oficial dominicano
```

---

## 👨‍💻 Autor / Author

Creado y desarrollado por / Created and developed by:

**JMGREP Developers**  
**Joan Gregorio Pérez** — *Ingeniero en software / Software Engineer*  
🇩🇴 República Dominicana  

> *"La primera aplicación gráfica para potenciar la inferencia local con Splash en Apple Silicon."*

---

## 📄 Licencia / License

Este proyecto está bajo la Licencia **MIT** - consulta el archivo [LICENSE](LICENSE) para más detalles.
