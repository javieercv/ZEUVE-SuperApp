# Resultados de pruebas — ZEUVE 0.15.6.0

Fecha: 20 de septiembre de 2026.
Entorno: Linux x86_64 con Swift 6.2.1.

## PASS

- `swift test --skip-build --filter MultimediaInspectorModuleTests`: **67/67 Swift Testing**, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: **85/85**, 0 fallos. Incluye 2 pruebas nuevas de identidad estable de las filas del Inspector.
- `swift test --skip-build`: **122/122 Swift Testing**, 0 fallos. La suite XCTest ejecutó sus pruebas portables y mantiene un test omitido intencionadamente porque el diagnóstico real de yt-dlp exige macOS Apple Silicon.
- `python3 Scripts/verify/app_sources.py`: PASS; **70** fuentes Swift de ZEUVEApp parseadas.
- `python3 Scripts/verify/xcode_integration.py`: PASS; **10** productos SwiftPM/Xcode coherentes.
- `python3 Scripts/verify/documentation.py`: PASS.
- `python3 Scripts/verify/project_structure.py`: PASS.
- `python3 Scripts/verify/multimedia_inspector.py`: PASS.
- `Scripts/generate_xcode_project.py`: proyecto Xcode regenerado correctamente para build 57 / marketing 0.15.6.

## No completado en este entorno

- `bash Scripts/verify_project.sh`: completa los tests y entra en `swift build -c release`, pero el proceso global supera el límite de ejecución antes de finalizar el build Release. No se registra PASS ni FAIL de ese build.
- `bash Scripts/build_macos.sh Release`: no ejecutable en este entorno; el propio script exige macOS Apple Silicon con Xcode.

## Validación manual requerida en macOS

1. Pistas → `Escuchar` → dejar reproducir varios segundos → `Pausar` en la misma fila.
2. Repetir `Escuchar`/`Pausar` varias veces desde Pistas.
3. Barra inferior → Play → Pistas → `Pausar`.
4. Espectrograma → Play → Pistas → `Pausar`.
5. Mantener reproducción mientras cambia el contador/playhead y confirmar que el botón de Pistas sigue respondiendo.
6. Cambiar de pista y verificar continuidad temporal y de Play/Pausa ya aprobada.
7. Entrar/salir de edición y confirmar que la lista continúa coherente.

La interacción real de SwiftUI/AppKit/AVFoundation debe verificarse en un Mac compatible; los tests portables no sustituyen esa comprobación.
