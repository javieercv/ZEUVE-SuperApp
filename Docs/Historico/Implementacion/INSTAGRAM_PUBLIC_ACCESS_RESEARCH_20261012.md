# Acceso público de Instagram — investigación del 12/10/2026

Base remota actualizada `b2c4fa7fc3b5347b6e28bb136ad5ff886865190d`. Diagnóstico sin cookies personales, sesión de navegador, proxy nuevo ni ejecución de JavaScript. Solo peticiones HTTPS verificadas y análisis de respuestas como datos. Las respuestas y URLs firmadas quedan fuera de Git.

## Requisito de sesión y presentación

La vista muestra el panel de sesión para todos los perfiles, incluso si `requiresAuthentication` es falso. La presentación aprobada por el usuario cambia a control plegado/opcional cuando no existe un requisito de autenticación confirmado, manteniendo el panel desplegado para contenido protegido. No convierte un bloqueo de feed en privacidad del perfil ni descarta el avatar público.

La página ordinaria del perfil de prueba responde 200 con canonical exacto y avatar. La consulta REST de feed ya incluida en gallery-dl responde 401 con `require_login: true` y petición de esperar. No ofrece elementos y no se reintenta ese feed. La respuesta aplica a esa consulta, no declara privada la cuenta. Las consultas anteriores GraphQL anónimas tampoco entregaron publicaciones.

## Fuentes primarias

- [Instaloader: revisión de acceso anónimo](https://github.com/instaloader/instaloader/pull/2675): el mantenedor describe restricciones de catálogo anónimo distintas de problemas TLS. La propuesta de suplantación no se adopta.
- [gallery-dl: incidencia 9564](https://github.com/mikf/gallery-dl/issues/9564): comentarios proponen GraphQL público y distinguen publicaciones individuales y listados. Se contrasta con peticiones reales; el comentario no se presenta como garantía de funcionamiento actual.
- [Meta: plugin oficial de inserciones](https://github.com/facebook/meta-embeds-for-wordpress): admite inserciones públicas de perfiles Instagram. No se incorpora WordPress, oEmbed ni scripts a ZEUVE.
- [OGInstagram: fuente de perfiles](https://github.com/seirenkr/OGInstagram/blob/0a3eb7016766421dc823b2a1f332604e4180a515/server/profile.go) y [parser de inserción](https://github.com/seirenkr/OGInstagram/blob/0a3eb7016766421dc823b2a1f332604e4180a515/server/igembed.go): el proyecto usa rutas de web e inserción como fuentes separadas. Se estudia el formato sin usar su servicio, proxies ni ejecutar su código.

## Inserción pública y respaldo aprobado

En el perfil público de prueba, `https://www.instagram.com/USUARIO/embed/` responde 200. Su `contextJSON` contiene un contexto de tipo Profile, usuario y owner_id exactos, con seis publicaciones y contador global de 788. Dos carruseles incluyen 37 nodos: 34 fotos y tres vídeos; las otras cuatro publicaciones son vídeos. Los siete nodos de vídeo no contienen URL de reproducción.

Una foto de carrusel se descarga directamente y FFprobe confirma JPEG 1080×1440, 92.187 bytes. Una inserción individual de vídeo responde 200 y confirma identidad, pero tampoco ofrece URL de reproducción; no se considera vídeo recuperado.

El respaldo aprobado utiliza únicamente la inserción del perfil, nunca un visor tercero. Valida tipo, usuario, enlace del perfil y propietario; excluye recursos ajenos, conserva ordinales del carrusel y extrae solo formatos disponibles. Su ventana es una muestra pública: no demuestra acceso a las otras publicaciones ni autoriza fabricar un cursor para el catálogo completo. Los vídeos sin recurso no se tratan como imágenes. El usuario aprueba expresamente «Sí, añadir el respaldo público» el 12/10/2026. La integración se limita a este endpoint de perfil; no incorpora la inserción individual probada durante la investigación. El ajuste de presentación tiene aprobación independiente.
