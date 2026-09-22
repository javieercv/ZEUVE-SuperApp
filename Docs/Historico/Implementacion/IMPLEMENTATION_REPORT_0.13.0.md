# Informe de implementación — ZEUVE 0.13.0

## Objetivo

ZEUVE 0.13.0 incorpora como sexto módulo oficial **Inspector multimedia** (`MultimediaInspectorModule` 0.1.0), comparte la inspección FFprobe en `ZEUVEEngines` y migra el Conversor universal a esa infraestructura sin modificar su comportamiento funcional.

## Cambios principales

- Nuevo descriptor built-in, navegación y atajo `⌘6`; Historial pasa a `⌘7` para evitar colisión.
- Nuevo módulo `MultimediaInspectorModule` con modelos, compatibilidad, planner, validator, ejecución, publicación, historial y espectrograma.
- UI en `ZEUVEApp/MultimediaInspector` con modo inicial siempre solo lectura, pestañas Resumen/Pistas/Espectrograma/Metadatos y edición explícita mediante borrador.
- Undo/Redo de draft para añadir/eliminar/reordenar pistas y modificar idioma, título y dispositions.
- Política híbrida: vídeo/audio únicamente stream copy; subtítulos convertibles solo con autorización explícita.
- Pipeline seguro de remux con fingerprint, espacio libre, workspace propio, `ExternalProcessRunner`, FFprobe de validación y publicación sin sobrescribir originales.
- `MediaInspectionService` compartido en `ZEUVEEngines`, con parser tolerante y caché temporal invalidada por fingerprint.
- Conversor universal migrado al servicio compartido; se retira su parser FFprobe duplicado sin refactorizaciones ajenas.
- Espectrograma propio mediante FFmpeg → PCM float32 por bloques → Accelerate/vDSP → dB → render nativo, con memoria acotada y exportación PNG.
- Investigación clean-room de Spek 0.8.5 como referencia conceptual; no se incorpora, enlaza, copia ni porta código GPL.
- Nuevo verificador de dominio `Scripts/verify/multimedia_inspector.py` y regresiones de catálogo/QA.
- Versión de ZEUVE elevada de 0.12.4 a 0.13.0; build de proyecto 47.

## Privacidad y seguridad

El módulo no solicita red ni añade telemetría. Los motores son los FFmpeg/FFprobe ya empaquetados. No se añaden dependencias, ejecutables, mecanismos de actualización ni lectura de cookies.

Los originales y entradas externas se tratan como protegidos; las salidas se construyen en temporales propios y se publican con resolución de conflictos. El historial nuevo contiene únicamente contadores/tipo/duración y no conserva rutas, metadata ni datos espectrales.

## Compatibilidad

Los formatos inspeccionables dependen de FFprobe. La edición 0.13.0 se limita explícitamente a MKV, MP4, MOV y WebM y puede bloquear combinaciones que FFmpeg técnicamente abriría si no están validadas por `MediaContainerCompatibilityRegistry`.

## Validación

La validación final portable pasa con 375 tests, `swift build -c release` y `verify_project.sh` correctos. Los resultados exactos y las limitaciones del entorno quedan en `Docs/TEST_RESULTS_0.13.0.md` y `Docs/DELIVERY_0.13.0.md`. La validación final de SwiftUI/AppKit, Accelerate ARM64, firma y motores empaquetados requiere macOS Apple Silicon con Xcode.
