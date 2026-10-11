# QA real del Descargador — ZEUVE 0.20.8.0

11/10/2026 · macOS Apple Silicon/Xcode · Release 0.20.8/build 74 · Descargador 0.7.4 · instaloader-zeuve 4.15.3-zeuve.3.

## Autorización y entorno

Después de reservar las pruebas manuales durante la implementación, el usuario autoriza «puedes empezar a probar» y después «sigue». Se repiten los enlaces aportados y se utiliza la autorización previa de sesión de Brave limitada a Instagram y al objetivo privado original. El perfil público adicional se analiza sin sesión. Reddit online continúa aplazado.

Base de código y app: `67895ab1befd63a529ad682d214d83528c6193b7`, comprobada contra origin/main sin divergencia. Esta ronda no cambia producto, dependencias, versión ni empaquetado. La app Release se opera mediante controles nativos AX por PID, con almacenamiento `ZEUVE_DATA_DIR` y descargas propios fuera del repositorio. No se manipulan las instancias Debug del usuario. CUA no permitió completar el control; se utilizó la alternativa de macOS autorizada. Las pruebas con motores por CLI se distinguen de la aceptación desde UI.

## Resultados de aceptación

| ID | Estado | Evidencia real de esta ronda |
| --- | --- | --- |
| D-13 | ❌ | TikTok muestra 3 fotos y 1 audio. Descarga 3 JPEG válidos; falla el audio. Repetir solo el audio también falla y no publica archivo. |
| D-15 | ❌ | X omite 6 referencias duplicadas, pero presenta y descarga 4 vídeos de la misma publicación. Persisten variantes del mismo clip entre motores. |
| D-21 | ❌ | SoundCloud se muestra como Vídeo. Dos descargas terminan sin archivos válidos, aunque yt-dlp sale con código 0. Regresión respecto a la salida de audio real aceptada el 09/10. |
| D-22 | ❌ | Tumblr acepta la forma de URL aportada, pero el análisis real no devuelve multimedia descargable. |
| D-23 | ❌ | Threads no devuelve multimedia descargable para el enlace aportado. |
| D-24 | ✅ | Snapchat: un vídeo visible, 6 referencias duplicadas omitidas, 1 correcto/0 fallidos; MP4 H.264/AAC de 7.038.893 bytes decodificado íntegramente. Sin VTT publicado como recurso primario. |
| D-25 | ✅ | EroMe: HTML de origen con 6 vídeos y 3 imágenes originales; UI con los mismos 9 recursos en orden. Descarga 9 correctos/0 fallidos; 6 MP4 y 3 JPEG, 9 SHA-256 distintos, 11.171.986 bytes y 0 errores de decodificación. |
| D-34 | ❌ | Perfil público adicional, anónimo: catálogo vacío con diagnóstico de solicitud bloqueada. No prueba ausencia de contenido ni privacidad. |
| D-44 | ⚠️ | Sesión importada/preparada; Stories sin resultados y perfil del objetivo privado sin catálogo. El límite de análisis termina automáticamente y libera controles; no se valida acceso efectivo ni descarga privada. |
| D-45 | ✅ | Cabecera Cookie pegada en el panel nativo: preparación temporal aceptada, sin error de formato. No certifica D-44. |
| D-46 | ✅ | Texto Netscape original pegado en el panel: sesión preparada temporalmente, sin normalización externa. No certifica acceso autenticado. |
| D-47 | ✅ | NSOpenPanel acepta el archivo original de 8 cookies con una caducidad vacía; nombre seleccionado confirmado, contenido original sin modificar. |
| D-48 | ✅ | Botón nativo Importar sesión con Brave confirmado: 8 cookies de Instagram importadas temporalmente. |
| D-49 | ✅ | Recordar en el Llavero crea el item; existencia comprobada sin leer ni imprimir el secreto. Permanece tras cierre y reinicio nativos. |
| D-50 | ❌ | Tras reinicio el item existe, pero Recordar aparece desactivado y el campo de sesión está vacío. La recuperación falla. |
| D-51 | ✅ | Restaurar todos los ajustes desde UI elimina el item QA del Llavero: consulta de existencia termina con código 44. Historial y archivos propios conservados. |
| P-12 | ✅ | Canarios de token/password/sessionid y 8 valores reales de cookies: 0 coincidencias en logs, ajustes, historial y stdout dentro del alcance ejercitado. |

D-11/D-39 conservan cobertura parcial de Instagram; D-33 no se vuelve a certificar. D-60 conserva la cobertura parcial: las galerías sí se ejercitan, pero las secciones de perfil/destacadas no producen resultados. D-17 mantiene el aplazamiento de Reddit. D-40–D-43 y D-56 siguen sin probar: un catálogo vacío no permite aceptar publicaciones, Reels, foto de perfil, independencia de secciones restringidas ni Cargar más. Los demás IDs conservan sus evidencias anteriores; no se presentan como repetidos en este Release.

## Investigación de los fallos

**TikTok:** el selector incluye correctamente la identidad del audio y `num=0`. Dos contrastes con gallery-dl incluido, separados de la UI, descargan 2.903.171 bytes para ese recurso. Aunque el extractor lo anuncia como MP3, FFprobe identifica contenedor MP4/M4A y AAC de 179,405941 s, sin vídeo. La validación rechaza la extensión incompatible; el respaldo yt-dlp termina con error. Ya existe un recurso de audio accesible en esta ronda: el problema reproducido es la discordancia de extensión/contenedor y su tratamiento, no una mera falta de disponibilidad. Las tres fotos nativas se decodifican correctamente.

