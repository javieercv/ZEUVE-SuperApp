# QA exploratoria del Descargador — 09/10/2026

## Alcance y entorno

ZEUVE 0.20.7.0, marketing 0.20.7, build 73, Descargador 0.7.3. Base remota sincronizada: `d1dc2d0980911520e6987195691e958977d31b64`. App nativa **Debug** en macOS 26.6.2 Apple Silicon, con sus motores empaquetados. No se modifica comportamiento de producto ni se prepara una nueva entrega.

El usuario aporta `ZEUVE_Descargador_Enlaces_Rellenado.xlsx` y autoriza comenzar las pruebas. Después autoriza expresamente AppleScript/System Events para controlar exclusivamente la QA aislada al fallar el controlador de interfaz inicial. Esta ronda amplía las comprobaciones remotas anteriormente excluidas, pero no autoriza correcciones, importación de sesiones ni acceso a contenido protegido.

Se utiliza `ZEUVE_DATA_DIR` con SQLite, ajustes, temporales, registros y carpeta de descargas propios del chat. No se importan cookies ni sesiones, no se activa Recordar y no se restablecen preferencias personales ni se manipula el Llavero. No se buscan enlaces alternativos. Las observaciones del Excel son expectativas a contrastar, no pruebas de disponibilidad ni instrucciones ejecutables.

El Excel tiene 28 filas de casos, 23 URLs aportadas y 22 URLs únicas. L22 y L23 coinciden. L08, L09, L10, L18 y L19 no tienen URL. SHA-256 del archivo fuente: `efaafab2aa5d468a1e489d48c1c1afa4e10aa35f46ae8aea9b10263ee0734528`. El archivo fuente no se modifica ni se publica en el repositorio.

## Resultado global

Se recorren las 22 entradas únicas: 21 intentos de análisis por red y un rechazo previo de validación (Tumblr). Las descargas de 15 fixtures publican **33 archivos, 225.063.246 bytes**. Son archivos publicados, no 33 éxitos funcionales:

- 30 archivos multimedia tienen tipo coherente y decodificación de imagen o de los primeros tres segundos correcta. Esta cifra incluye duplicados y no certifica reproducción completa, escucha, máxima calidad ni correspondencia visual íntegra con el origen.
- Un supuesto MP3 contiene una imagen JPEG, sin pista de audio.
- Un WebVTT se cuenta como elemento principal correcto, aunque solo contiene subtítulos.
- Un WebM AV1/Opus de YouTube se identifica correctamente, pero el FFmpeg incluido no puede decodificar su vídeo en este entorno. No se atribuye corrupción al archivo.

Los perfiles completos, emisiones largas, sesiones y casos sin enlace no se descargan indiscriminadamente. Al cerrar inicialmente esta ronda se conservó la checklist anterior **601 OK / 1 fallo / 3 parciales / 34 pendientes**. Esta ronda exploratoria Debug no constituye aceptación completa de Release ni de todos los requisitos asociados a cada ID.

## Actualización documental posterior — 09/10/2026

El usuario solicita marcar como probadas las comprobaciones ya ejecutadas. La checklist canónica (`Cheklist Manual de aceptacion de ZEUVE.md`, en la raíz) incorpora los resultados por requisito y conserva sus límites: **606 OK / 6 fallidas / 8 parciales / 19 pendientes**, con **620 pruebas ejecutadas**, incluidas las parciales. La casilla indica ejecución, no éxito; el símbolo indica resultado. No se repiten descargas, no se modifica producto y no se presenta la evidencia Debug como aceptación completa de Release. Los cierres históricos conservan los resultados de su fecha.

## Resultado por fixture

