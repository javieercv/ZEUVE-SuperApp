# Informe de implementación — ZEUVE 0.15.7.0

Fecha: 20 de septiembre de 2026.

## Objetivo

Hacer que el Inspector multimedia complete automáticamente espectrograma y sonoridad al abrir archivos con exactamente una pista de audio, manteniendo el flujo manual cuando FFprobe detecta varias pistas para no elegir una de forma silenciosa.

## Implementación

Se añade `MultimediaAutomaticAudioAnalysisPolicy`, una política mínima y testeable basada únicamente en `audioStreams.count`:

- `0`: no se ejecuta análisis de audio;
- `1`: análisis automático;
- `2+`: espectrograma y sonoridad manuales.

`MultimediaInspectorViewModel.open(_:)` conserva FFprobe como primera fase. Después de publicar la inspección técnica, solo en el caso mono-pista inicia `startAutomaticSingleTrackAudioAnalysis()`. La cadena reutiliza `generateSpectrogram()` y `analyzeLoudness(_:)`, por lo que no duplica motores ni lógica de análisis.

El espectrograma se ejecuta primero. La tarea coordinadora espera a que termine la generación actual —incluyendo una regeneración provocada por un cambio de parámetros— y solo después inicia la sonoridad. Cada servicio conserva la propiedad de su propio ciclo `OperationCoordinator`; no se añade paralelismo entre procesos FFmpeg pesados.

## Cancelación y aislamiento de sesión

La cadena automática dispone de `automaticAudioAnalysisSessionID` y `automaticAudioAnalysisTask`. El reset de sesión invalida el identificador y cancela la tarea coordinadora. `cancelCurrentOperation()` cancela también la cadena, además de las tareas y servicios existentes.

Esto evita que una cancelación, cierre o sustitución del archivo permita iniciar la sonoridad después sobre una sesión anterior. Los fallos de espectrograma o sonoridad no eliminan la inspección técnica ya obtenida.

## Comportamiento preservado

- Con varias pistas no cambia la selección manual existente.
- Los botones manuales de generar/regenerar espectrograma y analizar/reanalizar sonoridad permanecen disponibles.
- No se modifica `MultimediaAudioPreviewService`, waveform, identidad estable de filas, playhead compartido ni controles Escuchar/Pausar.
- No se añaden dependencias, motores, red, APIs, telemetría ni escrituras sobre el original.

## Versionado

- ZEUVE: `0.15.7.0`.
- Build: `58`.
- Inspector multimedia: `0.3.7`.
