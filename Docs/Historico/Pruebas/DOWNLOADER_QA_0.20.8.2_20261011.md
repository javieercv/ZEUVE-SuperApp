# QA nativa del Descargador — ZEUVE 0.20.8.2

11/10/2026 · Release, marketing 0.20.8/revisión 2/build 76 · Descargador 0.7.6 · instaloader-zeuve 4.15.3-zeuve.5. Base remota `4c95ab1911ef32bd60a01dfe61a083e33aeacdcc`. Aplicación real con almacenamiento y salida aislados, PID 61630; control mediante AppleScript/Accesibilidad ya autorizado. No se usan los resultados CLI para sustituir aceptación nativa.

## Resultados

| IDs | Resultado comprobado |
|---|---|
| D-23 | Threads analiza un recurso del post pedido y descarga un JPEG 4096×2731; 1 correcto/0 fallidos. La inserción contiene además avatares y una respuesta: ninguno entra en el catálogo. |
| D-33/D-34 | Perfil autorizado por URL y por `@usuario`, con Instagram seleccionado: 24 elementos, sin errores; metadata y acceso reales. La cuenta tiene cero publicaciones confirmadas. |
| D-42/D-43 | Perfil público adicional, sin cookies: encabezado/avatar y aviso de catálogo parcial. Stories/Destacadas restringidas no impiden seleccionar y descargar el avatar ofrecido, JPEG 100×100; 1 correcto/0 fallidos. |
| D-44 | Sesión autorizada para el objetivo original permite acceder a destacadas y descargar una foto y un vídeo; 2 correctos/0 fallidos. No se amplía la sesión al perfil público adicional. |
| D-56 | Cargar más pasa 24→48 elementos, sin error; recorrido de la cuadrícula confirma 48 títulos distintos. |
| D-60 | Las dos muestras de destacadas se publican en Instagram/perfil/Destacadas/colección. El nombre de la carpeta coincide con la metadata real de la colección; no se publican ese nombre, perfil ni URLs privadas. Las cuatro combinaciones de carrusel conservan la aceptación anterior. |

Ocho IDs pasan a OK. Estado acumulado: **639 pruebas, 634 OK, cero fallidas, tres parciales y dos pendientes; 637 ejecutadas**. Los IDs no repetidos mantienen su evidencia previa.

Se conserva D-11 parcial por Stories activas no aceptadas en esta ronda; D-39 parcial porque solo se recupera el encabezado/avatar público. D-40/D-41 siguen pendientes: metadata/feed anónimos del perfil público responden 401, sin publicaciones/Reels descargables. D-17, Reddit online, continúa aplazado. No se certifica publicación privada ni se interpreta un rechazo como sesión inválida o perfil inexistente.

La primera comprobación de alias se hizo con Automático; no usa el catálogo Instagram en ese modo. Se repite con Instagram seleccionado según el contrato documentado y pasa. Los fallos de control del selector/árbol AX se corrigen en el auxiliar de QA; no se atribuyen a ZEUVE. No se cambia el routing aprobado de nombres de usuario.

## Archivos y privacidad

Cuatro archivos, **12.767.658 bytes**, cuatro SHA-256 registrados fuera del repositorio. FFprobe y decodificación íntegra con FFmpeg: cero errores. Threads JPEG 4096×2731; avatar público JPEG 100×100; destacada JPEG 1080×1920; destacada MP4 H.264 720×1280/AAC estéreo 44,1 kHz. Se conserva el recurso que el origen devuelve, sin recodificación ni afirmación de una resolución superior no obtenida.

Auditoría final de datos/logs, SQLite con WAL, historial, stdout/stderr: siete valores reales de cookies y nueve variantes, 67 URLs privadas de perfil/Stories/multimedia, siete archivos y 51 entradas JSONL. **Cero coincidencias de cookies o URLs privadas**. No se afirma ausencia de nombres/rutas de archivos locales ni cobertura de toda caché del sistema.

Se restaura Ajustes > General desde UI, Llavero sin item (estado inicial/final 44), originales y sesión de Brave conservados. Se eliminan las dos copias propias con secretos: exportación de cookies y entrada del auxiliar. La app QA se cierra normalmente y el PID queda ausente; los cuatro resultados propios permanecen como evidencia fuera de Git. No se genera ZIP ni se toca la instancia Debug del usuario.

Las evidencias privadas están en la carpeta de QA con acceso restringido; este informe contiene únicamente cantidades, formatos y resultados. La [investigación](../Implementacion/INSTAGRAM_THREADS_RESEARCH_20261011.md) identifica consultas y fuentes sin conservar respuestas privadas en el repositorio.
