<div align="center">

# Contributing to Splash Monitor ⚡️

**[Español 🇩🇴](#-guía-de-contribución)** &nbsp;•&nbsp; **[English 🇬🇧](#-contribution-guide)**

</div>

---

## 🇩🇴 Guía de Contribución

¡Gracias por tu interés en contribuir a **Splash Monitor**! Cualquier tipo de aporte es bienvenido: corrección de errores, nuevas características, mejoras de documentación o sugerencias de diseño.

### Requisitos Previos

- Mac con procesador **Apple Silicon** (M3, M4, M5).
- **macOS 13.0** o superior.
- **Xcode 15+** o la **Swift 6.0 Toolchain**.
- Motor [Splash](https://inco.ai/blog/splash/) instalado: `brew install incoai/tap/splash`.

### Flujo de Trabajo

1. **Bifurcar el repositorio** en GitHub.
2. **Clonar tu bifurcación**:
   ```bash
   git clone https://github.com/<tu-usuario>/SplashMonitor.git
   cd SplashMonitor
   ```
3. **Crear una rama** con un nombre descriptivo:
   ```bash
   git checkout -b feat/nueva-caracteristica
   ```
4. **Realizar tus cambios** y verificar la compilación:
   ```bash
   ./scripts/build_app.sh
   ```
5. **Confirmar los cambios** siguiendo la convención [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat: agregar nueva caracteristica"
   git commit -m "fix: corregir error en MetricCard"
   git commit -m "docs: actualizar guia de instalacion"
   ```
6. **Enviar a tu bifurcación** y abrir un **Pull Request** contra `main`.

### Convenciones de Código

- Usar **Swift Concurrency moderna** (`async/await`, `@MainActor`).
- Mantener los componentes UI **limpios y nativos en SwiftUI** con soporte para modo claro y oscuro.
- Preservar el soporte **bilingüe** (`tr(es:en:)`) para todos los textos visibles al usuario.
- Seguir las guías de estilo de Swift (formato del equipo de Swift).
- Documentar funciones públicas con `///` doc comments.

### Estructura del Proyecto

```
Sources/SplashMonitor/
├── SplashMonitorApp.swift    # Punto de entrada
├── Models/                   # Modelos de datos Codable
├── Services/                 # Lógica de negocio y servicios
└── Views/                    # Componentes SwiftUI
```

### Reportar Errores

Si encuentras un error, por favor [abre un issue](https://github.com/hometrix/SplashMonitor/issues/new) con:

- Descripción clara del problema.
- Pasos para reproducirlo.
- Versión de macOS y modelo de Mac.
- Capturas de pantalla o registros de la terminal si es posible.

### Canales de Seguridad

Si descubres una vulnerabilidad de seguridad, **no** la reportes en un issue público. Consulta nuestra [Política de Seguridad](SECURITY.md) para instrucciones sobre divulgación responsable.

---

## 🇬🇧 Contribution Guide

Thank you for your interest in contributing to **Splash Monitor**! All contributions are welcome: bug fixes, new features, documentation improvements, or design suggestions.

### Prerequisites

- Mac with **Apple Silicon** (M3, M4, M5).
- **macOS 13.0** or later.
- **Xcode 15+** or the **Swift 6.0 Toolchain**.
- [Splash](https://inco.ai/blog/splash/) engine installed: `brew install incoai/tap/splash`.

### Workflow

1. **Fork** the repository on GitHub.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/<your-username>/SplashMonitor.git
   cd SplashMonitor
   ```
3. **Create a branch** with a descriptive name:
   ```bash
   git checkout -b feat/my-new-feature
   ```
4. **Make your changes** and verify the build:
   ```bash
   ./scripts/build_app.sh
   ```
5. **Commit your changes** following [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat: add new feature"
   git commit -m "fix: fix MetricCard rendering issue"
   git commit -m "docs: update installation guide"
   ```
6. **Push** to your fork and open a **Pull Request** against `main`.

### Code Conventions

- Use **modern Swift Concurrency** (`async/await`, `@MainActor`).
- Keep UI components **clean and native in SwiftUI** with support for both Light and Dark mode.
- Maintain **bilingual support** (`tr(es:en:)`) for all user-facing strings.
- Follow Swift style guidelines.
- Document public functions with `///` doc comments.

### Project Structure

```
Sources/SplashMonitor/
├── SplashMonitorApp.swift    # Entry point
├── Models/                   # Codable data models
├── Services/                 # Business logic and services
└── Views/                    # SwiftUI components
```

### Reporting Bugs

If you find a bug, please [open an issue](https://github.com/hometrix/SplashMonitor/issues/new) with:

- A clear description of the problem.
- Steps to reproduce it.
- Your macOS version and Mac model.
- Screenshots or terminal logs if applicable.

### Security

If you discover a security vulnerability, **do not** report it in a public issue. Please see our [Security Policy](SECURITY.md) for responsible disclosure instructions.

---

Created with ❤️ by **JMGREP Developers** · **Joan Gregorio Pérez** — *Ingeniero en software* (República Dominicana 🇩🇴)
