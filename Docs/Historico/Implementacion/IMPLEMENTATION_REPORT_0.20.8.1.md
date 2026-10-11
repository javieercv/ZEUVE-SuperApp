# Continuación de correcciones del Descargador

11/10/2026 · ZEUVE 0.20.8.1, marketing 0.20.8/build 75 · Descargador 0.7.5 · instaloader-zeuve 4.15.3-zeuve.4 sobre upstream 4.15.3. Base remota `ff89299275d437657437452f4e3c12a4efa5b2ce`.

El usuario pide continuar solucionando las fallidas y parciales después de revisar la QA real. Se mantiene el alcance aprobado, la sesión Brave limitada a Instagram/objetivo original y Reddit online aplazado.

Cambios: tipo de audio conservado en yt-dlp; audio TikTok MP4 anunciado como MP3 normalizado a M4A tras FFprobe sin modificar bytes; variantes X agrupadas por identidad CDN aunque otro motor las etiquete genéricas; Tumblr resuelto desde bloques del post concreto en HTML público; recuerdo de sesión persistido desde el panel y guardado de cookies ya importadas; eliminación de cookies anónimas duplicadas y cabecera CSRF coherente en el adaptador; validación limitada por HTTP 429 detenida sin reintentos largos/fallback en esa rama.

Sin nuevas dependencias upstream, permisos, endpoints, SQLite ni ZIP. Se conserva validación estricta, conflictos, temporales propios, coordinación y cancelación. El motor propio se reconstruye con las dependencias ya fijadas. La revisión personalizada se incluye mediante una plantilla de Info.plist y se contrasta con VERSION en el bundle real antes de aceptar el build. La [QA nativa](../Pruebas/DOWNLOADER_QA_0.20.8.1_20261011.md) acepta cinco fallos corregidos; los límites de Instagram/Threads se conservan explícitos en pruebas y entrega.
