# Entrega — ZEUVE 0.15.5.0

Fecha: 20 de septiembre de 2026.

## Versión

- ZEUVE: `0.15.5.0`
- Build: `56`
- Inspector multimedia: `0.3.5`

## Cambio entregado

Se corrige la ruta del botón `Escuchar/Pausar` de **Pistas**. Durante reproducción o pausa solo la fuente confirmada por el reproductor (`previewSourceID`) puede considerarse activa. `requestedPreviewSourceID` queda limitado al estado `Cargando…` de una sustitución en curso.

Pistas y Espectrograma usan la misma proyección `previewPlaybackState(for:)` para decidir iniciar, cambiar, pausar o reanudar. No se modifica el servicio de audio.

## Conservado sin cambios

- un único `MultimediaAudioPreviewService`;
- posición temporal compartida;
- continuidad Play/Pausa al cambiar de pista;
- limitación segura al cambiar a una pista más corta;
- seek de waveform conservando pausa;
- waveform y playhead del espectrograma;
- layout vertical adaptable de Espectrograma;
- edición, publicación y protección del archivo original;
- privacidad local y ausencia de red/telemetría;
- dependencias y motores existentes.

## QA

- Swift global: **122/122** tests.
- Inspector multimedia: **67/67** tests.
- Python: **83/83** tests.
- `MultimediaInspectorModuleTests`: build portable PASS.
- ZEUVEApp: **70** fuentes Swift parseadas.
- SwiftPM/Xcode: **10** productos coherentes.
- Verificadores relevantes: PASS.

El build Release completo no terminó dentro del límite temporal del entorno remoto. La build macOS real requiere Apple Silicon + Xcode y queda pendiente, junto con la validación manual de los botones reales de Pistas.

## Entrega web

Al trabajar desde ChatGPT web, la entrega incluye un ZIP limpio del proyecto completo. No debe contener `.build`, `build`, DerivedData, cachés Python, temporales ni datos locales de Xcode.
