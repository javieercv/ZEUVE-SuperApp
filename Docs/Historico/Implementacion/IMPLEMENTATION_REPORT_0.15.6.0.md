# Informe de implementación — ZEUVE 0.15.6.0

Fecha: 20 de septiembre de 2026.

## Objetivo

Corregir el botón `Escuchar/Pausar` de la pestaña Pistas del Inspector multimedia, que podía dejar de responder correctamente una vez iniciada la reproducción aunque el transporte compartido, el playhead y los controles de otras superficies funcionasen.

## Causa real localizada

En modo solo lectura, `MultimediaInspectorViewModel.audioTracks` y `subtitleTracks` reconstruían `MediaEditableTrack` directamente desde `inspection` en cada lectura. `MediaEditableTrack.from(...)` asigna por defecto un `UUID()` nuevo. Como `previewPosition` se publica aproximadamente cada 100 ms durante la reproducción, SwiftUI reevaluaba Pistas continuamente y recibía una colección con identidades distintas en cada render.

`MultimediaTracksView` usa `track.id` como identidad de `ForEach`, por lo que SwiftUI podía destruir y recrear una fila y su botón entre el inicio y el final de un clic. Esto explicaba que el primer `Escuchar` funcionase antes del refresco continuo y que `Pausar` fuese errático después, incluso cuando el reproductor inferior había iniciado la sesión.

## Implementación

`MultimediaInspectorViewModel` mantiene ahora dos snapshots de sesión:

- `inspectionAudioTracks`;
- `inspectionSubtitleTracks`.

Se construyen una única vez cuando una inspección FFprobe válida se acepta. `audioTracks` y `subtitleTracks` usan el draft mientras existe edición y, en modo lectura, devuelven esos snapshots estables.

Los snapshots se limpian al cerrar o fallar una inspección y se reconstruyen al abrir otro archivo o al publicar correctamente un resultado editado. No se ha modificado `MultimediaAudioPreviewService`, `PreviewSourceReplacementGate`, waveform, espectrograma ni el transporte común.

## Regresión protegida

`Scripts/verify/multimedia_inspector.py` impide volver a calcular pistas desde `inspection` en las propiedades consultadas por SwiftUI y exige la existencia/limpieza de los snapshots estables.

`Tests/ScriptTests/test_multimedia_inspector_track_identity.py` añade dos pruebas estructurales específicas para esta política.

## Versionado

- ZEUVE: `0.15.6.0`.
- Build: `57`.
- Inspector multimedia: `0.3.6`.

## Privacidad y archivos

No hay cambios de red, telemetría, logs, motores, dependencias, permisos ni persistencia. Los UUID permanecen exclusivamente en memoria y los archivos originales siguen protegidos.
