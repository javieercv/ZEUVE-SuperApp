# Resultados de pruebas — ZEUVE 0.15.3.0

Fecha: 19 de septiembre de 2026.

## Entorno disponible

Linux x86_64 con Swift 6.2.1. Este entorno permite validar SwiftPM, lógica portable, tests y verificadores, pero no ejecutar SwiftUI/AppKit/AVFoundation de macOS ni una aplicación firmada.

## Inspector multimedia

Comando ejecutado:

```bash
swift test --jobs 8 --filter MultimediaInspectorModuleTests
```

Resultado: **67 tests Swift Testing, 0 fallos**.

Incluye las regresiones nuevas `previewReplacementContinuityPreservesPlayingAndPausedIntent` y `previewCommandBuilderClampsSeekToShorterDestinationDuration`, además de los tests previos de sustitución A→B→C, invalidación por stop, command builder, waveform, espectrograma, edición y privacidad.

## Tests Python

Comando ejecutado:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado: **83 tests, 0 fallos**.

## Verificadores

Pasaron los verificadores de:

- integración de aplicación;
- estructura del proyecto y versionado;
- motores;
- documentación;
- rendimiento;
- Conversor universal;
- Descargador universal;
- Analizador de chats;
- Comparador de seguidores;
- Inspector multimedia;
- manifiestos;
- parseo de las 70 fuentes Swift de ZEUVEApp;
- coherencia SwiftPM/Xcode con 10 productos;
- documentación de módulos y ejemplos JSON;
- sintaxis Bash y compilación Python.

`Scripts/generate_xcode_project.py` regeneró `ZEUVE.xcodeproj` antes de comprobar la coherencia.

## Comprobaciones que no finalizaron en este entorno

`./Scripts/run_tests.sh` y una ejecución global `swift test --skip-build` se intentaron, pero superaron el límite de tiempo de ejecución disponible. No se atribuye a esas ejecuciones un resultado PASS o FAIL global.

`swift build -c release --target MultimediaInspectorModule` inició correctamente y no mostró errores de las modificaciones antes del límite, pero no terminó dentro del tiempo disponible; por tanto tampoco se registra como PASS.

## Build macOS

`./Scripts/build_macos.sh Release` devolvió explícitamente:

> Esta compilación requiere macOS Apple Silicon con Xcode.

Quedan pendientes en un Mac Apple Silicon la build Release nativa, firma/Hardened Runtime y los 11 escenarios manuales de reproducción/layout definidos para esta corrección.
