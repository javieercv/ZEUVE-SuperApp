# Resultados de pruebas — ZEUVE 0.15.7.0

Fecha: 20 de septiembre de 2026.
Entorno: Linux x86_64 con Swift 6.2.1.

## PASS

- `./Scripts/run_tests.sh`: PASS.
- `swift test --skip-build --filter MultimediaInspectorModuleTests`: **68/68 Swift Testing**, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: **89/89**, 0 fallos; incluye 4 regresiones nuevas de automatización del Inspector.
- Suite Swift global: **123/123 Swift Testing**, 0 fallos. Las suites XCTest portables no registran fallos; un test continúa omitido intencionadamente porque el diagnóstico ejecutable de yt-dlp exige macOS Apple Silicon.
- `python3 Scripts/verify/app_sources.py`: PASS; **70** fuentes Swift de ZEUVEApp parseadas.
- `python3 Scripts/verify/xcode_integration.py`: PASS; **10** productos SwiftPM/Xcode coherentes.
- Verificadores de integración, estructura, motores/preparación, documentación, rendimiento, Conversor, Descargador, Analizador de chats, Comparador de seguidores, Inspector y manifiestos: PASS.
- `python3 Scripts/validate_module_docs.py`: PASS.
- `Scripts/generate_xcode_project.py`: proyecto Xcode regenerado correctamente para build 58 / marketing 0.15.7.
- `swiftc -parse Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift`: PASS.

## Cobertura nueva

- Política mono-pista: 0 streams no automatiza, 1 stream automatiza, 2 o más no automatizan.
- La decisión usa `result.audioStreams.count`; no depende de la extensión.
- La cadena ejecuta espectrograma antes de sonoridad y no usa `async let` ni otra vía paralela.
- La tarea automática espera la generación de espectrograma vigente antes de iniciar sonoridad.
- Reset y cancelación invalidan/cancelan la cadena para impedir fases tardías sobre otra sesión.

## No completado en este entorno

- `./Scripts/verify_project.sh`: supera los tests y entra en `swift build -c release`, pero el proceso es terminado por el límite temporal remoto antes de finalizar la build Release. Repetir la build por separado tampoco alcanza a completarse dentro del límite; no se registra error de compilación antes del corte.
- `./Scripts/build_macos.sh Release`: el propio script informa que requiere macOS Apple Silicon con Xcode.
- `./Scripts/verify_app_macos.sh`: omite correctamente la validación real porque el entorno no es macOS Apple Silicon con Xcode.

## Validación manual requerida en macOS

1. Abrir un WAV o MP3 de una sola pista y confirmar: FFprobe → espectrograma automático → sonoridad automática.
2. Abrir un vídeo con exactamente una pista de audio y confirmar el mismo flujo.
3. Abrir un vídeo/contenedor con dos o más pistas y confirmar que espectrograma y sonoridad no arrancan solos.
4. Abrir un archivo sin audio y confirmar que no se intenta ningún análisis de audio.
5. Cancelar durante el espectrograma automático y comprobar que no arranca después la sonoridad.
6. Cancelar durante sonoridad y confirmar liberación correcta de la operación.
7. Cambiar parámetros del espectrograma durante la generación y confirmar que la sonoridad espera a la generación vigente.
8. Repetir la regresión 0.15.6.0 de Escuchar/Pausar desde Pistas, Espectrograma y reproductor inferior para confirmar que no hay cambios en el transporte compartido.
