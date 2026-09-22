# Resultados de pruebas — ZEUVE 0.15.8.0

Fecha: 20 de septiembre de 2026.
Entorno: Linux x86_64 con Swift 6.2.1.

## PASS

- `./Scripts/run_tests.sh`: **PASS**.
- Suite Swift global: **128/128 Swift Testing**, 0 fallos. Las suites XCTest portables no registran fallos; un test continúa omitido intencionadamente porque el diagnóstico ejecutable de yt-dlp exige macOS Apple Silicon.
- `swift test --skip-build --filter MultimediaInspectorModuleTests`: **73/73 Swift Testing**, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: **89/89**, 0 fallos.
- `./Scripts/verify_project.sh`: **PASS**.
- `swift build -c release --jobs 1`, ejecutado dentro de `verify_project.sh`: **PASS** en 216,99 s.
- `python3 Scripts/verify/multimedia_inspector.py`: **PASS**.
- `python3 Scripts/verify/app_sources.py`: **PASS**; 70 fuentes Swift de ZEUVEApp parseadas.
- `python3 Scripts/verify/xcode_integration.py`: **PASS**; 10 productos SwiftPM/Xcode coherentes.
- `python3 Scripts/validate_module_docs.py`: **PASS**.
- `Scripts/generate_xcode_project.py`: proyecto Xcode regenerado para build 59 / marketing 0.15.8.
- Parseo aislado de `MultimediaInspectorViewModel.swift`, `SpectrogramView.swift`, `MultimediaWaveformView.swift` y `MultimediaPreviewPlayerView.swift`: **PASS**.

## Cobertura nueva

Se añaden cinco regresiones Swift Testing específicas:

1. el zoom temporal se centra alrededor del playhead y se clampa en los extremos;
2. el pan mueve media ventana y nunca abandona la duración disponible;
3. ampliar y volver a reducir recupera correctamente la vista completa;
4. el sampler de waveform usa únicamente la región visible del timeline;
5. la envolvente admite de forma acotada la nueva resolución máxima de 65.536 buckets.

El verificador estructural protege además que:

- exista `AudioTimelineViewport.swift`;
- waveform y espectrograma consuman el mismo viewport del ViewModel;
- no reaparezcan las antiguas variables de zoom independientes del espectrograma;
- la waveform mantenga el límite de 65.536 buckets;
- ambas superficies expongan los controles compartidos;
- los capítulos se proyecten como marcadores temporales de solo lectura.

## Validación portable confirmada

- El módulo `MultimediaInspectorModule` compila en SwiftPM Linux, incluida la build Release global.
- El zoom/pan del espectrograma reutiliza el modelo ya calculado; no se introduce una nueva ruta FFmpeg/FFT para navegación.
- La waveform recorta y reduce la envolvente ya calculada en memoria.
- No se modifican `MultimediaAudioPreviewService`, `PreviewSourceReplacementGate`, la cadena automática mono-pista ni `OperationCoordinator`.
- No se añaden dependencias, red, permisos, APIs, telemetría ni escrituras sobre el original.

## No validado nativamente en este entorno

`./Scripts/build_macos.sh Release` no puede ejecutarse aquí: el propio script termina indicando que requiere **macOS Apple Silicon con Xcode**. `verify_app_macos.sh`, invocado desde `verify_project.sh`, omite por el mismo motivo la validación real de `ZEUVE.app`.

Por tanto permanecen pendientes en un Mac Apple Silicon:

- compilación SwiftUI/AppKit/AVFoundation real de ZEUVEApp;
- firma, Hardened Runtime y apertura de la aplicación;
- render/gestos/hover reales de Canvas;
- AVAudioEngine y reproducción real con FFmpeg/FFprobe ARM64 empaquetados.

## Validación manual recomendada en macOS

1. Abrir un WAV/MP3 y un vídeo de una pista; confirmar que 0.15.7.0 sigue haciendo espectrograma → sonoridad automáticamente.
2. Reproducir audio y ampliar desde los controles inferiores; confirmar que waveform y espectrograma muestran el mismo intervalo.
3. Ampliar desde la pestaña Espectrograma y confirmar que la waveform adopta inmediatamente el mismo rango temporal.
4. Desplazar izquierda/derecha desde ambas superficies y restaurar **Vista completa**.
5. Confirmar que el zoom se centra alrededor del playhead durante reproducción y pausa.
6. Hacer seek dentro de una zona ampliada y comprobar que la posición absoluta es correcta y que Pausa/Play se conserva según las reglas existentes.
7. Abrir un archivo con capítulos; verificar líneas de capítulo, título/tiempo en hover y ausencia de controles de edición de capítulos.
8. Abrir un audio externo del draft y confirmar que no hereda capítulos del contenedor original.
9. Repetir cambios rápidos de pista y los botones Escuchar/Pausar de Pistas, Espectrograma y barra inferior para descartar regresiones 0.15.2–0.15.6.
10. Con un archivo largo, confirmar que hacer zoom/pan no muestra una nueva operación pesada ni bloquea la interfaz.
