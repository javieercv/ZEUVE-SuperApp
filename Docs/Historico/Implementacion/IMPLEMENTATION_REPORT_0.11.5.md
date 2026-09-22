# Informe de implementación — ZEUVE 0.11.5

## Resultado

El Descargador continúa siendo universal. Instagram recibe una ruta específica aislada para publicaciones y Reels directos, sin alterar las prioridades ya aprobadas de YouTube, TikTok u otras plataformas.

## Enrutado de Instagram

- `instaloader-zeuve 4.15.3-zeuve.2` es el primer motor para `/p/`, `/reel/` y `/reels/` públicos.
- El primer intento nunca recibe cookies. Si no resuelve el contenido, el router continúa con `gallery-dl`, `yt-dlp` y el descubrimiento genérico.
- Una sesión ya autorizada solo puede utilizarse después de agotar las alternativas públicas y cuando el error confirma contenido privado. Login ambiguo, rate limit, 401, 403 o 429 no bastan para forzarla.
- Perfiles, Stories, Destacadas y foto de perfil conservan su flujo de catálogo anterior.

El adaptador emite todos los nodos de cada sidecar. Cada elemento conserva índice, tipo, URL temporal en memoria y extensión expuesta por el CDN. La descarga directa usa además el `Content-Type` de la respuesta como autoridad para evitar extensiones falsas cuando el servidor entrega, por ejemplo, WebP.

## Automático por plataforma

El modo predeterminado es `automatic`. La política se calcula para cada elemento:

- YouTube: audio MP3 a 320 kb/s.
- Cualquier otro origen: mejor contenido original disponible, sin extracción de audio, transcodificación ni contenedor forzado.

Los lotes mixtos combinan ambas decisiones sin compartir una selección global. Las opciones manuales «Vídeo» y «Solo audio» permanecen disponibles y tienen prioridad expresa.

## Compatibilidad y entrega

No se han añadido motores, paquetes, servicios, permisos ni APIs. `gallery-dl` y `yt-dlp` permanecen como fallbacks. La aplicación queda en ZEUVE 0.11.5, build 41, con Descargador universal 0.6.9, dentro de la carpeta activa original y sin generar ZIP.