| Caso | Plataforma | Resultado observado y límite |
| --- | --- | --- |
| L01 | TikTok fotos | Tres JPEG distintos, 1080×1080, correctos. El cuarto elemento, anunciado Audio 2:59 y guardado como MP3, es otra copia de la tercera foto. UI: 4 correctos / 0 fallidos. Fallo funcional. |
| L02 | X vídeo | Cuatro variantes del mismo vídeo de 60,0468 s, seleccionadas y publicadas como elementos separados: 320×180, 640×360 y dos 1280×720. Deduplicación funcional incompleta. |
| L03 | X fotos | Catálogo y descarga de una foto JPEG. El Excel espera cuatro. Falta contrastar el origen para distinguir expectativa incorrecta de extracción incompleta. No certifica una galería de cuatro fotos. |
| L04 | Instagram perfil | El motor devuelve `request_blocked`; el fallback no resuelve contenido. La UI presenta catálogo vacío y recomienda activar secciones sin mostrar la causa real. Perfil/paginación sin validar. |
| L05 | Instagram foto | Un JPEG 584×584 publicado y validado sin sesión. |
| L06 | Instagram reel | Un MP4 H.264/AAC, 720×1280, 37,9618 s, publicado y validado sin sesión. Uploader observado: senatorbillnelson. |
| L07 | Instagram carrusel | Diez JPEG distintos, 1000×1250, publicados sin sesión, con índices 01–10 en los nombres. No se compara visualmente todo el orden con la publicación original. |
| L08–L10 | Instagram sesión/story/highlight | Sin enlace ni sesión. No ejecutados. |
| L11 | Facebook | Un vídeo H.264/AAC de 97,097 s publicado y validado. |
| L12 | Reddit vídeo | Un vídeo H.264/AAC de 156,17 s publicado y validado. |
| L13 | Reddit galería | Supera el límite de espera de QA de 180 s. yt-dlp acaba con salida 1 alrededor del mismo límite. Sin descarga. Causa de incompatibilidad no atribuida a un defecto concreto. |
| L14 | Twitch | Un MP4 H.264/AAC de 5,007 s publicado y validado. El estado AX de cierre conserva un aviso pendiente de una operación anterior; no se certifica un cierre visual limpio de este caso. |
| L15 | Tumblr | URL del Excel rechazada antes de consultar la red: el validador exige `/post/`, ausente en `/nasa/178184776089/...`. Compatibilidad de este formato pendiente; no se comprueba la disponibilidad del post. |
| L16 | Threads | No se extrae contenido compatible. La UI informa del fallo y muestra referencia técnica. Sin archivo ni causa remota confirmada. |
| L17 | Snapchat | UI: 4 correctos / 1 fallido. Publica tres MP4 idénticos por SHA-256, 540×960, 87,3333 s, y un VTT como elemento principal. Duplicación y clasificación incorrecta. El lote continúa después del fallo. |
| L18 | EroMe | Sin enlace. No ejecutado. |
| L19 | YouTube directo/programado | Sin enlace. No ejecutado. |
| L20 | YouTube emisión finalizada | Analizada como emisión finalizada descargable, 6:22:51, cinco formatos y 159 pistas de subtítulos. No se descarga por duración. D-74 no se da por completado íntegramente. |
| L21 | YouTube no disponible | Rechazo visible «El contenido no está disponible», con referencia técnica. Sin archivo. Resultado negativo esperado. |
| L22/L23 | YouTube público | Un WebM AV1/Opus, 1920×1080, 337,481 s, publicado sin sesión. FFprobe reconoce contenedor y pistas; decodificación AV1 no disponible con el motor actual en este equipo. Se muestran 189 pistas de subtítulos, pero no se prueba exportación de subtítulos. Una sola descarga para la URL repetida. |
| L24 | TikTok vídeo | Un MP4 HEVC/AAC, 720×1280, 10,495 s, publicado y validado. |
| L25 | Pinterest | Un JPEG 1200×675 publicado y validado. |
| L26 | Vimeo | Un MP4 H.264/AAC, 320×180, 596,4583 s, publicado y validado. La disponibilidad de resoluciones superiores no se verifica independientemente. |
| L27 | Dailymotion | Un vídeo de 282:01 analizado y seleccionable. No se descarga por duración. |
| L28 | SoundCloud | Un archivo `.mp4` con pista AAC y sin vídeo, 85,0464 s, publicado y validado como audio. La UI lo etiqueta Vídeo y usa explicación de vídeos: clasificación/presentación incorrecta. El contenedor MP4 de solo audio no se trata por sí mismo como corrupción. |

## Incidencias comprobadas

### 1. Éxito aparente sin correspondencia con el tipo anunciado

En L01, el MP3 de 90.286 bytes tiene exactamente el SHA-256 de la tercera foto: `6054d22346707565f02122adf177b71f53a7c2bb47e4382a204835c5433bf46b`. FFprobe encuentra MJPEG 1080×1080 y ninguna pista de audio. Los registros identifican este elemento de gallery-dl con índice `0`.

La ruta actual conserva el `num` del extractor como `playlistIndex`. `GalleryDLDownloadCommandBuilder` añade `--range` solo para índices positivos y fuerza la extensión prevista en el nombre. El índice cero deja esa selección sin rango. Esta combinación es consistente con el resultado incorrecto observado; falta una prueba focalizada de los argumentos/extractor para certificar toda la cadena causal.

`DownloadOutputValidator` solo exige que FFprobe termine con código cero para extensiones audiovisuales y omite extensiones no reconocidas. No comprueba que un MP3 tenga audio ni que un elemento principal contenga vídeo/audio/foto en lugar de solo subtítulos. Así se explican los falsos positivos de L01 y L17 sin necesitar una caída del motor.

### 2. Un contenido aparece varias veces en el catálogo

L02 presenta cuatro variantes del vídeo. La comparación independiente de frames a 1, 15 y 45 s, normalizados a gris 64×36, encuentra diferencias medias absolutas inferiores a 0,59 sobre 255 entre todas las variantes y la primera, además de duración idéntica. Es una comprobación muestral, no un hash íntegro de contenido descomprimido.