**X:** los cuatro MP4 nativos se decodifican sin error. Resoluciones 1280×720, 640×360, 320×180 y 1280×720; todos de 60,0468 s. Los dos de 1280 producen el mismo frame reducido a los 10 s y la variante 640 prácticamente el mismo. Los SHA de archivos son distintos y no se usa eso para afirmar contenido distinto. La deduplicación actual no reúne suficientemente las variantes entre gallery-dl y los resultados genéricos de yt-dlp. No se ha demostrado una identidad binaria de los cuatro recursos.

**SoundCloud:** ambas operaciones nativas muestran «La operación terminó sin producir archivos válidos», 0 correctos/1 fallido, mientras el motor descarga 16 fragmentos y sale con código 0. El MP4 del mismo enlace obtenido en QA anterior sigue intacto; FFprobe confirma AAC sin vídeo de 85,046440 s. El catálogo actual lo clasifica Vídeo. El código de `expectedOutputKind` exige ese tipo en modo Original y `DownloadOutputValidator` exige un stream de vídeo: es una causa probable muy respaldada de la regresión. No se acepta una salida nueva, porque ninguna se publica.

**Llavero:** `UniversalDownloaderView` vincula Recordar del panel a `rememberInstagramSession` sin persistir la preferencia al cambiarlo. El análisis sí guarda el secreto, pero al iniciar solo se carga si la preferencia persistida de recuerdo está activada. La UI observada tras reinicio y el item aún presente respaldan esta causa; no se confunde guardado con recuperación.

**Instagram:** importar y preparar cookies ya funciona. Eso no demuestra validación efectiva. El perfil autenticado agota el presupuesto configurado de 120 s; el siguiente sondeo a aproximadamente 136 s observa el aviso de tiempo agotado y controles liberados, sin cancelación manual. La ruta de Stories recuperada no conserva el ID específico de la Story anterior: no se afirma que el mismo contenido siga activo ni se certifica acceso actual en navegador. La consulta del perfil adicional público permanece anónima.

**Tumblr y Threads:** se confirma el fallo del recorrido real, pero esta ronda no verifica independientemente que los dos contenidos concretos sigan disponibles. La corrección sintáctica de Tumblr pasa; eso no acepta la plataforma. No se amplía alcance con nuevos endpoints, motores ni evasión de controles.

## Privacidad, límites y cierre

Auditoría final: 167 entradas JSONL; 8 valores de cookies y sus variantes escapadas/desescapadas; 3 canarios sintéticos. Cero coincidencias en logs, ajustes e historial SQLite y stdout de los arranques. Se ejercitan análisis con sesión, éxito/error de análisis públicos y descargas/fallbacks públicos. P-11 queda revalidado en ese alcance. No hubo descarga autenticada privada exitosa; el resultado no certifica rutas no ejercitadas ni cualquier secreto posible.

Antes de guardar, el item de ZEUVE en Llavero no existía (código 44). Después de probar el reset vuelve a estar ausente. Se elimina la copia original propia de cookies y el archivo de entrada del controlador; no quedan archivos de cookies en los datos QA. El contenido adulto, habilitado únicamente en los ajustes aislados para el álbum autorizado, vuelve a desactivarse. La app QA se cierra normalmente; su PID ya no está activo. La pestaña QA identificada ya no está presente; no se cierran pestañas ajenas. Sesión original de Brave y datos del usuario conservados.

Se conservan 17 archivos publicados QA: 3 fotos TikTok, 4 vídeos X, 1 vídeo Snapchat y 9 recursos EroMe; 0 `.part` definitivos. Los dos audios diagnósticos están en carpetas propias separadas de las salidas de la app. Medios adultos, perfiles privados, cookies, URLs privadas, títulos y registros brutos permanecen fuera de Git.

Incidencias de control separadas del producto: dos intentos iniciales se dirigieron a Safari antes de confirmar Brave y fueron rechazados por permisos de macOS, sin importar cookies; después se comprobó Brave y el botón nativo funcionó. Una instancia QA dejó de estar disponible durante una interrupción; no hay evidencia para atribuirlo a crash de ZEUVE. SoundCloud se repite después y su fallo sí queda capturado desde UI. La política de JavaScript del navegador impidió el contraste DOM del objetivo privado; no se cambió ni eludió esa política.

## Estado acumulado y entrega documental

Checklist de 639 IDs: **621 OK, 7 fallidas, 6 parciales y 5 pendientes; 634 ejecutadas**. Nueve IDs pasan a OK desde estados fallido/parcial/pendiente; D-50 se ejecuta y falla; D-21 pasa de OK histórico a fallo reproducido. Fallidas actuales: D-13, D-15, D-21, D-22, D-23, D-34 y D-50. Las pruebas automáticas anteriores siguen siendo su evidencia técnica, pero no sustituyen estos resultados reales.

Se actualizan checklist, portada, índice y estado de aceptación, sin cambios de código. Verificación aplicable: documentación, enlaces/estados y `git diff --check`; no se recompila ni se vuelve a ejecutar la batería completa porque no cambia el producto desde la base probada. No se genera ZIP. Los fallos requieren una continuación de correcciones con su plan concreto; esta ronda registra los resultados y las causas investigadas.
