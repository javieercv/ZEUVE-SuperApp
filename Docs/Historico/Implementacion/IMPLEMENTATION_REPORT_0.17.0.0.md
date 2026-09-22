# Informe de implementación — ZEUVE 0.17.0.0

Fecha: 21 de septiembre de 2026.

## Objetivo

Cerrar el bloque principal de edición estructural del Inspector multimedia incorporando capítulos, attachments reales y metadatos multimedia seguros al mismo flujo reversible y protegido que ya gestionaba audio y subtítulos.

## Implementación

`MediaEditDraft` incorpora capítulos, attachments y un borrador de metadata. Los capítulos se modelan como marcadores de inicio y su final se deriva del siguiente capítulo o de la duración del medio. En modo edición, la waveform obtiene los marcadores directamente del draft, por lo que Undo/Redo y los cambios temporales se reflejan antes de ejecutar FFmpeg.

Los capítulos se materializan mediante un FFmetadata temporal creado exclusivamente en el workspace de la operación. `FFmpegMediaEditCommandBuilder` coordina ese input con los streams originales/externos, attachments y metadata mediante argumentos separados y conserva vídeo/audio en `-c copy`.

Los streams reales `codec_type=attachment` pueden conservarse, eliminarse o complementarse con archivos externos. Las entradas externas se validan como archivos regulares, se fingerprintan y vuelven a comprobarse antes y después de FFmpeg. Las `attached_pic` permanecen como streams de vídeo protegidos y no entran en la edición de attachments. La extracción usa FFmpeg hacia un workspace temporal y publica después mediante el mecanismo seguro de conflictos de ZEUVE.

Metadatos permite editar un conjunto multimedia seguro y conocido. Los títulos/idiomas de audio y subtítulos reutilizan el estado de las pistas y no crean una segunda fuente de verdad. Tags desconocidos siguen visibles y preservables, pero permanecen de solo lectura. `Preservar metadatos` controla tags; los capítulos siguen siempre el draft.

`MediaEditPlanner`, compatibilidad, cálculo de espacio, `MultimediaEditService` y `MultimediaResultValidator` se amplían para planificar y validar la estructura completa. El resultado se vuelve a inspeccionar con FFprobe y no se publica si capítulos, attachments, metadata o streams no coinciden con el plan.

## Privacidad y seguridad

No se añaden red, APIs, telemetría, dependencias ni motores. El original continúa protegido, no se usa shell y los temporales pertenecen a la operación. El historial guarda únicamente contadores agregados para las nuevas acciones y no títulos, nombres de attachments, valores de metadata ni rutas privadas.

## Versionado

- ZEUVE: `0.17.0.0`.
- Build: `62`.
- Inspector multimedia: `0.5.0`.
