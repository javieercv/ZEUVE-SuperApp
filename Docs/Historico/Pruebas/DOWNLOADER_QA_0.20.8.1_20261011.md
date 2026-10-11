# QA de las correcciones del Descargador — 0.20.8.1

11/10/2026 · macOS Apple Silicon/Xcode · Release 0.20.8.1, marketing 0.20.8/build 75 · Descargador 0.7.5 · instaloader-zeuve 4.15.3-zeuve.4, upstream 4.15.3 sin cambios. Base remota `ff89299275d437657437452f4e3c12a4efa5b2ce`.

## Autorización y método

El usuario pide continuar solucionando fallidas y parciales y ya ha autorizado las pruebas reales. Se mantienen los enlaces aportados, sesión de Brave limitada a Instagram y objetivo privado original, perfil público adicional anónimo y Reddit online aplazado. No se amplían motores upstream, endpoints ni mecanismos de acceso.

App nativa operada por controles AX y PID, con `ZEUVE_DATA_DIR` y salidas propios fuera del repositorio; alternativa de macOS previamente autorizada. No se manipulan las instancias Debug, los datos ni la sesión original del usuario. Se comprueba el bundle real antes de arrancar: marketing 0.20.8, revisión 1 y build 75. Firma y motores empaquetados verificados.

## Resultados reales desde UI

| ID | Resultado | Evidencia |
| --- | --- | --- |
| D-13 | ✅ | TikTok: cuatro recursos visibles, tres fotos y un audio; descarga 4 correctos/0 fallidos. Tres JPEG y un M4A AAC, sin vídeo, de 179,405941 s y 2.903.171 bytes. |
| D-15 | ✅ | X: nueve referencias duplicadas omitidas y un único vídeo visible; descarga 1 correcto/0 fallidos. MP4 H.264/AAC 1280×720, 60,046803 s, 4.410.764 bytes. |
| D-21 | ✅ | SoundCloud: catálogo Audio, 1 correcto/0 fallidos. MP4 exclusivamente AAC de 85,046440 s y 1.719.031 bytes; ya no exige vídeo para este audio original. |
| D-22 | ✅ | Tumblr: ocho recursos visibles y seleccionados del post concreto, 8 correctos/0 fallidos. Tres JPEG y cinco GIF. Se valida el formato recibido; las extensiones anunciadas por CDN no sustituyen la comprobación MIME/contenido. |
| D-50 | ✅ | Antes de guardar no existe item (consulta de Llavero código 44). Recordar crea el item y activa la opción. Reinicio completo de la app QA: opción activada y campo recuperado de 693 caracteres, idéntico al texto autorizado. No se imprime el secreto. |
| D-51 | ✅ revalidada | Reset global desde los controles nativos, en datos QA: item vuelve a estar ausente, código 44. |
| D-44 | ⚠️ conservada | La sesión recuperada permite preparar la operación, pero Story no devuelve contenido y el perfil privado termina en ≈18,6 s con aviso de rechazo/limitación de la consulta y controles liberados. No se certifica acceso a las secciones autorizadas. |

Los 14 archivos publicados suman 20.844.927 bytes y tienen 14 SHA-256 distintos. FFprobe comprueba tipos/streams y FFmpeg decodifica completamente fotos, GIF, vídeo y audio: cero errores. Las cifras no equivalen a una comprobación acústica humana.

## Diagnóstico y límites que permanecen

**Tumblr:** el extractor gallery-dl responde que ha agotado su cuota API diaria compartida. La página pública devuelve HTTP 200 y contiene ocho bloques de imagen del ID solicitado. El fallback toma las variantes originales de esos bloques y excluye avatares, recomendaciones y otros posts; las imágenes nativas descargadas coinciden en cantidad/tipo con esos bloques. Los enlaces de texto a YouTube no se convierten en recursos embebidos.

**Instagram:** la preparación local de una petición real, sin enviarla, confirma una sola sessionid y una sola csrftoken tras retirar cookies anónimas duplicadas; CSRF coherente. Un diagnóstico autenticado previo a terminar el manejo de límites recibió HTTP 429. La versión final detiene la validación limitada sin sus esperas/reintentos largos ni iniciar otro motor en esa rama. El recorrido nativo final sigue sin catálogo privado; se conserva D-44 parcial. El perfil público adicional se diagnostica sin sesión y recibe rechazo/limitación: D-34 continúa fallida y D-11/D-33/D-39 parciales. Estos resultados no demuestran perfil vacío, inexistente ni sesión inválida.

**Threads:** el HTML público recibido es HTTP 200, pero no contiene un recurso verificable del post solicitado; las referencias de imagen son al avatar. yt-dlp no dispone de extractor compatible para esta URL y el recorrido anterior no resolvió contenido. No se afirma que el post esté eliminado. D-23 sigue fallida; no se introduce una API distinta ni evasión de controles.

**Cobertura restante:** Reddit online se mantiene aplazado (D-17 parcial); organización de destacadas no verificada (D-60 parcial; cuatro combinaciones de carrusel conservadas). D-40–D-43 y D-56 siguen pendientes de catálogo utilizable. No se repiten plataformas ya aceptadas ni toda la batería manual de 639 IDs.

## Privacidad y cierre

Auditoría frente a siete valores reales de cookies y nueve variantes escapadas/desescapadas: 76 entradas JSONL, ajustes e historial SQLite y stdout de los dos arranques, cero coincidencias. Se ejercitan descargas públicas y consultas con sesión; no hubo descarga privada exitosa y no se certifican rutas no ejercitadas.

Se eliminan exclusivamente las copias propias de cookies y el archivo de entrada del controlador. No quedan archivos de sesión/cookies en los datos QA. Reset deja `allowAdultContent=false` y `rememberInstagramSessionByDefault=false`; el Llavero no contiene el item QA. La app sale normalmente y su PID ya no existe. Se conservan los 14 archivos de evidencia, cero `.part`; sesión de Brave y datos originales intactos. Registros brutos, URLs privadas y medios permanecen fuera de Git.

Checklist acumulada: **639 IDs, 626 OK, 2 fallidas, 6 parciales y 5 pendientes; 634 ejecutadas**. Solo D-13/D-15/D-21/D-22/D-50 cambian a OK. Los títulos y la evidencia histórica se conservan. No se genera ZIP ni se certifica distribución notarizada.
