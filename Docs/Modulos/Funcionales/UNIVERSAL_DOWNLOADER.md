# Descargador universal 0.7.3 — ZEUVE 0.20.5.0

## Identidad

- Identificador: `com.zeuve.universal-downloader`.
- Identificador heredado reconocido: `com.zeuve.youtube-downloader`.
- Tecnología: Swift 6 con motores locales incluidos u opcionales.
- Versión mínima declarada en el manifest: ZEUVE 0.10.4.

## Organización interna 0.7.3

El target vigente es `UniversalDownloaderModule` y la UI vive en `Sources/ZEUVEApp/UniversalDownloader`. La organización vigente diferencia explícitamente:

- coordinación universal de análisis y descarga;
- lógica específica de plataforma bajo `Platforms` únicamente cuando existe una responsabilidad propia;
- lógica específica de motor bajo `Engines/YTDLP`, `Engines/GalleryDL`, `Engines/Instaloader` y `Engines/DirectHTTP`;
- servicios comunes de publicación, archivos, validación, almacenamiento y descubrimiento;
- modelos universales separados de los modelos de formato/progreso propios de yt-dlp.

`YouTubeURLCanonicalizer` y la política pública de clientes de YouTube conservan su nombre porque son realmente específicos de la plataforma. Los builders, parsers, formatos, caché y fragmentación que pertenecen a yt-dlp utilizan nombres `YTDLP*`.

Los identificadores y claves persistentes legacy no se renombran. `UniversalDownloaderStorageKeys.Legacy` documenta y conserva `youtube.defaultSettings`, `youtube.defaultAdvancedMode`, `youtubeDownloader.presets` y `youtubeDownloader.outputFolderBookmark`. El historial continúa aceptando `com.zeuve.youtube-downloader`.

Este cambio es estructural: para una misma entrada, configuración y entorno deben mantenerse la misma selección de motores, argumentos, fallbacks, resultados, publicación, historial y comportamiento visible.

## Estrategia multimotor

El módulo no obliga a utilizar un único extractor. `UniversalEngineRouter` elige una estrategia según la plataforma:

- `yt-dlp`: plataformas de vídeo y audio, enlaces directos, colecciones y numerosos sitios compatibles.
- `gallery-dl`: fotografías, galerías, carruseles y redes sociales orientadas a imágenes.
- `instaloader-zeuve`: resolución directa y catálogo progresivo de Instagram.
- extractor HTML de ZEUVE: archivos directos, reproductores y manifiestos encontrados en páginas concretas.
- FFmpeg/FFprobe: unión, remultiplexado y validación multimedia.
- navegador opcional: reservado como compatibilidad futura; en 0.7.3 no existe una opción funcional de instalación/activación ni participa en el routing porque el contrato ejecutable anterior estaba incompleto. Ajustes conserva únicamente una sección informativa heredada sobre esta posibilidad.

El orden puede usar motores de respaldo aprobados. No se rastrea un sitio completo desde una página genérica.

### Contrato de éxito y fallback

Un motor no se considera correcto solo por terminar con código cero. Antes de publicar, ZEUVE exige archivos candidatos no vacíos y válidos para el tipo anunciado. En contenidos compuestos también comprueba que estén presentes todos los elementos esperados y conserva su orden.

Si un intento falla, queda vacío o produce un conjunto incompleto, sus temporales se eliminan antes de ejecutar el siguiente motor. Las salidas de dos estrategias no se mezclan para aparentar un éxito completo. Cuando sea seguro continuar, un fallo aislado se informa como parcial sin detener los demás elementos del lote.


## Motores de Instagram

`gallery-dl` e `instaloader-zeuve` son obligatorios en una aplicación compilada 0.12.4. La compilación se detiene si faltan, son obsoletos o no coinciden con el manifiesto. Su preparación sigue siendo una acción explícita del desarrollador y nunca ocurre en segundo plano.

## Robustecimiento del ciclo de operación — ZEUVE 0.12.4

El ViewModel conserva una tarea propietaria para análisis/descarga y otra independiente para la importación expresa de sesión de Instagram. Una importación de sesión no puede sustituir la referencia de una operación activa. La descarga normal y la descarga tras confirmar un reemplazo convergen en el mismo ejecutor, por lo que comparten progreso, errores, cancelación, publicación e historial.

La finalización espera `OperationCoordinator.finish()` antes de devolver la interfaz a estado disponible. Los procesos externos quedan además ligados a la cancelación de la `Task` Swift propietaria mediante `ExternalProcessRunner`, que termina el grupo POSIX completo con la política ya aprobada. La detección de posibles duplicados mantiene incrementalmente sus firmas en lugar de volver a recorrer todos los análisis anteriores.

