# Entrega — ZEUVE 0.17.0.0

Fecha: 21 de septiembre de 2026.

## Estado

Macro-bloque 2 implementado sobre la base 0.16.0.0 corregida y funcional.

- ZEUVE `0.17.0.0`.
- Build `62`.
- Inspector multimedia `0.5.0`.
- Sin dependencias nuevas.
- Sin cambios de red, telemetría ni motores.
- Originales protegidos y publicación únicamente tras validación.

## Cambio entregado

Inspector multimedia amplía su borrador de edición para gestionar capítulos, attachments reales y un conjunto seguro de metadatos multimedia. Los capítulos se generan mediante FFmetadata temporal, los attachments externos se fingerprintan y la extracción usa workspace/publicación segura. Las `attached_pic` continúan protegidas. `Preservar metadatos` ya no elimina capítulos implícitamente.

Planner, builder FFmpeg, validación FFprobe, cálculo de espacio, historial agregado y UI se han ampliado de forma coherente sin sustituir el reproductor ni el bloque de análisis avanzado cerrado en 0.16.0.0.

## QA

La suite específica del Inspector pasa 93/93 pruebas Swift Testing y las pruebas Python pasan 95/95. Los verificadores de estructura, Inspector, documentación e integración SwiftPM/Xcode pasan. La validación final nativa continúa requiriendo macOS Apple Silicon con Xcode; las ejecuciones globales más largas alcanzaron el límite temporal del entorno remoto antes de devolver estado final y se documentan sin marcarlas como PASS.
