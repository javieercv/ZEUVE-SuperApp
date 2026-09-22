# Entrega — ZEUVE 0.18.1.0

Fecha: 21 de septiembre de 2026.

## Estado

Corrección UX/documental del Inspector multimedia implementada y validada en el entorno portable disponible.

- ZEUVE `0.18.1.0`.
- Build `64`.
- Inspector multimedia `0.6.1`.
- Sin dependencias nuevas.
- Sin cambios de red, APIs, telemetría, motores o permisos.
- Sin cambios en edición/remux, análisis DSP, publicación ni protección del original.

## Cambio entregado

El Inspector completa la ayuda contextual exigida por las reglas permanentes de ZEUVE. Ajustes, Resumen, Pistas, Espectrograma, Metadatos y Lote reutilizan `ContextualHelpButton` y los componentes `Help*` compartidos para explicar opciones, métricas y estructuras técnicas que requieren interpretación.

Se añaden explicaciones específicas para sonoridad, señal/clipping, sincronización, espectrograma/FFT/Nyquist, capítulos, attachments/MIME, metadatos, comparación A/B, informes y lote. Los controles evidentes no reciben iconos innecesarios.

La ayuda es exclusivamente de presentación: no ejecuta motores ni análisis, no invalida cachés, no cambia preferencias y no toca archivos. Una regresión automática protege la cobertura y prohíbe que el Inspector introduzca una UI de información paralela.

La documentación del Inspector se consolida además para eliminar descripciones contradictorias heredadas respecto a capítulos, attachments y metadatos editables.

## QA

- Inspector: **99/99 Swift Testing**.
- Swift Testing global: **154/154**.
- XCTest portable: **215 tests**, 0 fallos, 1 omitido por requisito macOS Apple Silicon.
- Python: **107/107**, incluidas **5/5** regresiones nuevas de ayuda contextual.
- Build del target `MultimediaInspectorModule`: PASS.
- Verificadores de integración, estructura, motores, documentación, rendimiento, módulos y manifiestos: PASS.
- ZEUVEApp: **73** fuentes Swift parseadas.
- SwiftPM/Xcode: **10** productos coherentes; proyecto regenerado para marketing `0.18.1` / build `64`.
- Build SwiftPM Release completa: no finalizada dentro del límite temporal remoto; no se observó error antes del corte.
- Build/ejecución Xcode real y motores ARM64: pendientes en macOS Apple Silicon.

Ver `Docs/TEST_RESULTS_0.18.1.0.md` para el detalle y la validación manual recomendada.
