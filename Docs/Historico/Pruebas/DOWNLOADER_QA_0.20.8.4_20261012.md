# QA nativa pública — ZEUVE 0.20.8.4

12/10/2026. Release revisión 4/build 78, Descargador 0.7.8, helper 4.15.3-zeuve.7. Base remota sincronizada `3f499d8eab1ac7382066266454dac545cd9bcf3a`. El usuario pide terminar lo público excluyendo Stories activas y cuentas privadas. Reddit permanece aplazado. Datos aislados, sin sesión personal ni navegador.

## Recorrido real

- URL del perfil público con plataforma Automático: análisis inicial de 24 elementos, sesión opcional plegada y un único editor (URL). «Cargar más» pasa a 42 y desaparece al terminar.
- Cuadrícula: avatar, 34 fotos, cuatro Reels y tres vídeos de carrusel. Se recorre hasta el final y se vuelve al inicio. Los 42 títulos/IDs son únicos y coinciden con el origen en orden; los ordinales originales del carrusel se conservan, incluido el vídeo de posición 6.
- Selección de un Reel, un vídeo de carrusel y una foto desde ese catálogo de perfil. NSOpenPanel confirma carpeta exclusiva QA; Resumen muestra tres elementos. Descarga: **3 correctos, 0 omitidos, 0 fallidos**.
- Reel: MP4 H.264 720×1280/AAC, 10,283583 s, 2.721.880 bytes, carpeta Instagram/perfil/Reels. Vídeo de carrusel: MP4 H.264 720×960, 10,5 s, 689.277 bytes, bajo la publicación correspondiente. Foto: JPEG 1080×1440, 85.970 bytes, bajo la misma publicación. Total **3,497,127 bytes**. FFprobe valida los streams y FFmpeg decodifica íntegramente los tres archivos sin errores. El vídeo de carrusel recibido no contiene pista de audio; no se añade ni recodifica.
- Después del ajuste final de paginación, se recompila Release y se repite `@usuario` con Instagram seleccionado, 24→42 elementos, sesión opcional y cuatro Reels. Desplazamiento inferior/superior y cierre correctos. No se analiza `@usuario` como URL en Automático.

El aviso visible indica seis publicaciones de muestra frente al contador global 788. **No se certifica el catálogo global**: la consulta de timeline anónima continúa devolviendo 401. Se han recuperado todos los recursos multimedia de esa muestra, sin ampliar acceso ni eludir el bloqueo.

## Aceptación

- **D-39 pasa a ✅** en su criterio literal «Un perfil público se analiza sin obligar a iniciar sesión»: probado mediante URL y @usuario, con catálogo real de fotos/vídeos/Reels y descarga. Este OK no significa todas las publicaciones del perfil; ese límite permanece explícito en producto y documentación.
- **D-41 pasa a ✅**: cuatro Reels mostrados desde el catálogo del perfil, uno descargado y verificado. No se sustituye por un enlace independiente ni por una miniatura.
- D-33/D-34/D-40/D-42/D-43/D-56 conservan OK, con evidencia adicional pública de entrada, selección, independencia de autenticación y paginación finita.
- D-11 sigue ⚠️: Stories activas/cuentas privadas fuera de esta ronda por instrucción expresa. D-17 sigue ⚠️: Reddit aplazado. No se marcan estas comprobaciones excluidas como correctas.

Checklist acumulada: **639 pruebas: 637 OK, 0 fallidas, 2 parciales, 0 pendientes; 639 ejecutadas**. Los otros IDs conservan su evidencia histórica.

## Privacidad y cierre

No se importa ninguna cookie ni se reutiliza la sesión previa de Brave. Auditoría de datos, SQLite/historial, logs y stdout/stderr frente a 41 URLs firmadas de referencia: cero coincidencias; hosts CDN también ausentes. Llavero ausente (exit 44), cero `.part`, reset global nativo tras ambos recorridos y cierre exclusivo de los PIDs propios 22790/26730. Los archivos publicados se conservan; datos del usuario y navegador originales no se manipulan. Los JSON crudos de investigación y el archivo de entrada QA se eliminan al finalizar.

SHA-256: Reel `aa302ecb4455018e20ab3ecb3b0cc6a1c6badaf1265fe9140ed79b037b42cde6`; vídeo `3e828114b052759c9321484d1e9396078f8b53db19a599f500519b68375730fa`; foto `abf3c71c80070f64a5ccf052757a3a15eb67edea7cc17f0e83681c1f63235bbf`.

Evidencia local: `~/.codex/visualizations/2026/10/11/01a12a22-6a42-7b63-80e3-55f2aac36805/Publicos-final-20261012/`. Estados AX, selección, resultados multimedia y auditoría saneada. No se publican cookies, URLs firmadas o respuestas crudas.
