# Informe de implementación — ZEUVE 0.13.1.0

Fecha: 8 de septiembre de 2026.

## Objetivo

La Fase 1 de mantenimiento del Inspector multimedia se centra en fidelidad del espectrograma, coste de CPU/memoria, cancelación y adopción del nuevo versionado de cuatro componentes. No amplía el alcance funcional ni añade ajustes visibles.

## Cambios realizados

- ZEUVE adopta `MAJOR.MINOR.PATCH.REVISION` como versión canónica. `VERSION` pasa a `0.13.1.0` y el build interno a 48.
- Apple continúa recibiendo `MARKETING_VERSION = 0.13.1`; `ZEUVEReleaseRevision = 0` aporta el cuarto componente y `ZEUVEProductInfo.releaseVersion` compone `0.13.1.0` para la interfaz.
- Inspector multimedia pasa de módulo `0.1.0` a `0.1.1`; su contrato de manifiesto sigue usando SemVer de tres componentes y mantiene `minimumZEUVEVersion = 0.13.0`.
- `SpectrogramRenderMapping` centraliza la transformación lineal/logarítmica del eje de frecuencia. Pantalla, cursor, raster y exportación dejan de mantener fórmulas independientes.
- `SpectrogramRasterizer` crea un buffer RGBA acotado y `SpectrogramExporter` lo convierte a PNG mediante CoreGraphics/ImageIO. La escala activa se entrega explícitamente desde el ViewModel.
- `SpectrogramAccumulator` sustituye el desplazamiento continuo de arrays por índices de lectura y compactación amortizada. Con duración conocida agrega columnas directamente en buckets limitados por `maximumColumns`.
- La opción `Mezcla` procesa cada canal por separado y combina potencia espectral media por bin. Una señal presente en canales con fase opuesta ya no desaparece por cancelación de PCM.
- `SpectrogramFFTAnalyzer` prepara una sola vez la ventana y el setup DFT durante una petición. `SpectrogramFFTProcessor` conserva su API pública para cálculos aislados y tests.
- El Canvas conserva render seguro en el actor/UI y precalcula el mapa fila→bin para no repetir exponenciales/divisiones por cada píxel.
- Cancelar generación o exportación de espectrograma se trata como estado esperado y no como error visible.

## Seguridad y privacidad

No se añaden dependencias, motores, permisos, red, APIs, telemetría ni persistencia. PCM, espectros y raster siguen siendo transitorios. El PNG continúa publicándose mediante el pipeline seguro existente y no puede sobrescribir silenciosamente el original.

## Compatibilidad

La corrección de compilación Swift 6 recibida sobre 0.13.0 se registra bajo el nuevo esquema como revisión técnica `0.13.0.1`. La Fase 1 constituye mantenimiento funcional y por ello avanza `PATCH` a `0.13.1.0`, reiniciando `REVISION` a cero.

El build nativo 0.13.0 corregido fue validado por el usuario en Xcode. La versión 0.13.1.0 requiere una nueva validación nativa en macOS Apple Silicon; el entorno actual solo puede validar SwiftPM portable, scripts y estructura Xcode.
