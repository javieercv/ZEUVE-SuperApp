# Perfiles y Reels públicos — contraste del 12/10/2026

Base remota sincronizada `3f499d8eab1ac7382066266454dac545cd9bcf3a`. Alcance: público, sin cookies personales, Stories activas, cuentas privadas ni Reddit. No se usa navegador, proxy, visor tercero, nueva dependencia o endpoint.

## Causa y resolución comprobadas

La inserción pública ofrece seis publicaciones y sus IDs/propietarios. Sus siete vídeos carecen de URL de reproducción, aunque sí muestra 34 fotos. El adaptador anterior los omitía; esa ausencia en la inserción no prueba que la publicación concreta sea inaccesible.

El comando direct del ejecutable incluido resuelve anónimamente el primer Reel con código, post_id, owner_id y usuario coincidentes. La misma consulta `PolarisPostRootQuery` ya presente en Instaloader 4.15.3 recupera la reproducción de los cuatro Reels y los tres vídeos de carrusel. La normalización de métricas auxiliares no se necesita para descargar; el helper valida directamente la respuesta de esa misma consulta, sin iniciar otro feed.

Con la muestra completa se obtienen 41 recursos: 34 fotos, cuatro Reels y tres vídeos. Al añadir avatar, 42 posiciones conocidas. Los hijos se comprueban por ID y posición; el máximo formato disponible se elige por dimensiones. Las fotos no se sustituyen por posters y un vídeo sin URL real continúa omitido.

La consulta anónima de timeline ya incluida devuelve 401. Por ello no se afirma acceso a las otras publicaciones del perfil (contador global 788); el catálogo conserva aviso de muestra parcial. El estado de aceptación de análisis público/Reels se limita al criterio y recorrido realmente probados.

## Fuentes primarias y contraste local

- [Instaloader, PR 2706](https://github.com/instaloader/instaloader/pull/2706): migración de resolución de posts a PolarisPostRootQuery y la forma de respuesta v1. Se comprueba la implementación instalada 4.15.3; no se introduce la propuesta ni una versión nueva.
- [gallery-dl, incidencia 9564](https://github.com/mikf/gallery-dl/issues/9564): distingue HTML con login y resolución pública GraphQL. El comentario se contrasta con la ejecución local; no garantiza catálogo global ni compatibilidad permanente.

Respuestas y referencias firmadas se mantienen solo en temporales propios fuera de Git y se eliminan al cerrar. [Implementación](IMPLEMENTATION_REPORT_0.20.8.4.md) y [QA nativa](../Pruebas/DOWNLOADER_QA_0.20.8.4_20261012.md).
