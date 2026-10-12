# Implementación — ZEUVE 0.20.8.4

12/10/2026. Base remota `3f499d8eab1ac7382066266454dac545cd9bcf3a`, limpia y sincronizada. Marketing 0.20.8/revisión 4/build 78; Descargador 0.7.8; helper propio 4.15.3-zeuve.7, mismo Instaloader 4.15.3 y dependencias.

## Alcance

El usuario pide terminar lo público excluyendo Stories activas y cuentas privadas; Reddit sigue aplazado. Se continúa la corrección aprobada del helper/parser con las rutas existentes. No cambia UI, ajustes, privacidad, permisos, esquema ni dependencias; no se crea ZIP.

## Cambios

- El helper resuelve los vídeos/Reels de las publicaciones verificadas de la inserción utilizando exactamente la consulta de publicación concreta ya incluida (`27128499623469141`), sin consultas auxiliares de métricas.
- Comprueba código, ID de post, owner_id, usuario y carácter no privado en la respuesta. Los hijos de carrusel deben coincidir por ID, tipo y posición; una respuesta ajena no aporta recursos.
- Conserva 34 fotos y añade reproducción real de cuatro Reels y tres vídeos, en orden original. Clasifica Reel solo con `product_type=clips` en un vídeo independiente. Elige la mayor resolución compatible disponible y preserva extensión, duración válida y carpeta de sección/publicación.
- La reproducción tiene un intento por post, timeout máximo de 10 s y ventana opcional de 50 s dentro del presupuesto global de 120 s. Un rechazo 401/403/429, desafío o timeout detiene la resolución opcional posterior; las fotos disponibles se conservan. No consulta con usuario autenticado ni sessionid personal.
- Pagina por posiciones de recursos verificados, reservando su posición aunque falle la reproducción. Una ausencia de vídeos no desplaza ni omite fotos en las páginas siguientes. Los vídeos fuera de la ventana solicitada no se vuelven a consultar. Las posiciones internas no se emiten como metadata pública.
- El parser solo muestra el aviso de vídeos ausentes cuando realmente faltan. Mantiene sesión opcional, diagnóstico parcial, biografía, identificación `instagram-public-embed` y ausencia de otro intento de feed tras la muestra.
- Se reconstruye el helper ARM64 y actualiza manifiesto/hash/tamaño; contratos persistidos y otros motores se conservan.

## Límite real

El timeline global anónimo continúa respondiendo 401. Se conserva la muestra finita y su aviso; no se promete recuperar las otras publicaciones del perfil ni se elude el requisito del origen. El análisis público sin sesión y la presencia/descarga de Reels se aceptan solo por el recorrido documentado.

[Investigación](INSTAGRAM_PUBLIC_REELS_RESEARCH_20261012.md), [pruebas](../Pruebas/TEST_RESULTS_0.20.8.4.md), [QA nativa](../Pruebas/DOWNLOADER_QA_0.20.8.4_20261012.md).
