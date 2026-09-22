# Entrega — ZEUVE 0.3.0

Fecha: 2 de julio de 2026.

## Resumen

ZEUVE 0.3.0 mejora la claridad de la interfaz sin cambiar la arquitectura ni añadir dependencias. El modo simple de vídeo permite elegir el formato final y usa MP4 por defecto. El modo audio usa MP3 por defecto y muestra la calidad en kbps únicamente cuando MP3 está seleccionado. El nombre inicial pasa a ser Título.

También se incorpora un componente común de ayuda contextual con iconos de información en el Descargador, Organizador y Ajustes. Las explicaciones están en español, indican consecuencias relevantes y muestran una recomendación cuando corresponde.

## Compatibilidad

- Los presets antiguos siguen cargándose.
- El esquema de presets pasa de 1 a 2.
- Las configuraciones que no incluyen `mp3Bitrate` reciben 320 kbps sin alterar el resto de sus valores.
- No se modifican los motores ni se añaden dependencias.
- Las descargas continúan siendo secuenciales.

## Versión

- Versión anterior: 0.2.4, build 10.
- Versión nueva: 0.3.0, build 11.
- Motivo: nuevas opciones visibles y sistema general de ayuda contextual.

## Pruebas

- 69 pruebas Swift superadas.
- 11 pruebas de scripts Python superadas.
- Compilación SwiftPM Release completada.
- Análisis sintáctico de todos los archivos SwiftUI completado.
- Manifiestos JSON, documentación y proyecto Xcode verificados.
- ZIP final comprobado mediante prueba de integridad y revisión de exclusiones.

Los resultados y las limitaciones completas figuran en `Docs/TEST_RESULTS_0.3.0.md`.

## Limitaciones

La aplicación macOS no puede compilarse ni abrirse con Xcode en el entorno Linux utilizado para preparar esta entrega. La prueba manual final de los popovers, VoiceOver, teclado y flujo visual debe realizarse en un Mac Apple Silicon.
