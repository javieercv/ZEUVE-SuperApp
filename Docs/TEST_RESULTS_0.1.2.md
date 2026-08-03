# Resultados de pruebas — ZEUVE 0.1.2

Fecha: 1 de julio de 2026

## Motivo de esta versión

La compilación con Xcode en macOS detectó dos referencias a tipos de `ZEUVECore` sin importación explícita en el archivo que los usa:

- `DashboardView.swift` utilizaba `ModuleManifest`.
- `RootView.swift` utilizaba `OperationSnapshot`.

Swift aplica las importaciones por archivo. La corrección añade exclusivamente `import ZEUVECore` a esas dos vistas.

## Entorno disponible para la validación

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

Este entorno permite compilar y probar los paquetes Swift independientes de la interfaz. No dispone de Xcode, AppKit, SwiftUI para macOS ni del SDK de macOS.

## Pruebas automáticas

Comando:

```bash
swift test
```

Resultado:

- 30 pruebas ejecutadas.
- 30 pruebas superadas.
- 0 fallos.
- 0 errores inesperados.

Se volvieron a comprobar planificación, conflictos, selección parcial, cancelación y reversión, historial, SQLite, deshacer seguro, CSV, manifiestos, registros locales y coordinación de operaciones.

## Comprobación de regresión añadida

`Scripts/verify_project.sh` comprueba ahora que:

```text
Sources/ZEUVEApp/DashboardView.swift
Sources/ZEUVEApp/RootView.swift
```

contienen una importación explícita de `ZEUVECore`.

La comprobación se ejecutó correctamente.

## Compilaciones comprobadas

- Paquetes Swift en configuración Debug: correcta.
- Paquetes Swift en configuración Release: correcta.
- Análisis sintáctico de los archivos SwiftUI/AppKit: correcto.
- Regeneración y validación estructural de `ZEUVE.xcodeproj`: correcta.
- Verificación estática de ambas importaciones: correcta.

## Comprobación pendiente

No se ha podido compilar ni abrir `ZEUVE.app` en este entorno. La comprobación decisiva pendiente es ejecutar el proyecto con Xcode en un Mac Apple Silicon y confirmar que han desaparecido los diagnósticos de `ModuleManifest` y `OperationSnapshot`.

El aviso de Swift Package Manager que sugiere instalar `sqlite3` mediante Homebrew no se ha modificado en esta corrección y no era la causa de los errores tratados.
