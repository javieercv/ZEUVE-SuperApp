# Documento de compatibilidad del antiguo Descargador de YouTube

El módulo específico `com.zeuve.youtube-downloader` fue sustituido en ZEUVE 0.9.0 por **Descargador universal 0.5.0**, identificado como `com.zeuve.universal-downloader`.

El cambio amplía el funcionamiento a plataformas compatibles, archivos multimedia directos, colecciones y páginas concretas con varios vídeos. Los ajustes, presets, bookmarks e historial anteriores se consultan o migran para no perder la configuración aprobada.

La documentación funcional vigente se encuentra en:

- `Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md`.
- `Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER_PRIVACY_AND_NETWORK.md`.

Los motores siguen siendo yt-dlp, Deno, FFmpeg y FFprobe incluidos en ZEUVE. No se añade navegador automatizado, API externa, actualización automática ni evasión de DRM.