## Plataformas específicas

La versión inicial incluye estrategias específicas para YouTube, Instagram, TikTok, Pinterest, X/Twitter, Facebook, Reddit, Twitch, Vimeo, Dailymotion, SoundCloud, Tumblr, Threads, Snapchat público y EroMe.

Instagram admite perfiles completos. En el resto de redes se exige el enlace concreto de la publicación, vídeo, foto, álbum o contenido. EroMe solo acepta enlaces concretos.

La compatibilidad efectiva depende de que la plataforma continúe exponiendo el contenido y de los motores fijados. No se promete compatibilidad permanente con cualquier página de Internet.

## TikTok y descargas sociales 0.6.7

- Los enlaces concretos `/video/` y `/photo/` se clasifican directamente como vídeo o galería y usan `gallery-dl` como motor principal.
- El análisis interpreta el protocolo vigente de `gallery-dl 1.32.9` y conserva compatibilidad con el protocolo anterior.
- La descarga parte otra vez de la URL pública estable y selecciona el elemento por su posición. Así el motor puede renovar URLs firmadas y probar sus rutas alternativas ante un HTTP 403.
- Una ejecución no se considera correcta hasta que el espacio temporal contiene al menos un archivo candidato. Un código de salida cero con resultado vacío se trata como fallo.
- Si `gallery-dl` falla o termina vacío, ZEUVE limpia el espacio temporal y reintenta únicamente ese TikTok con el `yt-dlp` incluido y la misma URL pública estable. El respaldo debe terminar correctamente y producir archivos antes de publicar.
- Si ambos motores fallan, la operación queda marcada como fallo total, no publica restos parciales y muestra una referencia técnica saneada con acceso a los registros.
- El contenido se guarda en su formato original y se valida con FFprobe; no se recodifica.
- Las URLs firmadas, cookies y cabeceras de sesión permanecen fuera del historial, los metadatos, los registros y el ZIP del proyecto.

## YouTube público sin sesión 0.6.5

- Los vídeos públicos de YouTube se analizan y descargan sin cookies, cuenta ni sesión del navegador.
- En modo anónimo, ZEUVE configura automáticamente los clientes públicos `web_embedded,web_safari` del yt-dlp incluido. La segunda ruta permite un respaldo HLS cuando la transferencia directa es rechazada por YouTube.
- Análisis y descarga utilizan la misma política. Durante la descarga se vuelve a resolver la URL estable de YouTube y no se reutiliza una URL `googlevideo` firmada que pueda haber caducado o devolver HTTP 403.
- Un HTTP 403 o la ausencia de un PO token no se presentan por sí solos como una exigencia de iniciar sesión. ZEUVE informa de un rechazo temporal o de que no existe un formato público compatible.
- Las sesiones continúan disponibles únicamente como una opción expresa para contenido que realmente esté protegido por edad, cuenta o permisos. Un `cookies.txt` seleccionado conserva prioridad sobre la importación temporal del navegador.

## Instagram

Se puede introducir:

- `@usuario` o un nombre de usuario;
- enlace de perfil;
- publicación, fotografía, carrusel, vídeo o reel;
- story activa;
- historia destacada o elemento individual compatible.

El perfil se cataloga progresivamente. Puede mostrar publicaciones, fotos, vídeos, reels, stories activas, highlights y foto de perfil actual. No incluye publicaciones etiquetadas ni directos.

Las publicaciones y Reels directos públicos se resuelven primero con `instaloader-zeuve 4.15.3-zeuve.2`, sin cookies. El adaptador devuelve cada foto o vídeo del sidecar como un elemento independiente, conservando orden, tipo y formato. Si no puede resolverlo, ZEUVE continúa anónimamente con `gallery-dl`, `yt-dlp` y el descubrimiento genérico aprobado. Esta ruta conserva prioridad aunque exista una sesión guardada. Solo una señal explícita de contenido privado permite repetir con una sesión ya autorizada.

Redirecciones al inicio de sesión, respuestas 401, 403 o 429, límites temporales y mensajes ambiguos como `login required` no demuestran por sí solos que el contenido sea privado. No autorizan a adjuntar una sesión a una petición que todavía pueda resolverse públicamente.

## Perfiles por plataforma 0.7.3

«Por defecto de la plataforma» se resuelve para cada elemento, no para el lote completo. Todos los perfiles incorporados son editables desde Ajustes y pueden restaurarse individualmente o en conjunto. En 0.7.3, sus valores de fábrica son los mismos para todas las plataformas, incluido YouTube:

- contenido: «Original sin convertir»;
- calidad: mejor disponible;
- contenedor: automático, sin forzar conversión.

