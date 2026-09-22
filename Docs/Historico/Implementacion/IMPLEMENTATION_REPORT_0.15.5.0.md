# Informe de implementación — ZEUVE 0.15.5.0

Fecha: 20 de septiembre de 2026.

## Objetivo

Corregir la respuesta del botón `Escuchar/Pausar` de la pestaña **Pistas** del Inspector multimedia sin modificar el motor de audio ni las correcciones ya validadas de continuidad temporal, cambio de pista y layout.

Los casos reportados eran:

1. Pistas → `Escuchar` funcionaba, pero el mismo botón no pausaba de forma fiable después.
2. Reproducción iniciada desde el reproductor inferior → `Pausar` desde Pistas tampoco respondía de forma fiable.
3. El tiempo, la pista reproducida y la sincronización global ya eran correctos.

## Causa

0.15.4.0 centralizó la presentación de los botones, pero `previewControlMatches(_:)` daba prioridad absoluta a `requestedPreviewSourceID` siempre que existiera. Esa identidad representa una solicitud/transición y no debe gobernar un transporte ya estable.

Además, `previewTrack(...)` y `previewSelectedSpectrogram(...)` conservaban una segunda decisión interna (`shouldTogglePreviewControl`) paralela a `previewPlaybackState(for:)`. Aunque ambas partían del mismo estado, podían resolver de forma distinta un clic durante una transición residual.

## Corrección aplicada

`MultimediaInspectorViewModel` distingue ahora dos fases:

- `.loading`: la fuente relevante es exclusivamente `requestedPreviewSourceID` y el control muestra `Cargando…`;
- `.playing`, `.paused` y `.finished`: la fuente relevante es exclusivamente `previewSourceID`, confirmada por el snapshot de `MultimediaAudioPreviewService`.

`previewTrack(...)` y `previewSelectedSpectrogram(...)` consultan directamente `previewPlaybackState(for:)` para decidir la acción:

- fuente confirmada + `.playing` → pausa;
- fuente confirmada + `.paused`/`.finished` → reanuda;
- misma fuente en `.loading` → ignora una orden duplicada;
- otra fuente o estado inactivo → inicia/cambia preview.

Se elimina `shouldTogglePreviewControl`, evitando una segunda regla paralela.

## Archivos de producto modificados

- `Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift`
- `Sources/MultimediaInspectorModule/Resources/manifest.json`
- `Scripts/generate_xcode_project.py`
- `ZEUVE.xcodeproj/project.pbxproj`
- `VERSION`

No se ha modificado `MultimediaAudioPreviewService.swift`, `PreviewSourceReplacementGate`, el pipeline FFmpeg/AVAudioEngine, waveform, espectrograma, layout, edición o publicación.

## QA y guardarraíles

- `Scripts/verify/multimedia_inspector.py` comprueba la separación entre fuente solicitada y confirmada y prohíbe reintroducir una segunda decisión de toggle.
- La expectativa de manifiesto del módulo se actualiza a `0.3.5`.
- El versionado pasa a ZEUVE `0.15.5.0`, build `56`, Inspector multimedia `0.3.5`.

## Privacidad, archivos y dependencias

No hay dependencias nuevas, red, APIs, telemetría, persistencia adicional, logs privados, cambios de permisos ni escrituras sobre archivos originales. La corrección opera únicamente sobre identificadores efímeros en memoria del ViewModel.
