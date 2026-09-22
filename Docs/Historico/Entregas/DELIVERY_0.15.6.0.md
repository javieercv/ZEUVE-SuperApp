# Entrega — ZEUVE 0.15.6.0

Fecha: 20 de septiembre de 2026.

## Estado

Corrección implementada y validada en el entorno portable disponible.

- ZEUVE `0.15.6.0`.
- Build `57`.
- Inspector multimedia `0.3.6`.
- Sin dependencias nuevas.
- Sin cambios de red, privacidad, motores o originales.

## Cambio entregado

Las filas de audio y subtítulos de solo lectura mantienen ahora un UUID estable durante toda la inspección. Las publicaciones frecuentes de `previewPosition` ya no reconstruyen `MediaEditableTrack` ni reemplazan los botones de Pistas mientras el usuario interactúa con ellos.

La arquitectura de reproducción de 0.15.3–0.15.5 se conserva: un solo servicio/estado de preview, tiempo compartido y continuidad de pista/Play-Pausa.

## QA

- Inspector: 67/67 tests Swift Testing.
- Scripts: 85/85 tests Python.
- Suite Swift global: 122/122 Swift Testing.
- ZEUVEApp: 70 fuentes parseadas.
- Integración SwiftPM/Xcode: 10 productos coherentes.
- Verificadores de documentación, estructura e Inspector: PASS.
- Build Release global: no completado por límite del entorno.
- Build macOS/Xcode: pendiente en macOS Apple Silicon.

Ver `Docs/TEST_RESULTS_0.15.6.0.md` para el detalle y la validación manual requerida.