Por ello un lote mixto conserva, siempre que el origen y el motor lo permitan, JPEG, WebP, MP4, audio u otros formatos originales sin extracción automática de audio ni recodificación. Las opciones manuales «Vídeo», «Solo audio» y «Original» siguen disponibles y prevalecen cuando se seleccionan.

Las instalaciones procedentes de un esquema anterior migran únicamente el perfil de YouTube que coincida exactamente con el antiguo valor de fábrica MP3 320 kb/s. Cualquier personalización real del usuario se conserva.

La decisión utiliza la plataforma real detectada. Elegir una etiqueta genérica como «Página web» no transforma un enlace reconocido de Instagram o YouTube ni altera silenciosamente su política automática.

Cada operación conserva una instantánea de los ajustes ya resueltos para sus elementos. Editar un perfil después de preparar o iniciar una descarga no altera silenciosamente esa operación.

### Plataformas personalizadas

El usuario puede añadir una regla a partir de un enlace de ejemplo o un dominio. ZEUVE normaliza y guarda únicamente el host; descarta esquema, puerto, credenciales, ruta, consulta y fragmento. La regla puede aplicarse al dominio exacto o también a sus subdominios, y puede desactivarse sin eliminarla.

La comparación utiliza el origen estable de la página analizada, no una URL efímera del CDN. Si coinciden varias reglas gana el host más específico. El orden de prioridad es:

1. modo elegido manualmente para la operación;
2. regla personalizada por dominio;
3. perfil editable de la plataforma incorporada;
4. perfil genérico de página web;
5. valor de fábrica como recuperación defensiva.

Las reglas personalizadas configuran contenido, formato, calidad, nombres, conflictos, listas, metadatos, archivos auxiliares, subtítulos y procedencia cuando el motor y el tipo de contenido lo permiten. No almacenan sesiones, cookies, credenciales, proxy, carpeta de salida ni selecciones exactas de pistas. Crear una regla tampoco añade compatibilidad a una web que los motores no puedan resolver.

### Preset «Mejor calidad compatible»

Este preset utiliza «Original sin convertir» para cualquier plataforma: conserva fotografías, vídeos, audio y elementos de carruseles en el formato entregado por el origen, sin extracción automática de audio, recodificación ni contenedor forzado. Los presets 1080p, 720p y vídeo con subtítulos continúan siendo específicamente de vídeo.

Las instalaciones que todavía guardaban la copia incluida anterior en modo Vídeo la migran selectivamente al esquema 3. No se sustituye la lista completa ni se modifican presets personales con una configuración diferenciada.

La interfaz permite:

- cuadrícula o lista;
- tamaño de miniaturas;
- secciones visibles;
- número inicial y tamaño de cada carga adicional;
- selección individual o masiva;
- seleccionar solo contenido nuevo;
- carpetas por plataforma, perfil, sección, highlight o publicación múltiple.

## Perfiles privados y sesiones

ZEUVE no intenta saltar la privacidad. Si el perfil es privado o Instagram exige autenticación, el usuario debe proporcionar una sesión que ya tenga acceso mediante:

- cabecera `Cookie:` pegada;
- contenido de `cookies.txt`;
- archivo Netscape seleccionado;
- importación expresa desde Safari, Chrome, Firefox, Brave, Edge, Arc, Chromium, Opera o Vivaldi.

La sesión es temporal por defecto. Si el usuario activa «Recordar», se guarda en el Llavero de macOS. Nunca se solicita la contraseña de Instagram. Las sesiones no se escriben en logs, historial, presets, metadatos ni diagnósticos. Una sesión solo se aplica a un elemento cuya consulta haya necesitado autenticación; no se adjunta a descargas públicas.

La restauración global de Ajustes > General elimina del Llavero cualquier sesión de Instagram recordada y olvida la carpeta de salida persistida del Descargador. Conserva los presets y las reglas personalizadas por dominio, y no borra historial ni archivos descargados.

## Fotos de perfil

La foto actual se presenta en la mayor resolución accesible al extractor. Opcionalmente:

- ZEUVE puede conservar un historial local cuando detecta cambios después de una descarga autorizada;
- el usuario puede iniciar una búsqueda retrospectiva en Wayback Machine y otras fuentes públicas compatibles.

La búsqueda histórica no garantiza resultados. Solo se presentan imágenes que puedan recuperarse y asociarse a una captura; una página archivada sin imagen no se muestra como foto válida.

## Contenido adulto

«Permitir contenido para adultos» está desactivado por defecto. Si el dominio o la plataforma se clasifican como adultos:

- se bloquea el análisis antes de cargar miniaturas;
- se explica que debe activarse la opción en Ajustes > Descargador universal > Contenido;
- se ofrece abrir Ajustes;
- no se guardan cookies ni datos del contenido bloqueado.

