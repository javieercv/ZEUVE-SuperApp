# Implementación — ZEUVE 0.20.8.2

11/10/2026 · Base remota actualizada `4c95ab1911ef32bd60a01dfe61a083e33aeacdcc`. Marketing 0.20.8, revisión 2/build 76; Descargador 0.7.6; instaloader-zeuve 4.15.3-zeuve.5 sobre Instaloader 4.15.3.

El [contraste de fuentes y peticiones](INSTAGRAM_THREADS_RESEARCH_20261011.md) identifica dos causas: `from_username` empieza por un endpoint obsoleto pese a disponer de metadata GraphQL autenticada; y las destacadas se descartaban por falta de metadata móvil auxiliar, aun con elementos GraphQL válidos.

El helper resuelve la sesión realmente validada por búsqueda exacta de usuario y GraphQL, verificando de nuevo usuario e ID. Conserva las destacadas obtenidas con ese permiso si la única ausencia es la clave móvil de la misma colección, valida propietario cuando se incluye y restaura el estado del contexto. Los rechazos HTTP no se convierten en acceso. Evita consultar publicaciones cuando el recuento confirmado es cero y acota ventanas de Stories/destacadas para emitir cursor sin recorrer innecesariamente todo el perfil.

Sin sesión, el encabezado de la página ordinaria permite recuperar un avatar con canonical y tipo de perfil comprobados. Se ofrece como recurso independiente y se declara catálogo parcial; no se infieren publicaciones, Reels ni privacidad a partir de un 401/429. Las secciones restringidas conservan la descarga de ese recurso público. El parser presenta un aviso específico para esta cobertura.

Threads consulta la inserción pública autorizada tras un HTML ordinario sin recursos. Usa la sesión HTTP efímera existente sin cookies, comprueba el permalink y limita la extracción al primer contenedor de publicación. Excluye avatares, respuestas y enlaces adjuntos, conserva orden y formato de multimedia y usa la validación/publicación existentes. Se propaga cancelación y se decodifican entidades numéricas para verificar el código.

Se reconstruye el helper ARM64 con las mismas dependencias fijadas y se actualizan hash/tamaño del manifiesto. No hay dependencias upstream, motores, servicios de terceros, permisos, SQLite ni navegador nuevos. Versionado, Xcode y fuentes vivas sincronizados; no se genera ZIP.