L17 proporciona evidencia exacta: los tres MP4 comparten el SHA-256 `ba90b86ff17af0970c2eb81763ce5d206dbeefd0f38673eeed9204d222ad2bc9`. La agregación de extractores y descubrimiento HTML deduplica por referencias/URLs, pero no evita estas representaciones múltiples. También admite el VTT como resultado principal.

### 3. Presentación de errores y tipos

El perfil de Instagram bloqueado se transforma en un `DownloadAnalysis` con disponibilidad `unavailable` y causa en `description`. La tarjeta no muestra ese mensaje y recomienda activar secciones. No se interpreta un bloqueo temporal como autorización para usar sesión ni se aportan cookies como workaround.

SoundCloud conserva un archivo de audio correcto, pero la tarjeta utiliza Vídeo y el texto de vídeos descubiertos en páginas. Tumblr rechaza la forma concreta aportada por una regla de ruta anterior al análisis. Son problemas distintos de la indisponibilidad comprobada de L21.

## Cancelación y continuidad

Se inicia otro análisis de L13 únicamente para probar Cancelar desde UI. Antes: overlay de análisis y botón Analizar deshabilitado. Después: interfaz disponible, Analizar habilitado y ningún proceso de motor empaquetado observado. La recogida del estado posterior tarda 4,552 s desde el clic, incluyendo esperas y captura; no es una medición precisa de latencia de terminación.

El lote conjunto L21 + L22 muestra dos enlaces válidos, el fallo del primero y el segundo analizado y seleccionable. No se repite su descarga. Esto acredita continuidad del **análisis**. Separadamente, L17 acredita continuidad de la **descarga**: después del elemento fallido se publican elementos posteriores. Estos resultados no certifican cualquier clase de error ni limpieza en todos los fallbacks.

## Evidencia y problemas del controlador

La carpeta externa `QA-descargador-20261009` del chat conserva `results.json`, `media-verification.json`, `X-video-comparison.json`, `cancel-result.json`, `mixed-batch-result.json`, estados AX, capturas, SQLite, registros y archivos descargados. Los datos, capturas, URLs temporales y motores no se añaden al repositorio.

La automatización se detiene y se reanuda en puntos comprobados: rechazo de Tumblr, distinta jerarquía AX de hojas de resultado y falta temporal de acceso AX a la ventana al terminar SoundCloud. Esta última se recupera desde Ventana > Descargador universal, con el mismo proceso, y se guarda el resultado correcto. No se clasifican esos errores del controlador como caídas de ZEUVE. Un aviso pendiente de L13 aparece en evidencia posterior de Twitch y limita su aceptación visual. La cancelación intentada después del primer timeout de L13 encontró la operación ya terminada; solo la prueba separada acredita Cancelar.

## Próximo trabajo propuesto, todavía sin aprobar

1. Corregir selección de elementos de gallery-dl y validación por tipo, sin forzar conversión ni cambiar el modo Original. Área: `Engines/GalleryDL/GalleryDLAnalysisParser.swift`, `GalleryDLCommandBuilder.swift`, `Download/UniversalDownloadService.swift` y `DownloadOutputValidator.swift`, bajo `Sources/UniversalDownloaderModule`. Pruebas de índice cero, JPEG renombrado a MP3, ausencia de pista esperada, VTT principal, MP4 de solo audio legítimo y archivos auxiliares legítimos. El tipo esperado debe derivarse de una clasificación fiable del contenido, no asumir que cualquier MP4 tiene vídeo.
2. Corregir agregación/deduplicación y clasificación de audio/subtítulos en `Analysis/UniversalDownloadAnalysisService.swift`, `Discovery/UniversalPageDiscovery.swift` y los parsers pertinentes. Priorizar identidad estable y selección de calidad, sin descargar varias versiones ni colapsar dos elementos distintos de un carrusel. Añadir fixtures de X/Snapchat/SoundCloud y conservar continuidad/cancelación mediante `OperationCoordinator`.
3. Mostrar la causa de indisponibilidad de perfiles en `Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderView.swift` y revisar la regla Tumblr en `Validation/UniversalDownloadInputValidator.swift`. La aceptación de formatos alternativos requiere contrastar primero su routing y comportamiento, no desactivar validación de perfiles.

No se proponen motores/dependencias/permisos nuevos, importación de sesiones, recodificación automática, cambios de esquema ni sustitución de originales. Los fallos deben impedir publicar falsos resultados y conservar mensajes saneados; los temporales siguen siendo propios y la cancelación debe terminar los procesos antes de devolver disponibilidad. Después de aprobación: regresiones focalizadas, suites/verificadores y repetición acotada desde UI de Release con los enlaces aportados. La limitación AV1 y la revisión previa de saneamiento/URLs duplicadas deben evaluarse por separado antes de decidir cualquier cambio de motores o política de formatos.
