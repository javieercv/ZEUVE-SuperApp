# Informe de implementación — ZEUVE 0.15.8.0

Fecha: 20 de septiembre de 2026.

## Objetivo

Unificar la navegación temporal del Inspector multimedia para que waveform y espectrograma representen la misma ventana de tiempo, añadir zoom/pan reutilizable a la waveform, aumentar su resolución de navegación sin retener PCM completo y mostrar capítulos como referencias temporales de solo lectura.

## Viewport temporal compartido

Se añade `AudioTimelineViewport` en `MultimediaInspectorModule` como modelo puro y testeable. `MultimediaInspectorViewModel` conserva una única instancia para toda la sesión y deriva de ella el intervalo visible usado por waveform y espectrograma.

Los controles de ambas superficies llaman a las mismas operaciones del ViewModel:

- ampliar;
- reducir;
- desplazar media ventana hacia atrás o delante;
- restaurar **Vista completa**.

Cuando existe una sesión de preview, el zoom se centra alrededor del playhead vigente. El pan y el zoom se limitan a la duración disponible y el viewport vuelve a estado completo cuando el intervalo ampliado alcanza de nuevo toda la fuente.

El espectrograma continúa reutilizando el modelo completo ya calculado. Cambiar el viewport solo ejecuta `cropped(...)` y la reinterpretación del rango dinámico; no relanza FFmpeg ni FFT.

## Waveform de resolución acotada

La petición y el acumulador de waveform elevan el límite máximo de 4.096 a **65.536 buckets**. Sigue siendo una envolvente resumida de mínimo, máximo y RMS: no se conserva PCM completo.

`MultimediaWaveformRenderSampler` recibe ahora un `AudioTimelineVisibleRange`, recorta los buckets correspondientes a ese intervalo y solo después reduce el resultado al número de barras que necesita la vista. Por tanto, zoom y desplazamiento reutilizan la envolvente ya generada y no vuelven a decodificar el archivo.

## Marcadores de capítulos

Los capítulos obtenidos por FFprobe se proyectan mediante `AudioTimelineChapterMarker` sobre la waveform de la fuente original. El hover muestra el título y el instante preciso cuando el puntero está próximo al marcador.

Los marcadores son estrictamente informativos. No se habilita edición, reordenación ni escritura de capítulos y no se muestran sobre un audio externo del draft, porque esos capítulos pertenecen al contenedor original.

## Reproductor y comportamiento preservado

No se modifica `MultimediaAudioPreviewService`, `PreviewSourceReplacementGate`, la selección real de pistas ni la continuidad Play/Pausa/seek estabilizada en 0.15.2–0.15.6. El playhead publicado por el reproductor sigue siendo la única referencia temporal de reproducción y se proyecta sobre la ventana visible compartida.

Tampoco cambia el análisis automático mono-pista de 0.15.7.0: con una pista sigue ejecutando espectrograma y después sonoridad de forma secuencial; con varias pistas conserva el flujo manual.

## Privacidad, procesos y dependencias

- Sin dependencias nuevas.
- Sin red, APIs, telemetría ni permisos adicionales.
- Sin nuevas ejecuciones de FFmpeg/FFprobe para zoom/pan.
- Sin persistencia de waveform, viewport, capítulos o PCM.
- Sin cambios de publicación, remux ni archivos originales.

## Versionado

- ZEUVE: `0.15.8.0`.
- Build: `59`.
- Inspector multimedia: `0.3.8`.
