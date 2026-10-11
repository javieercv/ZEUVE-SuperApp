# QA nativa de perfiles públicos — ZEUVE 0.20.8.3

Fecha: 12/10/2026. Release 0.20.8.3/revisión 3/build 77, Descargador 0.7.7, adaptador 4.15.3-zeuve.6. Autorización de QA real vigente («puedes empezar a probar», «sigue»); el perfil público adicional se mantiene anónimo. No se importa ninguna sesión ni se accede a publicaciones privadas o Reddit.

## Resultado desde la app

1. Análisis de la URL del perfil público de prueba con Automático y sin cookies. Recupera inicialmente 24 elementos; la sesión aparece plegada como opcional. Solo hay un editor de texto, el de la URL. La biografía disponible y los avisos de muestra limitada/vídeos ausentes son visibles.
2. Desplegar voluntariamente «Sesión de Instagram (opcional)» muestra el editor de cookies y controles de sesión; volver a plegar los oculta. No se introduce ni importa ninguna cookie.
3. «Cargar más» pasa 24→35 elementos y desaparece al terminar la muestra. Se recorren la parte superior e inferior de la cuadrícula: 35 títulos/IDs únicos, coincidentes con el origen y en el mismo orden. Son el avatar y 34 fotos de dos carruseles dentro de las seis publicaciones expuestas. Los ordinales conservan los huecos de los vídeos omitidos. No se presenta el contador global de 788 como catálogo recuperado.
4. «Quitar selección» y elección de la primera foto de cada carrusel. NSOpenPanel confirma carpeta exclusiva de QA; Resumen muestra dos elementos seleccionados. Descarga nativa: **2 correctos, 0 omitidos, 0 fallidos**. Dos JPEG 1080×1440, 85.970 y 140.984 bytes, total **226.954 bytes**, publicados bajo Instagram/perfil/Publicaciones/publicación. FFprobe confirma JPEG y FFmpeg decodifica ambos íntegramente sin errores.
5. Enlace concreto autorizado de contenido protegido, consultado sin sesión. Panel de autenticación desplegado, dos editores, sin DisclosureGroup opcional y descarga deshabilitada. Es una comprobación de presentación; no certifica acceso ni descarga de Story activa. La URL se sustituye después por la pública.

## Bloqueo encontrado y repetición

Los dos primeros procesos de QA (34540 y 35357) se bloquearon al desplazarse por el nuevo catálogo: CPU cercana al 100 %, AX sin respuesta y muestra del hilo principal dentro de composición SwiftUI. El controlador CUA también agotó su tiempo de espera. Se terminaron únicamente esos procesos de QA.

La corrección mantiene montadas las tarjetas estáticas de la pantalla mediante VStack exterior y conserva LazyVGrid/LazyVStack del catálogo. Se repite desde Release recompilado, PID 36100: análisis, paginación, selección de fotos alejadas, NSOpenPanel, descarga, desplazamiento al final y regreso al inicio, expansión/plegado, contenido protegido y reset. Recorrido de más de tres minutos con ventana operativa; no se repite el bloqueo. Se conserva la captura/muestra inicial como evidencia de diagnóstico, sin considerarla aceptación.

## Estados de aceptación

- **D-40 pasa de pendiente a ✅:** publicaciones del perfil mostradas y fotos descargadas desde ese catálogo público. Cobertura limitada a la muestra real de inserción.
- **D-39 sigue ⚠️:** se confirma que el perfil público se analiza sin exigir sesión; el catálogo completo permanece sin acceso demostrado.
- **D-41 sigue ➖:** la muestra no ofrece URLs de reproducción de los siete vídeos/Reels; no se aceptan por sus miniaturas ni por enlaces independientes.
- **D-11 sigue ⚠️:** no se prueba una Story activa descargable en esta ronda.
- **D-17 sigue ⚠️:** Reddit online continúa aplazado por el usuario.
- D-42/D-43/D-56 conservan OK, con nueva evidencia de avatar público, restricciones independientes y paginación finita. Los IDs no repetidos conservan su evidencia previa.

Checklist acumulada: **639 pruebas, 635 OK, 0 fallidas, 3 parciales, 1 pendiente; 638 ejecutadas**.

## Privacidad y cierre

27 entradas JSONL. Auditoría de datos/SQLite/historial/logs/stdout/stderr: 34 URLs firmadas de referencia y dos variantes de URLs privadas, cero coincidencias; búsqueda adicional de hosts CDN, cero coincidencias. La auditoría no usa cookies reales porque no se importó ninguna. Llavero ausente antes y después (exit 44). Reset global desde la UI de QA; cero `.part`; los tres PIDs propios están cerrados. Descargas conservadas; nueve respuestas/datos crudos propios de investigación y el archivo de entrada QA se eliminan al cerrar. No se manipula la sesión original de Brave ni los datos de la app del usuario.

SHA-256 de las fotos: `abf3c71c80070f64a5ccf052757a3a15eb67edea7cc17f0e83681c1f63235bbf` y `5a325a9d29e47b65a8263bc247fe055659d1c58feb489c5ff6f36e4d66c0414f`.

Evidencia local aislada: `~/.codex/visualizations/2026/10/11/01a12a22-6a42-7b63-80e3-55f2aac36805/Publicos-descargador-20261012/`, con estados AX, títulos comparados, verificación multimedia y auditoría saneada. No se publican respuestas HTML, cookies, URLs privadas ni referencias CDN firmadas.
