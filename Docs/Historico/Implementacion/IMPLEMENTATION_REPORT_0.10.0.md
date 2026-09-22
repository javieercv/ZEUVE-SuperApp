# Informe de implementación 0.10.0

## Cambios principales

- Nuevo modelo común de plataformas, tipos multimedia, secciones de catálogo y motores.
- Enrutador multimotor con yt-dlp, gallery-dl, catálogo Instaloader, extractor HTML y navegador opcional.
- Validación de plataformas, perfiles, enlaces concretos, contenido adulto y directos.
- Catálogo progresivo de Instagram con sesión autorizada, stories, highlights, reels y foto de perfil.
- Descarga directa sin recomprimir, validación de imágenes y metadatos opcionales sanitizados.
- Historial local y búsqueda Wayback de fotos de perfil anteriores.
- Preferencias de catálogo y contenido centralizadas en Ajustes.
- Motores externos versionados y restaurables sin modificar Resources/Engines.

## Dependencias nuevas aprobadas

- gallery-dl 1.32.9.
- Instaloader 4.15.2.
- browser-cookie3 0.20.1 para importación expresa de cookies.
- PyInstaller 6.16.0 solo durante la preparación de binarios ARM64.

No se añadió descarga automática de motores ni navegador al paquete principal.
