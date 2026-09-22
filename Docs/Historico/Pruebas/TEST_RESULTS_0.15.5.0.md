# Resultados de pruebas — ZEUVE 0.15.5.0

Fecha: 20 de septiembre de 2026.

## Entorno disponible

Linux x86_64 con Swift 6.2.1. Este entorno permite validar SwiftPM, lógica portable, scripts, documentación y estructura del proyecto, pero no ejecutar SwiftUI/AppKit/AVFoundation reales de macOS.

## Suite Swift global

```bash
swift test --jobs 8
```

Resultado: **122 tests, 0 fallos**.

## Inspector multimedia

```bash
swift test --filter MultimediaInspectorModuleTests
```

Resultado: **67 tests, 0 fallos**.

```bash
swift build --target MultimediaInspectorModuleTests
```

Resultado: **PASS**.

## Tests Python

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado: **83 tests, 0 fallos**.

## Verificadores ejecutados

Pasaron en ejecución directa:

- `Scripts/verify/multimedia_inspector.py`;
- `Scripts/verify/project_structure.py`;
- `Scripts/verify/documentation.py`;
- `Scripts/verify/app_sources.py`: **70 fuentes Swift** parseadas correctamente;
- `Scripts/validate_module_docs.py`;
- `Scripts/verify/xcode_integration.py`: **10 productos** SwiftPM/Xcode coherentes.

`Scripts/generate_xcode_project.py` regeneró `ZEUVE.xcodeproj` desde la fuente canónica antes de validar la integración.

## Orquestador global y Release

```bash
ZEUVE_SWIFT_JOBS=8 ./Scripts/verify_project.sh
```

El orquestador completó correctamente su primera `swift test` con **122/122 tests**, pero superó el límite de ejecución del entorno durante `swift build -c release`. Por tanto, **no se registra un PASS global** de `verify_project.sh`.

También se intentó por separado:

```bash
swift build -c release --jobs 8
```

La compilación superó el límite de ejecución antes de terminar. No se registra PASS ni FAIL para este build Release.

## Build macOS

```bash
./Scripts/build_macos.sh Release
```

Resultado en este entorno:

> Esta compilación requiere macOS Apple Silicon con Xcode.

## Validación manual necesaria en macOS

Dado que el defecto reportado se manifiesta en la interacción real SwiftUI/AVFoundation, deben comprobarse expresamente:

1. Pistas → `Escuchar` → `Pausar` desde la misma fila.
2. Reproductor inferior → reproducir → `Pausar` desde la fila activa de Pistas.
3. Pistas → reproducir → pausar/reanudar desde Espectrograma.
4. Espectrograma → reproducir → pausar/reanudar desde Pistas.
5. Reanudar desde la misma fila de Pistas después de una pausa.
6. Repetir los casos anteriores tras cambiar de pista conservando posición.

La validación manual debe confirmar tanto el audio real como la etiqueta `Escuchar/Pausar`.
