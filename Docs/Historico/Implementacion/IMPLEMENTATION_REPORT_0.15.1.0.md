# Informe de implementación — ZEUVE 0.15.1.0

Fecha: 9 de septiembre de 2026.

## Objetivo

Corregir dos regresiones del reproductor del Inspector multimedia sobre la base 0.15.0.0 validada por el usuario en Xcode:

1. pulsar **Escuchar** en otra pista de audio no sustituía de forma fiable el stream activo;
2. al hacer seek en la waveform, el playhead podía volver brevemente a la posición anterior antes de adoptar el destino.

## Causa técnica

La selección de pista y la fuente realmente activa del preview estaban coordinadas por rutas distintas. `selectedAudioStreamIndex` podía programar un `stopPreview()` separado antes de iniciar el nuevo stream y `stopPreview()` ejecutaba la parada del actor de audio en una tarea asíncrona independiente. Esto permitía que start/stop de peticiones consecutivas compitiesen.

El seek actualizaba la posición real solo después de que `MultimediaAudioPreviewService.seek` terminase. Además, el monitor de snapshots podía publicar todavía una posición perteneciente a la reproducción anterior. En la vista, el estado local del drag se liberaba antes de pedir el seek.

## Implementación

### Sustitución de pista

`MultimediaInspectorViewModel` usa ahora `previewOperationID` como generación de operación. Las peticiones de start, stop, pause/reanudación y seek:

- cancelan la envoltura anterior;
- esperan su finalización lógica antes de entrar en la siguiente operación;
- invalidan el monitor anterior;
- solo publican snapshots cuando su `operationID` sigue siendo la vigente.

Pulsar **Escuchar** en una pista original sincroniza también `selectedAudioStreamIndex` mediante una ruta que evita disparar efectos laterales recursivos. La selección del Espectrograma usa la misma sustitución sin programar un stop independiente.

El `FFmpegAudioPreviewCommandBuilder` continúa usando argumentos separados y `-map 0:<streamIndex>` exacto. Se añadió una regresión A→B que comprueba `0:1` y `0:4` manteniendo `-ss 12.500000`.

### Seek optimista

`seekPreview(to:)` publica `previewPosition = target` de forma síncrona antes de iniciar el reinicio asíncrono de FFmpeg/AVAudioEngine. El monitor previo se cancela y los snapshots solo se aceptan si pertenecen a la generación actual.

`MultimediaWaveformView` solicita el seek antes de liberar `dragPosition`, de modo que no existe un frame en el que la vista vuelva a leer la posición anterior.

## Alcance protegido

No se han cambiado:

- DSP ni cálculo de waveform/espectrograma;
- sonoridad;
- edición estructural/remux;
- motores ni versiones de FFmpeg/FFprobe;
- dependencias;
- red, telemetría o historial;
- política de originales en solo lectura.

## Versionado

- ZEUVE: `0.15.1.0`.
- Build: `52`.
- Inspector multimedia: `0.3.1`.
- `MARKETING_VERSION`: `0.15.1`.
- `ZEUVEReleaseRevision`: `0`.
