# Informe de implementación — ZEUVE 0.15.0.0

Fecha: 8 de septiembre de 2026.

## Objetivo

0.15.0.0 convierte **Inspector multimedia** en una sesión de inspección reutilizable y amplía la navegación/análisis de audio sin convertir el módulo en editor temporal. La base sigue siendo FFprobe + FFmpeg local, el espectrograma optimizado de 0.13.2.0 y el reproductor auxiliar introducido en 0.14.0.0.

## Sesión reutilizable

La cabecera permite **Analizar otro archivo…** y **Cerrar análisis** sin reiniciar ZEUVE. Cambiar/cerrar archivo pasa por una única rutina de limpieza de sesión que detiene preview, waveform, espectrograma y sonoridad, limpia draft/plan/resultados propios del archivo y conserva preferencias. Un borrador modificado sigue exigiendo confirmación antes de descartarse.

Se elimina además la llamada duplicada a `stopPreview()` heredada de la base 0.14.0.0.

## Waveform como scrubber

El slider temporal del reproductor se sustituye por una waveform bipolar real. `MultimediaWaveformAccumulator` conserva por intervalo:

- máximo positivo;
- mínimo negativo;
- energía RMS opcional.

La parte inferior no es una copia invertida de la superior. En mezcla multicanal se preservan extremos y energía por frame sin downmix PCM susceptible a cancelación de fase.

La waveform se genera incrementalmente desde PCM, queda acotada a un máximo de buckets y no conserva el PCM. La vista puede representarse como Compacta, Equilibrada o Detallada; Picos o Picos + energía; con guía central opcional. Estos cambios visuales reutilizan el mismo modelo y no relanzan FFmpeg.

Durante el cierre de QA se corrigió también la compactación cuando la duración del stream es desconocida: al subir de nivel de resolución, un bucket impar se conserva como bucket parcial del nivel siguiente y los nuevos buckets duplican su anchura temporal. Así la compactación no deforma la posición horizontal de eventos tardíos.

## Posición temporal compartida

Waveform, reproductor y espectrograma usan la misma posición de preview. El usuario puede hacer seek en waveform o espectrograma y cambiar de pista conservando el instante actual cuando la duración del nuevo stream lo permite. Los capítulos con timestamp válido pueden navegar a esa misma posición.

## Sonoridad bajo demanda

`AudioLoudnessAnalysisService` usa el FFmpeg empaquetado y EBU R128 para obtener, cuando están disponibles:

- Integrated Loudness (LUFS);
- Loudness Range (LU);
- True Peak (dBTP);
- Sample Peak (dBFS).

No se ejecuta automáticamente al abrir un archivo. Es local, cancelable y reserva `OperationCoordinator` porque puede recorrer una pista completa.

## Timestamps y sincronización técnica

`AudioTimingAnalyzer` presenta `start_time`, offsets respecto al vídeo principal/contenedor y diferencias de duración. Son datos técnicos: ZEUVE no transforma una diferencia en un diagnóstico automático de desincronización.

## Informes técnicos

`MultimediaTechnicalReportExporter` genera TXT, Markdown o JSON únicamente a petición del usuario. La publicación usa las protecciones existentes y el contenido omite rutas completas del origen, fingerprints e identificadores internos de preview.

## Ajustes centralizados

`MultimediaInspectorPreferences` se persiste mediante `SettingsRepository` y aparece dentro del sistema central de Ajustes de ZEUVE. Incluye:

- estilo/representación/guía de waveform;
- volumen inicial y salto rápido del reproductor;
- FFT, ventana, escala, rango y canal inicial;
- pestaña inicial y detalle técnico;
- preservación de metadatos;
- sufijo de salida y contenedor preferido.

La restauración propia y la restauración global de ZEUVE recuperan los defaults del Inspector sin modificar archivos ni sesiones anteriores.

## Versionado

- ZEUVE canónica: `0.15.0.0`.
- `MARKETING_VERSION`: `0.15.0`.
- Revisión bundle: `0`.
- Build: `51`.
- Inspector multimedia: `0.3.0`.

## Límites deliberados

No se añade reproductor universal de vídeo, timeline, cortes, efectos, mezcla creativa ni edición temporal. Tampoco se añaden dependencias externas, red, telemetría, APIs o motores.
