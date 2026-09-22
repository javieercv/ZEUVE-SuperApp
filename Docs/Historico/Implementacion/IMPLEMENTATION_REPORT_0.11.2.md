# Informe de implementación — ZEUVE 0.11.2

Fecha: 22 de agosto de 2026.

## Objetivo aprobado

Restaurar el carácter universal del Descargador y comprobarlo con el TikTok público `7661387983458700566`, manteniendo YouTube y las garantías de privacidad existentes.

## Causa comprobada

- yt-dlp 2026.06.09 no podía analizar el enlace de TikTok probado.
- gallery-dl 1.32.9 sí resolvía el contenido, pero ZEUVE usaba opciones inexistentes y los identificadores de un protocolo anterior.
- TikTok `/video/` se clasificaba como página genérica y no recibía la estrategia social adecuada.
- La primera URL temporal del CDN podía responder HTTP 403; reutilizarla fuera de gallery-dl eliminaba sus rutas de respaldo internas.
- Los motores sociales estaban declarados, pero no incluidos como requisito efectivo de toda compilación.

## Cambios realizados

- TikTok vídeo y foto se clasifican directamente y enrutan a gallery-dl, con yt-dlp y el extractor genérico como respaldos.
- Los comandos usan `--config-ignore` y `--http-timeout`.
- El parser acepta Directory=2, URL=3 y Queue=6, además del formato heredado.
- Cada entrada conserva como origen la página pública estable; gallery-dl vuelve a resolverla durante la descarga y selecciona el elemento mediante `--range`.
- gallery-dl 1.32.9 e instaloader-zeuve 4.15.3-zeuve.1 ARM64 están incluidos, registrados como obligatorios, firmados y verificados.
- La firma de esos binarios PyInstaller limita la excepción de validación de bibliotecas a sus procesos auxiliares, sin aplicarla a ZEUVE.app.
- Terminal y Xcode comprueban los motores sociales antes de compilar, sin descargarlos automáticamente.
- ZEUVE se eleva a 0.11.2, build 38, y el Descargador universal a 0.6.6.

## Privacidad

La corrección no añade cuentas, APIs, proxies, telemetría ni permisos. Las URLs firmadas y las cabeceras privadas permanecen efímeras y no se guardan en planes persistidos, historial, metadatos, registros o entregas.
