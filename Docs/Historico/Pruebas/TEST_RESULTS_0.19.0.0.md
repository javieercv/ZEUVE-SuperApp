# Resultados de pruebas — ZEUVE 0.19.0.0

Fecha: 21 de septiembre de 2026.

## Validación local de la corrección de apertura — macOS ARM64

Ejecutada el 21 de septiembre de 2026 con Xcode y Apple Swift 6.3.3 sobre esta carpeta `ZEUVE_Swift_0.19.0.0`.

- Regresión `test_multimedia_inspector_playback_rate.py` antes del cambio: **fallo reproducido**, terminación SIGSEGV (`-11`) al asignar la velocidad del observador original.
- La misma regresión después del cambio: **PASS**, 22 asignaciones ejecutadas con Combine real: restauración repetida, 0,5×–2×, valores fuera de rango, NaN e infinitos; una actualización de audio y, cuando corresponde, un reinicio de vídeo conservando la posición.
- `ZEUVE_SWIFT_JOBS=4 ./Scripts/verify_project.sh`: **PASS completo**, incluidos 215 XCTest, 164 Swift Testing, 108 pruebas Python, build SwiftPM Release, verificadores de proyecto, parseo de las 75 fuentes App, coherencia Xcode, motores y build Xcode Debug ARM64 (`BUILD SUCCEEDED`).
- `codesign --verify --deep --strict` de la app Debug generada: **PASS**.
- Integración nativa adicional: se compilaron los archivos reales `MultimediaInspectorViewModel.swift` y `MultimediaBatchViewModel.swift` con los módulos construidos por Xcode y un ejecutable temporal de prueba, sin almacenamiento persistente. **PASS** en WAV mono abierto desde Resumen y Espectrograma, MP4 con vídeo/audio desde Pistas y MP4 sin audio desde Espectrograma (retorno a Resumen). Las muestras con audio completan espectrograma, señal y sonoridad automáticos. Los cuatro casos comprueban velocidades, cierre y restauración de preferencias. Un WAV inválido publica un error recuperable sin cerrar el proceso.
- SHA-256 de las tres muestras multimedia antes/después: **idénticos**; originales intactos.
- Comprobación visual: **parcial**. La app compilada se abrió y mostró el Inspector y el selector de archivos. El servicio de automatización `SkyComputerUseService` se cerró al confirmar el selector, por lo que no se da por validado el recorrido visual completo. La integración nativa anterior comprueba el flujo real del ViewModel y motores, pero no sustituye la comprobación visual ni la escucha/sincronía perceptual.

No se presenta esta corrección como una validación de todas las funciones de vídeo/OCR de 0.19.0.0. Los resultados históricos y límites de la entrega original siguen a continuación.

## Entornos registrados

La suite portable previa se ejecutó en Linux x86_64 con Swift 6.2.1; ese entorno permite validar Swift portable, tests Python, políticas y estructura, pero no la ejecución nativa de AppKit/SwiftUI/VideoToolbox/Vision ni motores ARM64. Tras el mantenimiento de compilación se ejecutó además un build local desde Xcode.

## Resultados

- Build Xcode local tras mantenimiento de compilación: **PASS**.
- Build Xcode local tras corregir la apertura defensiva del Inspector: **PASS**.
- Build Xcode local tras proteger análisis de audio con `sample_rate`/`channels` inválidos: **PASS**.
- `./Scripts/run_tests.sh`: **PASS**.
- XCTest: **215** pruebas, 0 fallos, 1 omitida por dependencia macOS/ARM64.
- Swift Testing: **164** pruebas, 0 fallos.
- Suite portable del Inspector: **109** pruebas, 0 fallos.
- Python `Tests/ScriptTests`: **107** pruebas, 0 fallos.
- `Scripts/verify/multimedia_inspector.py`: **PASS**.
- `Scripts/verify/project_structure.py`: **PASS**.
- Proyecto Xcode regenerado: marketing `0.19.0`, build `65`, Inspector `0.7.0`.

## Regresiones específicas

La cobertura nueva comprueba edición de vídeo por copy, límites de preview, carpetas/symlinks, reglas semánticas, stores de reglas/favoritos sin rutas, OCR SRT revisable, preview de subtítulos, schema 3 privado, migración de preferencias y protecciones de inputs externos. Se conserva la cobertura de audio preview, waveform, espectrograma, EBU R128, señal, A/B, capítulos, attachments, metadata, Undo/Redo, remux, batch, presets, publicación y OperationCoordinator.

## Pendiente en Mac Apple Silicon

No se ha ejecutado `./Scripts/build_macos.sh Release` en este entorno. Deben validarse render de vídeo real, sincronización audiovisual perceptual, fullscreen, cambio rápido de streams, VideoToolbox y fallback, HDR de inspección, Vision OCR PGS/VobSub, accesibilidad, firma, Gatekeeper y ejecución de los FFmpeg/FFprobe ARM64 empaquetados.
