# Informe de implementación — ZEUVE 0.11.3

Fecha: 22 de agosto de 2026.

## Objetivo aprobado

Corregir el caso en el que la descarga de un TikTok parecía terminar correctamente, pero no guardaba ningún archivo. El enlace reportado fue `https://www.tiktok.com/@l000rna/video/7675703483303071009` y no se dispuso de un registro de la ejecución original.

## Causa comprobada en el código y el motor incluido

- El binario incluido es `gallery-dl 1.32.9`. Su extractor de TikTok utiliza por defecto URLs directas del CDN y sus rutas de respaldo internas; no necesita integrar el módulo Python de yt-dlp para esa ruta.
- gallery-dl puede resolver una extracción como «sin resultados» y terminar con código cero, sin dejar archivos.
- `YouTubeDownloadService` interpretaba el código cero como éxito y no comprobaba la existencia de salida dentro de la rama gallery-dl.
- Aunque el enrutador declaraba yt-dlp como respaldo, no existía un cambio de motor durante la etapa de descarga cuando gallery-dl fallaba o terminaba vacío.
- El resumen final no diferenciaba con suficiente claridad una operación completamente fallida de una descarga completada.

## Cambios realizados

- La ruta gallery-dl comprueba inmediatamente los archivos candidatos regulares y no vacíos del workspace.
- Un TikTok solo se da por descargado cuando el proceso termina correctamente y existe al menos un archivo candidato.
- Si gallery-dl falla o termina vacío, se valida y limpia el workspace de la operación antes de reintentar la URL pública estable con el yt-dlp incluido.
- El respaldo yt-dlp también debe terminar correctamente y producir al menos un archivo antes de continuar con FFprobe y la publicación segura.
- Los dos fallos se clasifican en un único resultado accionable, con referencia técnica saneada y sin registrar la salida cruda de los motores.
- El resumen muestra «La descarga ha fallado», avisa de que no se guardó ningún archivo, presenta la referencia y ofrece abrir los registros.
- Se añadieron pruebas con el enlace reportado para la política de respaldo, conservación de la URL estable, salida vacía y estado de fallo total.
- ZEUVE se eleva a 0.11.3, build 39, y el Descargador universal a 0.6.7.

## Alcance y privacidad

El cambio está limitado a la etapa de descarga de TikTok. No modifica el enrutado de otras plataformas, no cambia los binarios fijados y no añade dependencias, servicios, APIs, proxies, permisos ni telemetría. Las URLs firmadas, cookies y cabeceras privadas siguen fuera de planes persistidos, historial, metadatos y registros.
