# Informe de implementación — ZEUVE 0.15.9.0

Fecha: 20 de septiembre de 2026.

## Objetivo

Añadir al Inspector multimedia un análisis local de señal para detectar silencios y localizar **Posible clipping**, reutilizando la línea temporal compartida y manteniendo intactos el reproductor, la edición/remux y la protección del original.

## Implementación

Se incorporan `AudioSignalAnalysisConfiguration`, `AudioSignalAnalysisAccumulator` y `AudioSignalAnalysisService`. FFmpeg decodifica únicamente la pista elegida a PCM `float32` (`f32le`) conservando sample rate y número de canales. El PCM se procesa incrementalmente y no se conserva completo en memoria ni se escribe a disco.

El silencio se analiza en ventanas RMS de 10 ms. Una ventana solo se considera silenciosa cuando **todos los canales** están por debajo del umbral. Los valores predeterminados aprobados son -60 dBFS y 0,5 s de duración mínima.

El clipping se trata deliberadamente como indicio: ZEUVE muestra **Posible clipping** cuando un canal presenta varias muestras consecutivas próximas al límite digital. El valor predeterminado es -0,1 dBFS y tres muestras consecutivas. Los eventos cercanos se agrupan y tanto silencios como clippings tienen límites de almacenamiento para proteger memoria/UI, conservando contadores de elementos omitidos.

## Integración

`MultimediaInspectorViewModel` mantiene resultados por `sourceID`. Waveform y espectrograma proyectan los mismos silencios/eventos sobre el `AudioTimelineViewport` compartido; no se introduce otra línea temporal ni otro reproductor. Pistas añade una acción **Señal/Reanalizar señal** y un resumen compacto.

Con exactamente una pista, la cadena automática pasa a ser:

`FFprobe → espectrograma → análisis de señal → sonoridad`.

Las fases se esperan secuencialmente. Con dos o más pistas, el análisis dependiente de pista continúa siendo manual.

## Ajustes, seguridad y cancelación

Los umbrales viven en `MultimediaInspectorPreferences` y se exponen mediante los Ajustes centralizados del Inspector. La decodificación usa el ejecutor seguro existente, argumentos separados, fingerprint antes/después y `OperationCoordinator`. La cancelación invalida la tarea y solicita la cancelación del proceso; no se publica un resultado parcial.

No se añaden dependencias, red, APIs, telemetría, motores ni escrituras sobre el original.

## Versionado

- ZEUVE: `0.15.9.0`.
- Build: `60`.
- Inspector multimedia: `0.3.9`.
