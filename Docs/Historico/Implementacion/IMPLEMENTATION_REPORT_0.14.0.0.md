# Informe de implementación — ZEUVE 0.14.0.0

Fecha: 8 de septiembre de 2026.

## Objetivo

0.14.0.0 amplía **Inspector multimedia** como herramienta técnica de uso diario sin convertirlo en editor temporal. Conserva el motor FFprobe/remux/espectrograma de 0.13.2.0 y mejora presentación, navegación, lectura técnica y previsualización de audio.

## Espectrograma

`SpectrogramView` separa controles de análisis y visualización mediante layout responsive. Los estados vacío y generando se centran como una unidad; el gráfico añade ejes de tiempo/frecuencia, grid, leyenda dB, crosshair y lectura aproximada tiempo/frecuencia/dB. El playhead del reproductor usa el mismo eje temporal y un gesto sobre el gráfico puede iniciar escucha desde la posición inspeccionada.

El cambio no altera `SpectrogramAnalysisPlanner`, el presupuesto de FFT, la caché ni el DSP adaptativo de 0.13.2.0.

## Previsualización de audio

Se añade `MultimediaAudioPreviewService`. FFmpeg decodifica el stream exacto a PCM float32 por pipe y `AVAudioEngine`/`AVAudioPlayerNode` realiza la salida en macOS. Una cola acotada con back-pressure evita decodificar el archivo completo por adelantado. Pause detiene FFmpeg y resume vuelve a abrir desde la posición retenida; seek reinicia desde la nueva posición.

El servicio es actor y no reserva `OperationCoordinator`: reproducción y espectrograma pueden coexistir. La reproducción no publica archivos, no crea historial y no persiste PCM. Las entradas externas del draft vuelven a validar `FileFingerprint` antes de escucharse.

## Canales y lectura técnica

`AudioChannelLayoutResolver` traduce layouts conocidos a nombres de canal seguros y conserva `Canal N` ante ambigüedad. `MediaInspectionTextFormatter` centraliza texto técnico reutilizable para portapapeles local.

Resumen presenta múltiples streams de vídeo y detalle de capítulos, attachments/attached pictures, programs y streams de datos/desconocidos. Metadatos añade filtro local y acciones de copia sin habilitar edición.

## Pistas

Audio puede previsualizarse por fila. En modo edición, audio/subtítulos permiten reordenación drag & drop además de flechas/teclado; el cambio se aplica mediante una única mutación del draft para preservar Undo/Redo. Los drops externos pasan por la misma inspección FFprobe y selección explícita ya existente.

## Versionado

- ZEUVE canónica: `0.14.0.0`.
- `MARKETING_VERSION`: `0.14.0`.
- Revisión bundle: `0`.
- Build: `50`.
- Inspector multimedia: `0.2.0`.

## Límites deliberados

No se añade reproductor universal de vídeo, timeline, cortes, efectos, mezcla creativa, edición de chapters/attachments, batch, A/B, detector de transcodificación ni ajustes visibles.

No se añaden dependencias externas, red, APIs, telemetría ni motores.
