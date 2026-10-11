# Investigación de Instagram y Threads — 11/10/2026

Base ZEUVE remota `4c95ab1911ef32bd60a01dfe61a083e33aeacdcc`. Consultas controladas con TLS verificado, sin proxy nuevo, servicios de terceros ni ejecución de código descargado. Las respuestas con URLs firmadas, perfil privado y cookies permanecen fuera del repositorio.

## Fuentes primarias y contraste

- [Instaloader PR 2652](https://github.com/instaloader/instaloader/pull/2652): migración de metadata de perfil a GraphQL tras fallos de `web_profile_info`. En Instaloader 4.15.3 la obtención de metadata autenticada ya contiene esta ruta, pero `Profile.from_username` sigue empezando por el endpoint anterior. [Código](https://github.com/instaloader/instaloader/blob/da65e697a021be94e6ae20e33145fbf488351a73/instaloader/structures.py).
- [Incidencia 2726](https://github.com/instaloader/instaloader/issues/2726): usuarios reportan 429 desde la primera petición. No prueba que la sesión de ZEUVE sea inválida ni permite atribuir el rechazo únicamente a la IP.
- [instagram_monitor: notas de versión](https://github.com/misiektoja/instagram_monitor/blob/main/RELEASE_NOTES.md) y [resolución de perfiles](https://github.com/misiektoja/instagram_monitor/blob/2c29cd4ee27876698a110338807f3d22347b742a/instagram_monitor.py): búsqueda de ID con coincidencia exacta y metadata GraphQL para sesión. Se estudia el mecanismo; no se incorpora su código ni sus otras funciones.
- [gallery-dl: extractor Instagram](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/gallery_dl/extractor/instagram.py) y [configuración](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/docs/configuration.rst): estrategias de usuario `search,web`, APIs separadas por sección y resolución de destacadas. Se mantiene el motor empaquetado 1.32.9 sin actualizar upstream.
- [instagrapi: metadata de usuario](https://github.com/subzeroid/instagrapi/blob/5a61562cfc87b232f2b492b03264adaa10fef65d/instagrapi/mixins/user.py): contraste de normalización y resolución. No se añade esta dependencia ni un nuevo cliente móvil.
- [Ejemplo público de Threads](https://github.com/reza-em/saveit-instagram-youtube-tiktok-downloader-bot/blob/main/threads.py): demuestra que la inserción puede contener recursos ausentes de la página ordinaria. Se inspecciona su implementación sin ejecutarla; ZEUVE implementa su propio parser con identidad y límites más estrictos.

## Evidencia controlada

1. La sesión de Brave autorizada para el objetivo original se valida realmente. Búsqueda exacta → metadata GraphQL devuelve el perfil correcto, privado y seguido por la cuenta, con cero publicaciones. No se interpreta la ausencia de publicaciones como fallo de sesión.
2. El perfil público adicional se consulta sin credenciales. HTML ordinario HTTP 200 contiene canonical, encabezado y avatar. Metadata GraphQL y feed anónimos devuelven 401; no se inventa un catálogo ni privacidad a partir del rechazo.
3. La consulta de destacadas devuelve cinco colecciones. Los elementos GraphQL se obtienen, pero la metadata móvil auxiliar omite la clave de la misma colección; el `KeyError` descartaba toda la sección. El adaptador conserva exclusivamente esos elementos ya autorizados y usa los recursos GraphQL disponibles. No hace fallback tras rechazo HTTP ni ante otra identidad.
4. El helper corregido devuelve una ventana con avatar y 23 elementos de destacadas, sin advertencias. El siguiente elemento determina el cursor; los datos privados y títulos no se publican en este informe. Esta evidencia CLI se distingue de la QA nativa de Release.
5. Threads: la inserción del mismo código responde HTTP 200 también con el User-Agent existente de ZEUVE. Contiene imagen del post, avatares y una respuesta adjunta. La extracción se limita al primer `OuterContainer`, la región multimedia anterior a `PostDateContainer` y el permalink del `LinkContainer`. Se decodifica `&#064;` antes de validar identidad. Los otros recursos no se incorporan.

## Límites

No se prueba ninguna publicación privada, Reddit online ni una Story activa nueva. Recuperar el avatar no certifica publicaciones/Reels públicos. No se emplean visores terceros, proxies, suplantación TLS, CAPTCHA ni evasión de controles de acceso. El único endpoint nuevo aprobado expresamente es la inserción pública de Threads; el resto conserva mecanismos incluidos en los motores y la página ordinaria del perfil.