La lista local cubre dominios conocidos y admite dominios adicionales configurados por el usuario. Ningún clasificador puede detectar de forma perfecta todas las páginas genéricas.

## Directos, DRM y acceso

No se descargan directos activos ni programados de ninguna plataforma. Una repetición publicada como vídeo normal puede tratarse como contenido ordinario.

ZEUVE no evita DRM, pagos, CAPTCHA ni controles de acceso. Solo utiliza contenido que la URL o la sesión autorizada ya pueden visualizar.

## Descarga y publicación

Las fotografías y archivos directos se descargan por streaming a temporales privados, sin recodificación. Se conserva la extensión real cuando puede determinarse. Las imágenes se validan por firma y los vídeos o audios con FFprobe antes de publicarse.

Las operaciones:

- no sobrescriben por defecto;
- publican mediante movimiento atómico cuando es posible;
- no publican `.part`;
- limpian únicamente temporales pertenecientes a la operación;
- continúan con el resto del lote cuando un elemento falla de forma aislada;
- muestran progreso real o indeterminado y resumen final.

## Metadatos

Opcionalmente se puede guardar descripción y un JSON sanitario con identificador, tipo, plataforma y metadatos disponibles. Se excluyen claves de cookies, sesiones, tokens, autorización, contraseñas, secretos, proxy y cabeceras.

## Motores externos

Ajustes > Descargador universal > Motores permite instalar desde un archivo local una versión estable o experimental en:

`~/Library/Application Support/ZEUVE/Engines/`

La versión incluida dentro de la aplicación no se modifica. Puede restaurarse en cualquier momento. Toda sustitución, incluso estable, muestra una advertencia; las versiones experimentales añaden una advertencia reforzada.

## Perfiles públicos de Instagram sin sesión 0.6.4

- Los perfiles públicos se analizan sin exigir una sesión: publicaciones, reels y foto de perfil continúan disponibles cuando los motores pueden consultarlos públicamente.
- Stories y Destacadas se omiten cuando no existe una sesión validada y se muestran como secciones no disponibles; no bloquean ni deshabilitan el resto del perfil.
- Una respuesta ambigua, un límite temporal o un endpoint que pida inicio de sesión no convierten el perfil en privado ni abren automáticamente la tarjeta obligatoria de autenticación.
- Si una sesión aportada es inválida, ZEUVE vuelve a intentar el perfil de forma anónima antes de declarar la consulta no disponible.
- `gallery-dl` continúa como respaldo público cuando `instaloader-zeuve` no resuelve el perfil.
- `instaloader-zeuve 4.15.3-zeuve.2` añade la resolución directa anónima de publicaciones, Reels y sidecars completos sobre Instaloader 4.15.3.
- La sesión sigue siendo obligatoria para perfiles privados sin acceso, stories, destacadas y enlaces concretos que Instagram proteja expresamente.
- Los registros indican solo si se aportó y validó una sesión, el motor, el fallback y las secciones restringidas; nunca guardan cookies, tokens ni el usuario de la cuenta iniciada.

## Persistencia secundaria del historial

El resultado de una descarga tiene prioridad sobre su entrada de historial. Si los archivos se descargan y publican correctamente pero falla únicamente la escritura en SQLite, la descarga sigue considerándose correcta y la interfaz muestra un aviso. El log asociado conserva solo el tipo técnico del error. No se añaden URLs, rutas, cookies, sesiones ni otros datos privados para diagnosticar ese fallo. El bookmark de salida usa la infraestructura común de `ZEUVECore`, manteniendo sin cambios las claves actual y legacy del Descargador.

## Organización de la vista — Fase 4

`UniversalDownloaderView.swift` conserva la composición principal de la herramienta y la tarjeta de ajustes se aloja en `Sources/ZEUVEApp/UniversalDownloader/Views/UniversalDownloaderSettingsCard.swift`. La extracción mantiene exactamente las opciones, textos, bindings, modos simple/avanzado y política de red/acceso ya aprobados; no crea una pantalla ni una configuración nueva.

`UniversalDownloaderViewModel` y `UniversalDownloadAnalysisService` se revisaron durante el saneamiento. Se mantienen como coordinadores porque su estado/tareas y su routing respectivamente forman ciclos cohesivos; no se dividen por un límite arbitrario de líneas ni se altera el orden de motores o fallbacks.

## Documentación relacionada

- [Privacidad y red](UNIVERSAL_DOWNLOADER_PRIVACY_AND_NETWORK.md)
- [Motores](../../Motores/UNIVERSAL_DOWNLOADER_ENGINES.md)
- [Empaquetado de motores](../../Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md)
- [Gestión y overrides](../../Motores/ENGINE_MANAGEMENT.md)
