# Informe de implementación — ZEUVE 0.15.3.0

Fecha: 19 de septiembre de 2026.

## Objetivo

Corregir tres regresiones del Inspector multimedia sin ampliar alcance ni cambiar arquitectura: todos los controles de reproducción deben gobernar una sola sesión, el cambio de pista debe conservar posición y Play/Pausa, y el Espectrograma debe ceder altura antes de ocultar el reproductor inferior.

## Reproductor compartido

La auditoría confirmó que ya existía un único `MultimediaAudioPreviewService`, propietario exclusivo de `AVAudioEngine`/`AVAudioPlayerNode`, y un único estado observable en `MultimediaInspectorViewModel`. No se crearon nuevos reproductores ni estados `isPlaying` por vista.

`MultimediaAudioPreviewService.replaceSource` incorpora `preservePlaybackState`. Antes de retirar la sesión actual se captura su estado real mediante `PreviewPlaybackContinuity`. Si la sesión estaba reproduciendo o cargando, la sustitución conserva reproducción. Si estaba pausada o finalizada, la nueva fuente queda preparada sin arrancar FFmpeg ni AVAudioEngine. El `PreviewSourceReplacementGate` y la limpieza atómica de 0.15.2.0 se conservan.

`seek` admite la misma política. La waveform usa `preservePlaybackState: true`, por lo que mover el playhead estando pausado mantiene Pausa. La ruta de reinicio desde `finished` conserva la semántica anterior y reproduce desde cero.

## Sincronización de Pistas y Espectrograma

`selectedAudioStreamIndex` considera ahora una sesión existente si hay fuente confirmada, fuente solicitada o fuente activa interna. Así una selección A→B→C durante `loading` no pierde C por depender exclusivamente de `previewSourceID`.

Los cambios de pista desde Pistas y desde el selector del Espectrograma pasan por la misma sustitución con continuidad de estado. El botón `Escuchar/Pausar` del Espectrograma deja de llamar a `previewSelectedSpectrogram(at: 0)` y utiliza la posición/estado compartidos. El clic sobre el gráfico conserva su comportamiento explícito de reproducir desde el instante pulsado.

## Layout del Espectrograma

`SpectrogramView.swift` eliminó los tres `frame(minHeight: 420)` aplicados al eje, raster y leyenda. Esas piezas usan ahora la altura flexible disponible. Los controles superiores mantienen tamaño intrínseco y el reproductor inferior, situado fuera de la pestaña en el `VStack` del Inspector, deja de ser empujado fuera de la ventana por un mínimo rígido del gráfico.

No se añadió `ScrollView` global y no se modificó el layout de Resumen, Pistas o Metadatos.

## Tests y verificadores

Se añadieron regresiones para:

- continuidad de intención entre `.playing`, `.loading`, `.paused` y `.finished`;
- clamp de un seek de 82 s a una pista destino de 30 s;
- ausencia del reinicio `at: 0` en el botón del Espectrograma;
- ausencia del mínimo rígido de 420 pt;
- reconocimiento de una sustitución pendiente;
- uso de seek que conserva Play/Pausa.

## Privacidad y alcance

No se añadieron dependencias, red, telemetría, motores, permisos, persistencia, rutas privadas ni escritura sobre originales. La reproducción sigue siendo local y efímera. No se modificaron DSP, sonoridad, remux, edición estructural ni otros módulos.

## Versionado

- ZEUVE: `0.15.3.0`.
- Build: `54`.
- Inspector multimedia: `0.3.3`.
- `MARKETING_VERSION`: `0.15.3`.
- `ZEUVEReleaseRevision`: `0`.
