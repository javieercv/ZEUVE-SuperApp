# Informe de implementación — ZEUVE 0.15.4.0

Fecha: 19 de septiembre de 2026.

## Objetivo

Corregir la última asimetría observada en los botones `Escuchar/Pausar` del Inspector multimedia después de 0.15.3.0: el audio, el tiempo y la pista ya estaban compartidos correctamente, pero el botón de la misma pestaña que iniciaba la reproducción podía no ejecutar Pausa mientras el control equivalente de la otra pestaña sí funcionaba.

## Causa

No existía un segundo reproductor ni un fallo del motor de audio. `MultimediaAudioPreviewService` seguía siendo único y el estado global era correcto.

La divergencia estaba en la capa UI/ViewModel: Pistas y Espectrograma resolvían de forma distinta si su fuente concreta era la sesión activa. Durante el breve tránsito entre `requestedPreviewSourceID`, `previewSourceID` y `activePreviewSource`, una vista podía considerar que debía volver a entrar por una ruta de inicio/cambio en lugar de delegar en Pausa. Cambiar de pestaña daba tiempo a que la identidad confirmada se estabilizara, lo que explica que el control de la otra pestaña sí funcionara.

## Corrección

`MultimediaInspectorViewModel` incorpora una única resolución de estado por fuente mediante `previewPlaybackState(for:)` y dos helpers privados compartidos por las rutas de Pistas y Espectrograma.

La identidad se resuelve con prioridad estricta:

1. `requestedPreviewSourceID` mientras existe una sustitución pendiente;
2. `previewSourceID` cuando la fuente ya está confirmada;
3. `activePreviewSource` únicamente como respaldo transitorio.

`previewTrack(_:)` y `previewSelectedSpectrogram(...)` usan la misma función para decidir si el clic actual debe pausar/reanudar la sesión existente o iniciar/cambiar de fuente.

`MultimediaTracksView` obtiene `Cargando…`, `Pausar` y `Escuchar` desde `previewPlaybackState(for:)`. `SpectrogramView` hace lo mismo y su botón deja de decidir localmente entre `togglePreviewPause()` y `previewSelectedSpectrogram(...)`: delega siempre en el ViewModel.

## Elementos no modificados

No se ha cambiado `MultimediaAudioPreviewService`, `PreviewSourceReplacementGate`, FFmpeg, AVAudioEngine, waveform, seek, continuidad temporal, cambio de pista, layout del Espectrograma, sonoridad, edición estructural ni publicación de archivos.

Por tanto se conservan las correcciones de 0.15.3.0: posición compartida, Play/Pausa al cambiar de pista, seek pausado, clamp de pistas más cortas y layout vertical flexible.

## Regresión estructural

`Scripts/verify/multimedia_inspector.py` comprueba ahora que:

- existe una resolución central de estado/identidad en el ViewModel;
- la fuente solicitada tiene prioridad durante transiciones;
- Pistas y Espectrograma consumen la misma resolución;
- Espectrograma no vuelve a introducir una decisión local de `togglePreviewPause()`.

## Privacidad y dependencias

No se añaden dependencias, red, telemetría, permisos, persistencia ni modificaciones de archivos originales. La previsualización continúa siendo local y efímera.

## Versionado

- ZEUVE: `0.15.4.0`.
- Build: `55`.
- Inspector multimedia: `0.3.4`.
- `MARKETING_VERSION`: `0.15.4`.
- `ZEUVEReleaseRevision`: `0`.
