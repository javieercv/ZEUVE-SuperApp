# Entrega — ZEUVE 0.19.0.0

Fecha: 21 de septiembre de 2026.

## Identidad

- ZEUVE `0.19.0.0`.
- Marketing `0.19.0`.
- Build `65`.
- Inspector multimedia `0.7.0`.

## Contenido

Corrección local adicional: el Inspector deja de entrar en recursión al restaurar la velocidad de reproducción durante apertura/cierre de archivos. Se incluye una regresión ejecutable con Combine sobre el observador real; los resultados de la validación de esta corrección se registran por separado en `Docs/TEST_RESULTS_0.19.0.0.md`.

Entrega única del macro-bloque final aprobado del Inspector multimedia: preview de vídeo, subtítulos de preview, edición de streams de vídeo y carátulas, carpetas y edición semántica por lotes, análisis espectral avanzado, OCR bitmap local/revisable, favoritas de configuración, informes schema 3 y ampliación de Ajustes/ayuda contextual.

No se incorpora transcode audiovisual, sistema global de plugins, motores nuevos, dependencias externas, red, telemetría o servicios cloud.

## Calidad y límites

Las suites portables y verificadores disponibles en Linux están recogidos en `Docs/TEST_RESULTS_0.19.0.0.md`. La validación final de UI macOS, VideoToolbox, Vision, firma y motores ARM64 requiere un Mac Apple Silicon y no se marca como ejecutada aquí.

## Entregable

La distribución de ChatGPT web debe producir un ZIP limpio del proyecto completo, sin `.build`, `.swiftpm`, DerivedData, caches, `.DS_Store`, `__MACOSX` ni temporales, conservando permisos ejecutables de scripts y engines. El ZIP debe verificarse antes de entrega.
