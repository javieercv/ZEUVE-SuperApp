# Decisiones aprobadas de ZEUVE

Fecha de consolidación inicial: 6 de agosto de 2026. Actualizado para ZEUVE 0.20.3.0 el 24 de septiembre de 2026.

> **Cómo leer este documento:** las secciones con número de versión conservan la decisión aprobada en el momento en que se tomó. Cuando una decisión histórica fue sustituida, manda la decisión posterior y la documentación viva de `Docs/Fundamentos/`, `Docs/Modulos/` o `Docs/Motores/`. Este archivo no debe usarse como descripción cronológica del estado actual sin contrastar esas fuentes.

## Estado vigente de referencia — ZEUVE 0.20.3.0

Este bloque resume las decisiones actualmente efectivas que más fácilmente pueden confundirse con registros antiguos. No sustituye los detalles de cada sección ni las fuentes vivas.

- Built-ins: Organizador 0.1.4, Descargador 0.7.3, Analizador de chats 0.1.6, Conversor 0.3.0, Comparador de seguidores 0.1.0, Inspector multimedia 0.7.2 y Limpiador 0.1.1.
- Navegación: un orden personalizable compartido por Sidebar/Inicio/comandos; atajos personalizables o desactivables. Defaults ⌘1…⌘7 y ⌘8 para Historial. No hay preferencia de ocultación de módulos en 0.20.3.0.
- Ajustes: centralizados. Orden de secciones: Organizador 10, Descargador 20, Analizador 30, Conversor 40, Inspector 50 y Limpiador 60; el Comparador no tiene sección propia.
- Inspector: inspección + preview + análisis + edición estructural segura sin transcode audiovisual; la transformación que requiere recodificación pertenece al Conversor.
- Limpiador: `scanLocalStorage` autoriza análisis local documentado; cualquier retirada exige `removeLocalItems`, plan visible, selección y revalidación. Papelera es el modo seguro predeterminado y Undo solo aparece cuando es verificable.
- Motores requeridos por la instantánea actual: yt-dlp, Deno, FFmpeg, FFprobe, gallery-dl e instaloader-zeuve. Pandoc sigue soportado como opcional del Conversor cuando se prepara. Playwright no participa en la ruta efectiva actual. Calibre, Ghostscript y LibreOffice están retirados.
- Versión: ZEUVE 0.20.3.0, marketing 0.20.3, build 69.


## Limpiador 0.1.1 — corrección 0.20.3.0

- El análisis general y las mediciones largas deben atender cancelación de `OperationCoordinator`; cancelar devuelve la UI a un estado utilizable sin esperar a que finalice una consulta ya descartada.
- Spotlight tiene un límite de 30 segundos y una única salida por fin normal, indisponibilidad, cancelación o timeout. Un resultado incompleto se declara como cobertura parcial.
- Solo un inventario completo puede marcar aplicaciones históricas como ausentes; cobertura parcial nunca convierte falta de evidencia en prueba de desinstalación.
- La vista de Limpieza muestra el plan completo, incluidos datos persistentes no seleccionados automáticamente.
- En desinstalación, seleccionar elementos seguros conserva la `.app` elegida y solo añade asociados regenerables elegibles; desmarcar la app desmarca sus asociados.
- La confirmación previa enumera rutas, cantidad, tamaño, riesgo y modo. Tras ejecutar se renueva el análisis y la selección queda vacía.
- Undo solo se ofrece cuando hubo movimientos efectivos y verificables a Papelera.
- No cambian dependencias, motores, red, permisos ni esquema de almacenamiento.

## Inspector multimedia 0.7.2 — optimización 0.20.2.0

- Se conserva íntegramente el modelo estabilizado en 0.7.1: identidad solicitada/confirmada, generaciones, `MultimediaPreviewControlResolver`, pausa de vídeo con frame retenido y seek optimista.
- La cancelación acelerada es exclusiva de procesos efímeros de preview: 50 ms de gracia antes de SIGKILL. `ExternalProcessRunner` mantiene 2 s como valor predeterminado para el resto de ZEUVE.
- Pausar audio corta inmediatamente `AVAudioPlayerNode`/salida antes de esperar la limpieza completa; la posición se captura primero y FFmpeg continúa cerrándose de forma verificable.
- El monitor del preview deja de sondear al quedar pausado y evita reasignar propiedades/frame sin cambios. La reproducción activa mantiene la cadencia de snapshots aprobada.
- No cambian red, dependencias, motores, archivos originales, edición, análisis ni `OperationCoordinator`.

## Inspector multimedia 0.7.1 — corrección 0.20.1.0

- Estado y acción de preview se resuelven por identidad solicitada, identidad confirmada y transporte global.
- Pausar vídeo conserva fuente/frame; fullscreen usa la ventana propietaria.
- Al cancelar edición solo se conserva, pausada, una sesión formada enteramente por fuentes originales; cualquier fuente externa o no resoluble detiene toda la sesión.
- Rolloff, banda efectiva y caída persistente son métricas distintas; confianza y anomalías declaran cobertura, agrupación y truncado.
- El schema JSON sigue en 3 con campos aditivos y las mismas exclusiones de privacidad.

## Navegación personalizable y Limpiador 0.1.0 — 0.20.0.0

- Existe un único orden de módulos compartido por Sidebar, Inicio y comandos. El catálogo built-in conserva los defaults y la persistencia usa identificadores estables, no posiciones.
- Los atajos de módulos e Historial son configurables o pueden quedar desactivados; Inicio y Ajustes mantienen su comportamiento estándar. Los defaults son `⌘1`…`⌘7` y `⌘8` para Historial.
- El Limpiador es built-in, Swift nativo, local y sin red. V1 no incorpora helper root, `sudo`, shell ni dependencias externas.
- Se aprueban `scanLocalStorage` y `removeLocalItems` como permisos distintos. Analizar nunca equivale a eliminar: toda retirada requiere plan visible, selección y revalidación.
- Papelera es el modo predeterminado. Undo solo se ofrece cuando el elemento sigue verificable en Papelera y la ruta original está libre.
- `Conservar` persiste aparte del inventario. El reset global restaura preferencias pero no borra inventario, historial ni decisiones `Conservar`.
- App Groups compartidos, volúmenes externos ausentes, datos persistentes y cambios desde el análisis se tratan conservadoramente. Xcode Archives no son caché normal.

## Inspector multimedia 0.7.0 — decisiones del macro-bloque 0.19.0.0

- El preview de vídeo usa el FFmpeg aprobado y una superficie nativa; no se introduce VLC, mpv ni otro reproductor. `previewPosition`/la sesión de transporte siguen siendo la única fuente de verdad temporal y el reproductor de audio existente se conserva.
- El preview puede limitar resolución, FPS, buffer y decoder; los límites de seguridad que evitan OOM no son desactivables. VideoToolbox es una optimización, no un requisito, y debe existir fallback a software.
- HDR se considera preview de inspección, no monitorización HDR de referencia ni herramienta de color grading.
- ASS/SSA puede previsualizar contenido y timing, pero no se promete fidelidad completa de estilos mientras FFmpeg no incorpore libass.
- El modelo estructural admite vídeo, audio y subtítulos; `attached_pic`/carátulas se gestiona aparte. No se recodifica audio o vídeo para satisfacer una edición.
- El lote puede enumerar carpetas y aplicar reglas semánticas sobre streams reales. Es obligatorio hacer preflight antes de una edición masiva; no se emparejan automáticamente archivos externos por nombre.
- Los indicios de fuente previamente lossy son heurísticos y explicables. Un cutoff aislado no permite afirmar que un FLAC/ALAC/PCM sea falso.
- OCR de subtítulos bitmap es 100 % local mediante frameworks del sistema, produce un borrador revisable y nunca sustituye automáticamente el original.
- `favorites` se activa únicamente para configuraciones reutilizables (presets y conjuntos de reglas); no guarda rutas multimedia.
- Informes schema 3 son aditivos y no deben exportar rutas completas, fingerprints internos, PCM, frames, texto OCR/subtítulos ni metadata privada innecesaria.
- El Inspector sigue sin permiso de red y no añade motores/dependencias externas.

## Plataforma
- Aplicación nativa para macOS.
- Apple Silicon ARM64.
- macOS 14 Sonoma como versión mínima inicial.
- No se prepara todavía una versión para Windows, Linux o Mac Intel.

## Interfaz
- Diseño minimalista, coherente y con estilo macOS.
- Toda la interfaz visible estará en español.
- Modo claro, oscuro o según el sistema.
- Las herramientas ofrecerán modos simple y avanzado cuando tenga sentido.


## Interfaz y ayuda contextual 0.3.0
- Las opciones técnicas o ambiguas muestran un icono nativo `info.circle` junto a su nombre.
- Al pulsarlo se abre una explicación en español sencillo con consecuencias y recomendación cuando corresponda.
- El componente es común, accesible mediante teclado y VoiceOver, y compatible con los modos claro y oscuro.
- El sistema se aplica al Descargador, Organizador y Ajustes, y deberá reutilizarse en módulos futuros.
- No se añaden iconos informativos a acciones completamente evidentes para evitar ruido visual.


## Ajustes centralizados 0.4.0
- Todos los ajustes persistentes se administran desde el apartado general Ajustes.
- Ajustes ofrece una sección General y una sección propia para cada módulo configurable.
- El Organizador y el Descargador no muestran ruedas ni botones independientes de configuración.
- Las opciones de la operación actual permanecen dentro de la herramienta; los valores predeterminados se guardan en Ajustes.
- El Descargador conserva un selector rápido de presets, pero la creación, edición, eliminación y restauración se realiza en Ajustes > Descargador universal > Presets.
- El diagnóstico de motores se encuentra únicamente en Ajustes > Descargador universal > Diagnóstico.
- Cambiar valores predeterminados no modifica silenciosamente operaciones ya preparadas o en curso.
- Los módulos futuros deben integrarse en este mismo sistema y no crear ajustes independientes sin aprobación.

## Restablecimiento global de ajustes 0.12.3

- Ajustes > General ofrece una acción destructiva con confirmación para restaurar de una sola vez los valores de fábrica persistentes de ZEUVE y de todos los módulos configurables.
- La acción no borra la base de datos ni ejecuta un borrado genérico de la tabla `settings`; cada módulo restaura sus propios valores mediante sus APIs actuales para mantener coherentes la memoria y la persistencia.
- Se conservan historial, presets/preajustes, favoritas, perfiles personalizados por dominio, carpetas recientes del Organizador, motores instalados/overrides y archivos del usuario.
- El Descargador restablece preferencias generales, modo avanzado y perfiles incorporados, conserva perfiles personalizados y presets, elimina la sesión de Instagram recordada del Llavero y olvida los bookmarks de salida actuales y legacy.
- El Conversor restablece sus valores predeterminados y olvida su carpeta de salida recordada, pero conserva preajustes y favoritas.
- El tema vuelve a Sistema. El Comparador de seguidores no requiere acción porque no tiene ajustes persistentes en 0.8.0.
- El restablecimiento queda deshabilitado mientras exista una operación activa y no modifica silenciosamente una operación ya preparada.
- Un fallo de persistencia en una sección no aborta las demás restauraciones; los fallos se acumulan y se comunican al usuario.

## Valores predeterminados del Descargador 0.3.0
- Vídeo: contenedor MP4 por defecto; en modo simple también se puede elegir Automático, MKV o WebM.
- Audio: MP3 por defecto.
- MP3: 320 kbps por defecto, con opciones 128, 192, 256 y 320 kbps visibles solo al seleccionar MP3.
- Nombre de archivo: Título por defecto, sin añadir el ID.
- Los presets antiguos mantienen sus valores y se migran al esquema 2 sin perder configuraciones.

## Perfiles por plataforma y dominios personalizados 0.12.0

- «Por defecto de la plataforma» es una elección del usuario: los perfiles incorporados se editan en Ajustes y los valores definidos en código quedan únicamente como restauración de fábrica.
- La migración inicial copia los valores generales existentes a los perfiles incorporados para no cambiar las preferencias de una instalación actual. Una instalación nueva conserva YouTube en MP3 320 y los demás orígenes en contenido original.
- Se admiten reglas personalizadas por dominio exacto, con inclusión opcional de subdominios y posibilidad de desactivarlas.
- Solo se guarda el host normalizado. No se persisten rutas, consultas, fragmentos, credenciales, tokens ni URLs firmadas de contenido.
- El perfil se compara con el origen estable de la página y nunca con un CDN descubierto. Ante varias coincidencias gana el dominio más específico.
- La prioridad aprobada es: elección manual, regla personalizada, plataforma incorporada, página web y recuperación de fábrica.
- Cookies, sesiones, proxy, carpeta de salida y selección exacta de pistas siguen siendo datos de operación y no forman parte de perfiles persistentes.
- El plan guarda ajustes resueltos por elemento para impedir que una edición posterior cambie una descarga preparada o en curso.

## Integración central de módulos built-in 0.12.3

- Los módulos oficiales incorporados se describen en `ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift`. El catálogo es la fuente de integración para ID actual, aliases históricos, orden de navegación existente, disponibilidad de Ajustes, comando/atajo y presenters de historial.
- `AppModel` conserva propiedades fuertemente tipadas para cada ViewModel y sigue siendo responsable de construirlas. No se aprueba un contenedor type-erased, reflexión ni carga dinámica para los módulos oficiales.
- La vista concreta de cada herramienta se resuelve en un único `BuiltInModuleViewRouter`; las secciones persistentes de Ajustes se resuelven en `BuiltInModuleSettingsRouter`. Los routers son exhaustivos y permiten que el compilador obligue a integrar un nuevo caso.
- Barra lateral, Inicio, Ajustes y comandos consumen únicamente módulos cuyo manifiesto se haya registrado correctamente. Si falla el manifiesto o el registro, se muestra el aviso de arranque existente y la herramienta no se ofrece como disponible.
- El alias `com.zeuve.youtube-downloader` pertenece al descriptor del Descargador universal y se reutiliza también para presentar y filtrar historial legacy; no se vuelve a introducir como módulo visible independiente.
- Se conservan los órdenes actuales de barra lateral, Dashboard y Ajustes y los atajos ⌘1–⌘5. Esta fase no añade personalización del orden, visibilidad ni atajos y no modifica preferencias persistentes.
- `Package.swift` y los productos que enlaza `Scripts/generate_xcode_project.py` permanecen explícitos: son dependencias de compilación, no metadatos de presentación. El generador sigue descubriendo automáticamente todos los Swift de `Sources/ZEUVEApp`.

## Perfiles de fábrica del Descargador 0.12.3

- Los perfiles incorporados de fábrica de todas las plataformas, incluido YouTube, usan «Original sin convertir», mejor calidad disponible y contenedor automático.
- Esta decisión sustituye únicamente la antigua regla de fábrica que asignaba MP3 320 kb/s a YouTube en las decisiones 0.11.5 y 0.12.0. Esas entradas se conservan como registro histórico de las versiones en las que estuvieron vigentes.
- La migración desde esquemas anteriores solo sustituye el perfil de YouTube cuando coincide exactamente con el antiguo valor de fábrica MP3 320 kb/s; cualquier perfil personalizado por el usuario se conserva.
- «Por defecto de la plataforma» continúa resolviéndose por elemento y sigue respetando, por este orden, la elección manual, las reglas personalizadas por dominio, el perfil de plataforma, el perfil genérico de página web y el valor de fábrica de recuperación.
- No cambian motores, routing, privacidad, sesiones, cookies, publicación, historial, dependencias ni permisos como consecuencia de esta decisión.

## Saneamiento interno del Descargador universal 0.12.2

- El target oficial del módulo pasa de `YouTubeDownloaderModule` a `UniversalDownloaderModule`; la UI pasa a `Sources/ZEUVEApp/UniversalDownloader` y los tests a `Tests/UniversalDownloaderModuleTests`.
- Los nombres `YouTube*` se conservan únicamente para responsabilidades realmente específicas de YouTube o para identificadores/literales legacy que deben seguir leyéndose.
- Los builders, parsers, formatos, caché y política adaptativa propios de yt-dlp utilizan nombres `YTDLP*`; gallery-dl, instaloader-zeuve y HTTP directo se organizan como motores independientes.
- El módulo continúa siendo un único target. No se crean targets por plataforma o motor ni se añaden protocolos o dependencias generales sin necesidad funcional.
- `UniversalDownloaderViewModel` sigue coordinando SwiftUI, pero la persistencia/migración, construcción del plan y sesión de Instagram se separan en responsabilidades concretas.
- `UniversalDownloadAnalysisService` y `UniversalDownloadService` conservan el routing, orden de fallback, cancelación, publicación y uso de `OperationCoordinator`; las extracciones no pueden modificar argumentos de motor ni decisiones observables.
- Las claves `youtube.defaultSettings`, `youtube.defaultAdvancedMode`, `youtubeDownloader.presets`, `youtubeDownloader.outputFolderBookmark` y el identificador `com.zeuve.youtube-downloader` se mantienen como compatibilidad legacy. No se borran tras migrar.
- La clave Codable histórica `videoID` de los elementos de catálogo se conserva en datos, aunque el API Swift expone `canonicalID`. `Temporary/YouTube` también se mantiene como ruta legacy durante esta fase.
- No cambian red, sesiones, privacidad, motores, formatos, presets, historial, UX, permisos ni dependencias. Es un refactor con preservación de comportamiento.


## Preset universal original 0.12.1

- «Mejor calidad compatible» significa conservar el contenido original, no seleccionar únicamente vídeo. Se aplica a fotos, vídeos, audio, galerías y carruseles cuando el motor lo permite.
- Los presets que anuncian vídeo conservan expresamente el modo Vídeo y no heredan el modo Original del preset universal.
- La copia incluida persistida migra de vídeo genérico a Original sin eliminar la lista ni modificar presets personales con una configuración diferenciada.

## Arquitectura
- Swift 6 es la base del núcleo y de la aplicación.
- SwiftUI es la base visual y AppKit cubre integraciones avanzadas de macOS.
- Python, Rust u otros lenguajes pueden utilizarse de forma aislada cuando sean la mejor solución, pero ningún módulo aprobado actualmente depende de una instalación de Python del usuario.
- No se utiliza Flask, pywebview, Electron ni un servidor localhost como base.
- Solo puede ejecutarse una operación pesada principal a la vez.
- Los motores reutilizables se integran mediante `ZEUVEEngines`; la lógica específica permanece dentro de cada módulo.

## Módulos
- ZEUVE se diseña desde el inicio como una plataforma modular.
- Los módulos oficiales utilizan manifiestos, permisos, capacidades y una API versionada.
- La importación de módulos por el usuario se implementará en una versión futura.
- Los módulos externos deberán ejecutarse aislados y comunicarse mediante contratos estables.
- Los módulos nuevos deben seguir la documentación de `Docs/` y partir siempre del ZIP más reciente.
- ZEUVE 0.9.2 incluye el Organizador, el Descargador universal, el Analizador de chats, el Conversor universal y el Comparador de seguidores de Instagram.

## Persistencia e historial
- SQLite local sin dependencias Swift externas.
- Ajustes, historial y presets se guardan localmente.
- El historial global se dirige por `moduleID` y obtiene nombre e icono desde el registro de módulos.
- Cada módulo puede aportar su presentador de detalles sin acoplar la vista global a una lista cerrada.

## Privacidad
- Sin telemetría, analítica, publicidad ni comprobaciones automáticas de actualización.
- Procesamiento offline siempre que la función lo permita.
- El Organizador no utiliza Internet.
- El Descargador solo utiliza Internet tras una acción expresa de análisis o descarga.
- No se guardan URLs completas por defecto, URLs firmadas de googlevideo, cookies, tokens, cabeceras ni credenciales.
- Los logs aplican la misma política de minimización.

## Descargador universal 0.6.0 (ZEUVE 0.10.0)
- Identificador: `com.zeuve.universal-downloader`; tecnología `mixed`; modo `builtIn`.
- Utiliza un registro multimotor: el motor óptimo se elige por plataforma y tipo de contenido, con alternativas de respaldo y extractor genérico.
- Plataformas específicas iniciales: YouTube, Instagram, TikTok, Pinterest, X/Twitter, Facebook, Reddit, Twitch, Vimeo, Dailymotion, SoundCloud, Tumblr, Threads, Snapchat público y EroMe.
- Salvo Instagram, las redes sociales requieren el enlace concreto del contenido. EroMe solo admite enlaces concretos, no exploración de perfiles.
- Instagram acepta nombre de usuario, perfil y enlaces individuales. El catálogo muestra progresivamente publicaciones, fotos, vídeos, reels, carruseles, stories activas, historias destacadas y foto de perfil actual; no incluye etiquetadas ni directos.
- Las stories y los elementos de highlights son seleccionables individualmente. Los carruseles permiten seleccionar cada archivo.
- Los perfiles privados solo se catalogan mediante una sesión que ya tenga acceso. Se admite cabecera Cookie, `cookies.txt`, archivo seleccionado o importación expresa desde navegador. No se solicita contraseña ni se intenta eludir privacidad.
- La sesión es temporal por defecto; puede guardarse cifrada en el Llavero. Cookies, tokens y cabeceras quedan fuera de logs, historial, presets y diagnósticos.
- La foto actual se obtiene en la mayor resolución accesible. El historial local de cambios es opcional. La búsqueda retrospectiva en Wayback Machine y fuentes públicas es manual y no garantiza resultados.
- Se descargan fotos, vídeo y audio en su archivo original cuando es posible, sin recomprimir. FFprobe y validaciones de firma de imagen verifican los resultados antes de publicarlos.
- La interfaz ofrece selector de plataforma, cuadrícula/lista, secciones visibles, tamaño de miniaturas, lotes progresivos, carpetas, nombres, metadatos y selección de contenido nuevo configurables desde Ajustes.
- El contenido adulto está desactivado por defecto. Si se detecta un dominio adulto, el análisis se bloquea antes de cargar miniaturas y se indica cómo activarlo en Ajustes. La política se aplica a EroMe y al resto de dominios adultos conocidos o añadidos por el usuario.
- Los directos activos o programados quedan excluidos en todas las plataformas; una repetición publicada como vídeo normal puede descargarse.
- Motores: yt-dlp, Deno, FFmpeg/FFprobe, gallery-dl 1.32.9 e instaloader-zeuve 4.15.3-zeuve.2. Los dos últimos se preparan para ARM64 mediante el script aprobado.
- El navegador automatizado no forma parte del peso principal; se contempla como motor opcional instalado expresamente y utilizado solo como último recurso.
- Las actualizaciones de motores son manuales. Las versiones externas se guardan en `~/Library/Application Support/ZEUVE/Engines/`; la versión incluida permanece intacta y restaurable.
- Toda actualización, incluida una estable, muestra una advertencia de incompatibilidad. Las versiones experimentales muestran una advertencia adicional.
- No se eluden DRM, pagos, CAPTCHA, controles de acceso o restricciones para las que la sesión del usuario no tenga permiso.

## Analizador de chats 0.1.6 (ZEUVE 0.7.4)
- Identificador: `com.zeuve.chat-analyzer`; tecnología `swift`; modo `builtIn`.
- Procesamiento completamente offline de ZIP o TXT de WhatsApp, ZIP completos de Instagram, ZIP de una sola conversación y entradas avanzadas compatibles.
- Se analiza como máximo un chat lógico de WhatsApp y una conversación de Instagram por operación.
- Instagram se cataloga antes de analizar y procesa únicamente la conversación seleccionada. Si solo existe una, queda seleccionada automáticamente sin iniciar el análisis.
- `libarchive` del SDK/sistema se utiliza mediante un puente C mínimo; no se añade un paquete Swift externo.
- SQLite temporal es la fuente de almacenamiento auxiliar y se elimina al cerrar, cancelar o sustituir el análisis.
- Zona horaria predeterminada: California → España. Fechas numéricas ambiguas: día/mes/año.
- Mensajes del sistema se importan y cuentan en totales, pero se excluyen de perfiles y respuestas.
- Multimedia clásica: imagen, vídeo, audio y sticker; los nombres de sticker de WhatsApp prevalecen sobre la extensión WEBP y la definición puede configurarse desde Ajustes.
- Conversaciones predeterminadas: pausa de 3 horas, calculadas sobre la cronología completa y filtradas después.
- Respuestas predeterminadas: ventana máxima de 24 horas; puede elegirse sin límite dentro de la conversación.
- Fusiones, búsquedas y análisis son temporales y no se guardan.
- El historial almacena solo cantidades, plataformas, duración, estado y advertencias.
- Los archivos originales se abren en lectura y los adjuntos no se abren ni se decodifican. En un TXT directo se muestran como no comprobados, no como faltantes.
- El archivo de conversación no tiene límite de tamaño por defecto y se procesa progresivamente cuando el formato lo permite. El usuario puede activar un límite persistente desde Ajustes. Las protecciones estructurales del ZIP siguen siendo obligatorias.
- `Analizar otro chat` cierra la sesión temporal, limpia las fuentes y vuelve inmediatamente a la pantalla inicial del Analizador.
- `Cerrar análisis` cierra la sesión temporal, conserva las fuentes seleccionadas y vuelve inmediatamente a la pantalla inicial del Analizador.
- El cambio entre importación y resultados observa directamente el estado del Analizador y no depende de salir del módulo para actualizarse.
- Las nueve pestañas de resultados incluyen ayuda contextual general y explicaciones específicas en métricas, gráficos, opciones y columnas no evidentes.
- Las estadísticas derivadas se calculan fuera del hilo principal y se publican como instantáneas inmutables para mantener fluida la interfaz.
- Cada pestaña pesada se calcula solo al abrirse y reutiliza su caché mientras no cambien el chat, los filtros, las fusiones o los ajustes de los que depende.
- Los cambios rápidos cancelan cálculos obsoletos y una revisión interna impide publicar resultados pertenecientes a un estado anterior.
- Los filtros esperan brevemente antes de recalcular y la búsqueda aplica una espera de 200 ms; cambiar de página o contexto reutiliza el índice de coincidencias.
- Mientras se actualizan estadísticas se conserva el último resultado válido y se muestra un indicador discreto; nunca se presentan resultados parciales como definitivos.
- Cambiar una opción analítica invalida únicamente las secciones relacionadas y no reconstruye innecesariamente el resumen o los filtros básicos.
- Todos los gráficos de resultados son interactivos mediante hover: muestran el dato exacto y su fecha, periodo, hora o categoría sin requerir clic.
- El tooltip sigue la posición del cursor, cambia automáticamente de lado cerca de los bordes y permanece dentro del área visible del gráfico o mapa de calor.
- En gráficos comparativos el tooltip presenta todas las series visibles y el total conjunto del instante o categoría seleccionado.
- La interacción visual consume únicamente las instantáneas en caché, no recalcula estadísticas ni modifica filtros, mensajes o archivos.
- El mapa de calor utiliza el mismo criterio de resaltado y tooltip que los gráficos de líneas y barras.

## Conversor universal 0.3.0 (ZEUVE 0.11.0)
- Identificador: `com.zeuve.universal-converter`; versión del módulo `0.3.0`; tecnología `mixed`; modo `builtIn`.
- Procesamiento offline de imágenes rasterizadas y vectoriales compatibles, animaciones, audio, vídeo, PDF, texto, marcado, datos, carpetas y ZIP, limitado siempre a las capacidades realmente disponibles.
- Calibre y Ghostscript se eliminan completamente. No se convierten ebooks ni EPS.
- EPUB, MOBI, AZW/AZW3, FB2 y EPS se siguen detectando para mostrar un rechazo claro y no tratarlos como archivos genéricos.
- El Organizador conserva sus reglas de clasificación de libros electrónicos.
- Pandoc se mantiene únicamente para conversiones entre TXT, Markdown y HTML.
- Los lotes pueden mezclar formatos concretos de una misma categoría si todos admiten la operación, salida y ajustes comunes; no se mezclan categorías incompatibles.
- La detección combina extensión, firma, UTI, MIME, estructura contenedora y datos del motor. Una discrepancia queda visible y la extensión nunca prevalece automáticamente sobre evidencia fiable del contenido.
- La matriz central de compatibilidad decide qué conversiones se muestran y registra motor, pérdida, recodificación, copia directa, opciones, limitaciones y disponibilidad.
- Los ZIP se catalogan sin extracción completa, admiten conservar o aplanar estructura y aplican límites configurables de entradas, tamaño, profundidad y relación de compresión.
- Todos los originales se abren en lectura. Antes de publicar, cada salida se compara contra todas las rutas originales del lote y se valida con el motor correspondiente.
- La publicación utiliza temporales y sustitución atómica. La política predeterminada es renombrar; sin prefijo se usa `nombre - converted.ext` y después numeración segura.
- Los preajustes oficiales son Bajo, Medio, Alto, Máxima calidad y Personalizado; Máxima calidad es el valor predeterminado. Las favoritas, preajustes y ajustes portables no guardan entradas, contraseñas ni recursos privados.
- Los metadatos disponen de tres políticas: conservar compatibles, conservar esenciales y eliminar. No se copia contenido activo o peligroso.
- El paralelismo automático es conservador: las operaciones pesadas se serializan y solo las tareas nativas o de copia seguras pueden usar concurrencia limitada. El valor manual está acotado entre 1 y 8.
- Se admite contraseña local para ZIP y PDF compatible con PDFKit. Los formatos ofimáticos se retiraron completamente del Conversor en 0.7.3; CSV permanece como formato genérico de datos.
- Fuentes y modelos 3D quedan fuera de alcance en 0.7.0 por decisión aprobada.
- La experiencia nativa, VoiceOver, ImageIO, PDFKit, VideoToolbox, firma y apertura de la app requieren validación final en macOS Apple Silicon.
- En modo simple, una conversión de vídeo siempre recodifica la pista de vídeo; MP4 automático utiliza H.264. La copia rápida/remux solo puede activarse expresamente en modo avanzado y está desactivada por defecto.
- Los ajustes predeterminados anteriores migran a recodificación real. El preajuste oficial `Vídeo MP4 compatible` también se actualiza, mientras que los preajustes personalizados no se modifican silenciosamente.
- Vídeo → fotogramas escribe directamente en una carpeta visible `Procesando` dentro del destino. Al completar se renombra sin copiar todo el árbol; al cancelar, fallar o recuperar un cierre inesperado se conservan los fotogramas válidos en una carpeta `Incompleto`.
- PNG permanece sin pérdida y utiliza compresión nivel 3 con predictor Up. `tiempos.csv` se crea durante la misma ejecución de FFmpeg y el progreso informa del número real de fotogramas.

## Comparador de seguidores de Instagram 0.1.0 (ZEUVE 0.8.0)
- Identificador: `com.zeuve.instagram-followers`; tecnología `swift`; modo `builtIn`.
- Procesamiento completamente local y offline de una exportación ZIP de Meta o de un `following.json` junto con uno o varios `followers_<número>.json`.
- No se inicia sesión, no se utilizan cookies, tokens, APIs, scraping ni automatización de navegador.
- El ZIP se cataloga antes del análisis y solo se leen los JSON necesarios, sin extracción completa.
- Se rechazan rutas inseguras, enlaces simbólicos, cifrado, duplicados, conflictos por mayúsculas y límites sospechosos de entradas, tamaño, profundidad o compresión.
- Los archivos de seguidores se ordenan por su sufijo numérico y pueden contener huecos. Debe existir exactamente un `following.json`.
- La extracción de usuario prioriza `string_list_data[].value`, después URL de Instagram, `title` y el formato heredado `media_list_data`.
- La comparación ignora mayúsculas y `@` inicial, conserva puntos y guiones bajos y deduplica cuentas repetidas.
- Los resultados se dividen en cuentas que no siguen de vuelta, seguidores no seguidos y seguimiento mutuo.
- Búsqueda y ordenación trabajan sobre el resultado ya cargado y no vuelven a abrir el ZIP.
- La apertura de perfiles solo se produce al pulsar manualmente «Abrir en Instagram» y se identifica como acción externa.
- La exportación TXT/CSV usa una ubicación elegida por el usuario y no sobrescribe silenciosamente.
- El historial conserva únicamente datos agregados; nunca nombres de usuario, búsquedas, rutas completas ni URLs.
- No se añaden ajustes persistentes en esta versión porque no existe ninguna preferencia necesaria entre sesiones.

## Motores aprobados para 0.7.0 — registro histórico, sustituido en 0.11.0
- yt-dlp 2026.08.19 mediante la distribución oficial descomprimida para macOS.
- Deno 2.9.0 oficial para macOS ARM64.
- FFmpeg y FFprobe 8.1.2 compilados para ARM64 con libmp3lame, libopus, libx264 y libwebp estáticos, VideoToolbox y Apple ProRes.
- libx264 está aprobado para H.264 por software. libx265 permanece expresamente excluido.
- Pandoc 3.10 para conversiones de texto y marcado.
- Calibre 9.11.0 para libros electrónicos, integrado como aplicación completa y con su firma oficial conservada.
- Ghostscript 10.07.1 para EPS y flujos PostScript aprobados, ejecutado con modo seguro y recursos locales.
- Ningún motor se descarga durante el uso. Los motores opcionales se consideran `no proporcionados` hasta que `prepare_engines_macos.sh` los genere o copie y registre hashes y tamaños reales.
- No se utiliza Python del sistema, Homebrew, descarga dinámica de componentes, `--remote-components` ni actualización automática.
- Los motores se almacenan una sola vez bajo `Resources/Engines/` y `engines.json` registra versión, arquitectura, SHA-256, procedencia, licencia, función, diagnóstico, tamaño y obligatoriedad.
- SHA-256 y tamaño se verifican durante la preparación y antes del empaquetado. Tras firmar, el diagnóstico comprueba existencia, licencia, permisos, arquitectura, dependencias, lanzamiento y versión sin exigir el hash anterior a `codesign`.

## Base de motores tras la simplificación de ZEUVE 0.11.0
- yt-dlp, Deno, FFmpeg y FFprobe mantienen sus funciones aprobadas.
- Pandoc 3.10 se conserva para TXT, Markdown y HTML.
- Calibre y Ghostscript quedan retirados del código, registro, preparación, firma, verificación y empaquetado.
- Ningún motor se descarga durante el uso normal de la aplicación.

## Simplificación del Conversor 0.7.3
- LibreOffice se elimina por completo del código, registro de motores, preparación, diagnóstico, firma y empaquetado.
- El Conversor deja de admitir Word, Excel, PowerPoint, OpenDocument y RTF como entrada o salida.
- CSV se conserva como formato genérico de datos y para salidas auxiliares.
- El Organizador mantiene sus reglas de clasificación de extensiones porque no convierte ni abre esos formatos.

## Optimización de rendimiento 0.7.4
- El Descargador y el Conversor comparten el registro y la caché de diagnóstico de motores; la caché se invalida si cambian los archivos y la actualización manual forzada se mantiene.
- El Analizador crea el índice normalizado de búsqueda únicamente al utilizar la búsqueda. El índice es temporal, compacto, local y se elimina al cerrar o sustituir la sesión.
- Los índices de búsqueda pequeños se mantienen en memoria y los excepcionalmente grandes utilizan un archivo temporal mapeado dentro del espacio privado de la sesión.
- La caché de búsqueda no altera los criterios, resultados, filtros ni expresiones regulares; si no puede construirse, se conserva la búsqueda directa anterior.
- La escritura de mensajes en SQLite temporal reutiliza una sentencia preparada dentro de una transacción.
- Las actualizaciones muy frecuentes de yt-dlp y FFmpeg se agrupan conservando siempre el último valor y publicando inmediatamente cambios finales, errores y fases.
- El Conversor reutiliza el escáner mientras sus límites no cambien y calcula una sola vez el conjunto de rutas originales protegidas.
- Los rankings analíticos costosos se preparan con la instantánea y no se ordenan de nuevo por cada redibujado.
- La limpieza de temporales y la lectura del historial se realizan fuera del hilo principal; el historial incorpora un índice SQLite global por fecha.

## Procesos y cancelación
- No se utiliza `/bin/sh` ni interpolación de comandos.
- Los argumentos se pasan separados y validados.
- Cada motor se inicia con `posix_spawn` en un grupo de procesos independiente del proceso principal.
- La cancelación envía primero SIGTERM, espera un tiempo limitado y usa SIGKILL solo como último recurso.
- Se espera la terminación y se comprueba que no queden descendientes.
- El cierre de ZEUVE termina los grupos registrados.

## Archivos
- No se sobrescriben resultados sin autorización expresa.
- La opción predeterminada ante conflictos es renombrar automáticamente.
- yt-dlp escribe únicamente en temporales controlados por la operación.
- Los `.part` no se publican.
- Los resultados se verifican antes de moverse y las copias entre volúmenes usan un nombre temporal en destino antes del renombrado final.
- La limpieza solo elimina archivos que pertenecen de forma verificable a la operación.

## Distribución y seguridad
- App Sandbox permanece desactivado en 0.7.0.
- Hardened Runtime permanece activado.
- Se conservan las firmas oficiales de `yt-dlp` y Deno; Deno mantiene las autorizaciones JIT necesarias para V8. FFmpeg, FFprobe, Pandoc, gallery-dl e instaloader-zeuve se firman de forma explícita con la identidad de ZEUVE cuando están presentes.
- Sandbox requiere una prueba técnica específica posterior.
- No se incorporan binarios arbitrarios cuando el entorno no permite generar y verificar los binarios ARM64 aprobados.

## Desarrollo y entrega
- Antes de implementar cambios se presenta un plan y se espera aprobación.
- No se refactorizan ni modifican partes no solicitadas.
- El proyecto se actualiza en su única carpeta activa conservando el nombre existente; solo se genera un ZIP o una carpeta versionada adicional cuando el usuario lo solicita expresamente.
- No se afirma que una app se ha compilado o abierto sin haberlo comprobado realmente.

## Corrección de preparación de motores 0.7.1 — registro histórico
- La licencia de Calibre 9.11.0 se obtiene desde el archivo oficial `LICENSE` del tag fijado cuando no está incluida dentro de `Calibre.app`.
- Se elimina la referencia inexistente a `COPYING`, que devolvía HTTP 404 y detenía la preparación antes de FFmpeg, Ghostscript y la publicación final de `Resources/Engines`.

## Corrección del Descargador universal 0.10.1
- `gallery-dl` e `instaloader-zeuve` deben estar incluidos realmente en cualquier aplicación 0.10.1 compilada; no basta con declararlos como opcionales con tamaño y hash vacíos.
- La compilación por Terminal prepara automáticamente ambos motores cuando faltan y actualiza sus hashes, tamaños y licencias antes de verificar.
- La compilación directa desde Xcode debe detenerse si los motores sociales no están preparados, para no generar otra aplicación que anuncie Instagram sin poder utilizarlo.
- Los enlaces de Instagram conservan la plataforma y el tipo real aunque el usuario seleccione «Página web».
- Cuando Instagram exige autenticación, la interfaz debe indicar que se necesita una sesión temporal o `cookies.txt`; los registros nunca incluyen cookies ni la sesión.

## Corrección del Descargador universal 0.10.2
- La respuesta `Profile … does not exist` de Instaloader se considera no concluyente cuando puede deberse a autenticación, bloqueo o limitación temporal.
- Un perfil no comprobable debe ofrecer acceso a la sesión y no afirmar que el perfil no existe sin evidencia suficiente.
- Los perfiles de Instagram utilizan realmente `gallery-dl` como fallback tras un resultado no concluyente de `instaloader-zeuve`.
- Los registros pueden indicar sesión aportada y sesión validada mediante valores booleanos, pero nunca cookies, tokens ni el nombre de la cuenta iniciada.
- La revisión mínima del ayudante social es `4.15.2-zeuve.2`; una compilación debe regenerar el motor si falta o conserva la revisión anterior.

## Perfiles públicos de Instagram 0.10.3

- Un perfil público no exige sesión para analizar publicaciones, reels y foto de perfil.
- Sin sesión validada, Stories y Destacadas se omiten y se muestran como no disponibles; no bloquean el contenido público ni deshabilitan su descarga.
- Una consulta pública bloqueada o no concluyente no se interpreta como perfil privado y no abre automáticamente una solicitud obligatoria de sesión.
- Una sesión inválida no impide probar de nuevo el perfil de forma anónima.
- La sesión solo es obligatoria cuando se confirma un perfil privado sin acceso o cuando el contenido concreto requiere autenticación.
- `gallery-dl` permanece como fallback público y `instaloader-zeuve 4.15.2-zeuve.3` es la revisión mínima aprobada.
## Simplificación de motores y formatos 0.11.0
- Se eliminan Calibre y Ghostscript por decisión expresa.
- El Conversor deja de admitir conversiones de EPUB, MOBI, AZW/AZW3, FB2, EPS y PostScript.
- La detección de esos formatos se conserva para informar correctamente al usuario.
- El Organizador mantiene la clasificación de ebooks y EPS.
- Pandoc se mantiene para TXT, Markdown y HTML.
- Las menciones de Calibre y Ghostscript en informes y changelogs antiguos se conservan como registro histórico.

## Corrección de resolución de perfiles públicos 0.10.4

- Instaloader se actualiza de 4.15.2 a 4.15.3 porque la versión oficial nueva corrige la resolución de perfiles públicos tras el cambio de Instagram.
- La revisión incluida mínima pasa a ser `instaloader-zeuve 4.15.3-zeuve.1`; cualquier binario 4.15.2 se considera obsoleto y debe regenerarse antes de compilar.
- El ejecutable ARM64 anterior se retira del ZIP fuente para impedir que una aplicación vuelva a empaquetar el motor defectuoso.
- Se mantienen sin cambios `gallery-dl` como fallback, el acceso público sin sesión y la exigencia de sesión únicamente para perfiles privados o secciones protegidas.
- No se añaden servidores, proxies, APIs, telemetría ni dependencias nuevas para el usuario final.

## YouTube público sin sesión 0.11.1

- El Descargador debe analizar y descargar vídeos públicos de YouTube sin exigir cookies, cuenta ni sesión del navegador.
- Cuando no hay sesión expresa, análisis y descarga emplean automáticamente la cadena de clientes públicos `web_embedded,web_safari` del yt-dlp incluido.
- La descarga anónima vuelve a resolver la URL estable de YouTube; no reutiliza URLs multimedia firmadas obtenidas durante el análisis.
- HTTP 403 y los avisos de PO token no implican automáticamente autenticación. Solo se solicita una sesión cuando el contenido confirma una restricción real de cuenta, edad o permisos.
- La corrección no añade dependencias, servicios remotos, tokens externos, telemetría ni cambios de privacidad.
- La verificación del paquete debe ejecutar JavaScript con Deno para detectar una pérdida de sus autorizaciones JIT antes de entregar la aplicación.

## Descarga social y TikTok 0.11.2

- Los enlaces concretos de TikTok se analizan y descargan principalmente con gallery-dl 1.32.9; yt-dlp permanece como respaldo porque una regresión externa puede afectar a uno de los motores.
- El protocolo aprobado de gallery-dl usa Directory=2, URL=3 y Queue=6. Se mantiene lectura heredada para no romper fixtures o salidas antiguas.
- La descarga social vuelve a resolver la página pública estable y selecciona el elemento por rango. No persiste URLs firmadas del CDN y deja al motor aplicar sus fallbacks internos.
- gallery-dl e instaloader-zeuve son obligatorios para cualquier aplicación 0.11.2 compilada. Su preparación es manual y reproducible; las compilaciones de Terminal y Xcode solo verifican y fallan de forma clara si faltan.
- ZEUVE no añade servicios, APIs, proxies, telemetría, cuentas ni permisos nuevos para esta corrección.

## Verificación de salida y respaldo de TikTok 0.11.3

- Ningún motor de descarga se da por correcto únicamente por terminar con código cero: la operación debe producir al menos un archivo candidato en el espacio temporal.
- Para enlaces concretos de TikTok, `gallery-dl 1.32.9` conserva la prioridad y sus rutas internas de CDN. Si falla o termina vacío, ZEUVE elimina cualquier resultado parcial y reintenta la URL pública estable con el `yt-dlp` incluido.
- El respaldo se limita a TikTok y no altera el enrutado de las demás plataformas. También debe terminar correctamente y producir archivos antes de iniciar la publicación.
- Si ambos intentos fallan, la interfaz presenta un fallo total, indica que no se guardó ningún archivo y permite abrir los registros mediante una referencia técnica saneada.
- La corrección no modifica los binarios fijados, no añade dependencias, servicios, APIs, permisos, telemetría ni persistencia de URLs firmadas o datos de sesión.

## Instagram público anónimo 0.11.4 — registro histórico, sustituido en 0.11.5

- Los reels, publicaciones y demás enlaces concretos públicos de Instagram se analizan primero con `yt-dlp 2026.08.19`, sin cookies, cuenta ni sesión del navegador.
- Una sesión disponible para perfiles privados no se envía a un enlace concreto que ya se haya resuelto públicamente; la misma política se aplica durante la descarga.
- `gallery-dl 1.32.9` permanece como respaldo anónimo. Una redirección al login, un límite temporal o el mensaje ambiguo «login required» no confirman por sí solos que el contenido sea privado.
- Solo una indicación explícita de cuenta o perfil privado permite presentar la sesión como necesaria. Los perfiles completos conservan el catálogo de `instaloader-zeuve` y su detección expresa de privacidad.
- No se añaden servicios externos, APIs de terceros, telemetría, permisos ni lectura silenciosa de cookies.

## Enrutado específico de Instagram y automático por plataforma 0.11.5

- Las publicaciones y Reels directos de Instagram priorizan `instaloader-zeuve` de forma anónima. `gallery-dl`, `yt-dlp` y el descubrimiento genérico permanecen como fallbacks, sin convertir Instagram en el centro de la arquitectura universal.
- `instaloader-zeuve` representa cada nodo de un carrusel como un elemento independiente y conserva su orden, tipo y referencia original; el descargador no recodifica esos archivos.
- Una publicación compuesta solo se considera resuelta completamente cuando están presentes todos los nodos esperados. Un intento vacío o incompleto no impide probar el siguiente motor y sus resultados parciales no se mezclan con los del fallback.
- Los errores públicos ambiguos no autorizan el uso de sesión. Solo una señal explícita de contenido privado permite repetir con una sesión ya aportada por el usuario.
- La selección predeterminada es una política, no un formato global: YouTube usa MP3 a 320 kb/s; cualquier otro origen usa el original de máxima calidad. En lotes mixtos se decide por elemento.
- Las selecciones manuales «Vídeo» y «Solo audio» continúan disponibles y anulan la política automática.
- La corrección reutiliza exclusivamente `instaloader-zeuve`, `gallery-dl` y `yt-dlp`; no añade motores, dependencias, servicios, permisos ni lectura silenciosa de sesiones.

## Infraestructura compartida y fallo secundario de historial — 2026-09-07

- La mecánica genérica de bookmarks de carpetas y acceso `security-scoped` se comparte desde `ZEUVECore`. Cada módulo mantiene sus propias claves persistentes, validadores, migraciones y políticas de salida.
- Si una operación principal termina correctamente y falla únicamente el guardado de historial, la operación **permanece correcta** y ZEUVE muestra un aviso específico. El fallo del historial no puede convertir retrospectivamente en fallida una descarga, conversión, análisis, comparación u organización ya completada.
- El diagnóstico de ese fallo se limita a metadatos técnicos saneados, actualmente el tipo de error. No se registran rutas, nombres de archivos, URLs, contenido tratado, sesiones, cookies, tokens ni credenciales.
- Si una capacidad posterior depende obligatoriamente del registro de historial, esa capacidad queda no disponible únicamente para la ejecución cuyo registro no pudo persistirse. En el Organizador esto significa que no se ofrece «Deshacer» para esa ejecución concreta; los movimientos ya completados no se revierten ni se marcan como fallidos.
- Cada operación pesada tiene un único propietario de su ciclo en `OperationCoordinator`. Para módulos nuevos se prefiere que sea el servicio responsable de la ejecución pesada; una orquestación en `ZEUVEApp` sigue siendo válida cuando esa capa coordina explícitamente varias responsabilidades. No debe haber doble `begin/finish` para una misma operación y la liberación debe garantizarse en éxito, error y cancelación.

## Organización interna por responsabilidad — 0.12.3 / Fase 4

- La mantenibilidad se mejora separando fuentes únicamente cuando existe una responsabilidad autónoma y la API/comportamiento pueden conservarse. No se adopta un límite máximo de líneas como criterio arquitectónico.
- Las vistas de resultados del Analizador, los modelos del Conversor y la implementación interna de `ChatAnalytics` pueden distribuirse en archivos por dominio sin crear targets ni contratos nuevos.
- Helpers técnicos independientes, como el soporte de progreso/diagnóstico FFmpeg, pueden extraerse del coordinador siempre que no cambien ejecución, argumentos, publicación, cancelación o privacidad.
- No se fragmentan ViewModels o coordinadores estrechamente acoplados si ello requiere ampliar estado privado, repartir la propiedad de tareas/cancelación o introducir capas sin responsabilidad propia.
- Esta organización es saneamiento interno: no autoriza cambios de UI, opciones, persistencia, formatos, motores, red, dependencias ni comportamiento visible.
## Verificación modular y coherencia de build — 0.12.3 / Fase 5

- `Scripts/verify_project.sh` continúa siendo el comando oficial de verificación, pero debe actuar como orquestador y no volver a acumular grandes bloques de comprobaciones por módulo. Las reglas se agrupan bajo `Scripts/verify/` por responsabilidad.
- Una reorganización del verificador no puede eliminar guardarraíles existentes. Las verificaciones textuales se reservan para invariantes estructurales, seguridad o contenido expresamente prohibido; cuando exista un test ejecutable equivalente y estable, se prefiere dicho test.
- `Package.swift` y `Scripts/generate_xcode_project.py` siguen siendo explícitos, pero su duplicación se protege automáticamente: todos los productos de biblioteca SwiftPM deben coincidir con la lista del generador y con el proyecto Xcode regenerado.
- La validación portable de `ZEUVEApp` mediante parseo sintáctico es útil pero no sustituye la compilación real. En macOS Apple Silicon la validación de aplicación debe incluir motores y `xcodebuild` mediante `Scripts/verify_app_macos.sh`.
- Los tests grandes se dividen solo cuando existen grupos funcionales con fixtures independientes. No se amplía visibilidad o se duplican helpers únicamente para reducir líneas de un archivo de pruebas.



## Robustecimiento de operaciones, privacidad y análisis escalable — 0.12.4

- El ciclo de una operación pesada debe permanecer estructurado hasta que `OperationCoordinator.finish()` haya terminado. La interfaz no vuelve a estado disponible antes de liberar el coordinador.
- Una `Task` Swift propietaria de un proceso externo debe cancelar también el grupo POSIX asociado. `ExternalProcessRunner` aplica esta garantía además de conservar la cancelación explícita idempotente, SIGTERM, periodo de gracia y SIGKILL como último recurso.
- El Descargador separa la tarea de operación de la importación de sesión de Instagram y utiliza un único ejecutor para descarga normal y reemplazo confirmado. La sesión no puede sustituir la referencia de una operación activa.
- Los logs locales se minimizan: no deben registrar rutas completas de usuario cuando no sean imprescindibles. `LocalLogger` conserva únicamente archivos propios `zeuve-AAAA-MM-DD.jsonl`, con retención automática de 30 días, máximo global de 50 MiB y permisos restrictivos cuando el sistema lo permite.
- La búsqueda manual de avatares históricos de Instagram usa una sesión `URLSession` efímera dedicada, sin caché ni almacén persistente de cookies, con timeout de petición de 30 s y de recurso de 120 s. No se amplían endpoints ni se automatiza la consulta.
- Un bookmark de carpeta que no pueda resolverse en un intento no se elimina automáticamente. Los bookmarks stale resolubles se refrescan y la eliminación queda reservada a sustitución/restablecimiento explícito o a una invalidación inequívoca. Nunca se toca la carpeta señalada.
- El Analizador de chats utiliza SQLite temporal como fuente principal de los mensajes de sesión. La importación se realiza incrementalmente, la deduplicación global y el orden estable se materializan en SQLite y las analíticas/búsquedas recorren el store por lotes o devuelven agregados/páginas compactas. No se reduce el límite estructural aprobado de mensajes para ocultar consumo de memoria.
- Las rutas ZIP normalizadas duplicadas se rechazan. La lectura mediante libarchive comprueba cancelación entre entradas y bloques para no prolongar innecesariamente una operación cancelada.
- El tamaño de un ViewModel no autoriza por sí solo una división. En 0.12.4 solo se separan responsabilidades cuando existe una propiedad o ciclo independiente demostrado.
- La infraestructura de QA sigue basada en los verificadores locales del proyecto y la validación macOS Apple Silicon. 0.12.4 no introduce CI, servicios remotos ni dependencias nuevas.

## Inspector multimedia 0.13.0

- Se aprueba `MultimediaInspectorModule` como sexto módulo built-in, ID `com.zeuve.multimedia-inspector`, versión 0.1.0, icono `waveform.path.ecg` y atajo `⌘6`; Historial pasa a `⌘7`.
- Todo archivo empieza siempre en modo inspección/solo lectura. Solo `Editar` crea un `MediaEditDraft`; Undo/Redo actúa únicamente sobre ese draft.
- La inspección FFprobe se comparte en `ZEUVEEngines/MediaInspection`; el Conversor universal migra a esa capa sin cambios funcionales y no debe mantener un parser FFprobe duplicado.
- La edición inicial se limita a MKV/MP4/MOV/WebM. Vídeo y audio nunca se recodifican automáticamente; si no caben por stream copy se propone otro contenedor compatible o se bloquea la operación y se deriva al Conversor.
- Los subtítulos sí pueden convertirse de forma auxiliar cuando la compatibilidad lo requiere y el usuario lo autoriza de manera expresa; no se realiza OCR.
- El original nunca se sobrescribe. Se usan fingerprints, workspace temporal, validación FFprobe y publicación segura antes de considerar el resultado válido.
- Remux, espectrograma y exportación pesada respetan `OperationCoordinator`. FFprobe ligero puede ejecutarse sin reservar la operación global.
- El espectrograma se implementa de forma independiente con FFmpeg → PCM incremental → Accelerate/vDSP → dB → render nativo. Spek 0.8.5 se utiliza únicamente como referencia funcional/técnica clean-room; no se copia, porta, enlaza ni incorpora código GPL o wxWidgets.
- `MultimediaInspectorPreferences` prepara defaults futuros, pero 0.13.0 no muestra ajustes del Inspector y mantiene `settingsOrder: nil`. Cualquier futura UI persistente irá a `SettingsView`/`SettingsRepository`.
- El módulo es completamente local, no solicita red y no añade dependencias ni motores externos.


## Versionado de cuatro componentes — 0.13.1.0

- La versión canónica de la aplicación pasa a `MAJOR.MINOR.PATCH.REVISION`. `REVISION` se reserva para correcciones técnicas mínimas sin cambio funcional; `PATCH` identifica correcciones o mejoras reales de mantenimiento.
- La versión mostrada por ZEUVE y el archivo `VERSION` usan cuatro componentes.
- Para respetar el formato de Apple, `MARKETING_VERSION`/`CFBundleShortVersionString` conserva `MAJOR.MINOR.PATCH`; `ZEUVEReleaseRevision` guarda el cuarto componente y `ZEUVEProductInfo.releaseVersion` compone la versión visible.
- `CURRENT_PROJECT_VERSION` sigue siendo el build interno independiente y debe incrementarse en cada build entregable nueva.
- Los manifiestos de módulos mantienen `MAJOR.MINOR.PATCH` porque forman parte del contrato `ModuleManifest`/API 1.0. No se cambia ese contrato mediante esta decisión.
- La corrección de compilación Swift 6 recibida después de 0.13.0 se clasifica bajo el nuevo esquema como 0.13.0.1; la Fase 1 del Inspector se entrega como 0.13.1.0.

## Inspector multimedia — saneamiento técnico Fase 1 — 0.13.1.0

- Pantalla y PNG comparten `SpectrogramRenderMapping`; no puede existir una interpretación lineal en exportación cuando la UI está en escala logarítmica.
- La mezcla de visualización multicanal combina potencia espectral por canal. No genera audio ni modifica el contenido fuente; su objetivo es evitar cancelaciones de fase artificiales en la representación.
- `SpectrogramFFTAnalyzer` reutiliza ventana y setup FFT durante una petición; el API público de `SpectrogramFFTProcessor` se conserva para pruebas y cálculo aislado.
- El acumulador usa lectura indexada y compactación por bloques. Cuando la duración es conocida, agrega directamente en buckets temporales acotados por `maximumColumns`; no necesita crecer hasta duplicar el límite antes de compactar.
- El render SwiftUI precalcula el mapeo vertical antes de dibujar el Canvas. La exportación crea un buffer RGBA acotado y aplica el mismo mapeo de frecuencia.
- Cancelar el análisis o la exportación es un estado esperado y no se muestra como error.
- No se añaden dependencias, red, APIs, motores, persistencia ni nuevas opciones visibles.

## Inspector multimedia — rendimiento del espectrograma Fase 2 — 0.13.2.0

- `SpectrogramAnalysisPlanner` conserva análisis denso para archivos cortos y, en archivos largos, distribuye hasta ocho FFT dentro de cada intervalo de columna. El presupuesto máximo depende de resolución, FFT y memoria, no crece linealmente con la duración.
- La mezcla sigue promediando potencia espectral por bin y canal. Un canal individual de una pista con más de dos canales se extrae en FFmpeg; estéreo permanece interleaved porque la medición no mostró una mejora material al aplicar `pan`.
- Ventana, setup DFT y buffers se reutilizan durante una petición. El modelo guarda dB sin clipping destructivo para que rango, escala y zoom no repitan el análisis.
- La caché espectral es solo de memoria, LRU, limitada a cuatro entradas y 64 MiB e invalidada mediante `FileFingerprint`. No persiste rutas, PCM ni metadatos.
- El lector POSIX inicia motores con máscara de señales vacía para que la cancelación por `SIGTERM` funcione aunque el worker de origen bloquee señales.
- El render del Canvas utiliza un raster calculado fuera de `@MainActor`. La UI recibe únicamente el resultado inmutable y conserva aislamiento Swift 6.
- Se mantiene el máximo de 1.800 columnas y un presupuesto adicional de 64 MiB para el modelo. No se añaden dependencias, red, APIs, telemetría, permisos ni ajustes visibles.


## Inspector multimedia — experiencia técnica y previsualización — 0.14.0.0

- Se aprueba un reproductor de **previsualización de audio**, no un editor temporal. Sirve para escuchar pistas durante inspección y preparación del draft; no introduce timeline, cortes, mezcla creativa, efectos ni exportación.
- La reproducción universal de audio utiliza los FFmpeg empaquetados para decodificar el stream exacto a PCM por streaming y AVAudioEngine/AVAudioPlayerNode para salida local en macOS. No se añade AVPlayer como única ruta porque no cubre el mismo conjunto de contenedores/códecs que FFmpeg.
- La cola PCM debe permanecer acotada y aplicar back-pressure. Pausar detiene la decodificación y reanudar vuelve a abrir el stream desde la posición retenida; cerrar/cambiar archivo/cancelar edición detiene la previsualización.
- Reproducir no reserva `OperationCoordinator`, porque es una herramienta ligera de inspección que debe poder convivir con el espectrograma. Tampoco crea historial, archivos permanentes, red, telemetría ni persistencia de PCM.
- Los audios externos añadidos al draft pueden previsualizarse antes del remux, siempre tras revalidar su fingerprint. El reproductor nunca sustituye las validaciones de edición/publicación.
- El espectrograma puede iniciar/seekear la reproducción desde el punto inspeccionado y mostrar un playhead sincronizado. Rango dinámico, escala y zoom siguen siendo reinterpretaciones visuales y no relanzan FFmpeg/FFT.
- Los nombres de canal solo se muestran como L/R/C/LFE/SL/SR/etc. cuando el `channel_layout` permite una correspondencia segura; en caso contrario se usa `Canal N`.
- Chapters, attachments, attached pictures, programs, data streams y streams desconocidos se amplían únicamente en lectura. 0.14.0.0 no autoriza su edición.
- El reproductor audiovisual universal con decodificación/render de vídeo FFmpeg queda fuera de 0.14.0.0. Una preview de vídeo futura requerirá decisión y alcance propios.

## Inspector multimedia — navegación avanzada de audio — 0.15.0.0

- Se aprueba una sesión reutilizable: el usuario puede cerrar el análisis actual o sustituirlo sin reiniciar ZEUVE. Un borrador sucio exige confirmación.
- La waveform pasa a ser el scrubber del reproductor y debe ser bipolar real: máximo positivo y mínimo negativo por intervalo, nunca una mitad superior duplicada/invertida. La mezcla multicanal preserva extremos/energía sin downmix PCM susceptible a cancelación.
- Waveform, espectrograma y reproductor comparten una única posición temporal. Cambiar de pista conserva ese instante cuando sea posible.
- La sonoridad bajo demanda usa FFmpeg/EBU R128, es local/cancelable y respeta `OperationCoordinator`.
- Los offsets de audio son información técnica basada en timestamps; no autorizan diagnósticos automáticos de desincronización.
- Los informes técnicos TXT/Markdown/JSON se generan solo por solicitud explícita y deben excluir rutas completas, fingerprints e IDs internos.
- Las preferencias del Inspector se integran exclusivamente en Ajustes centralizados mediante `SettingsRepository`; no se permite una configuración paralela dentro del módulo.
- El reproductor universal de vídeo continúa fuera de alcance y requerirá una decisión específica posterior.

## Inspector multimedia — cambio de pista y seek — 0.15.1.0

- El preview de audio mantiene una única operación vigente. Start, stop y seek se serializan y cada petición posee una generación; resultados/snapshots de generaciones anteriores no pueden publicar estado sobre la actual.
- Pulsar **Escuchar** en una pista original sincroniza también la selección principal de audio del Inspector. El cambio conserva el instante actual cuando cabe en la nueva duración y FFmpeg usa el stream exacto seleccionado.
- La waveform aplica seek optimista: el playhead cambia de posición inmediatamente al clic/drag y solo acepta snapshots pertenecientes a la misma generación de seek, evitando rebotes visuales.
- Estas correcciones no cambian la política local/solo lectura, no crean historial y no añaden dependencias ni red.

## Inspector multimedia — sustitución atómica del preview — 0.15.2.0

- Cada sustitución desacopla primero del estado compartido los recursos de la sesión vigente. Su limpieza opera exclusivamente sobre esas referencias capturadas y debe terminar antes de crear AVAudioEngine/AVAudioPlayerNode para la fuente nueva.
- El servicio mantiene una generación propia, además de la generación de UI. Si llega A→B→C mientras B espera limpieza, B pierde autorización y solo C puede arrancar o publicar resultado.
- El tiempo se conserva en el ViewModel incluso durante el estado pendiente y se limita a la duración declarada por la fuente nueva. La misma ruta sirve para originales, externos y cambios desde pausa.
- La UI distingue fuente solicitada de fuente confirmada: solo la solicitada muestra **Cargando…** y la fuente anterior deja de presentarse como activa desde el clic.
- La corrección mantiene sin cambios dependencias, motores, DSP, formatos, privacidad, red, permisos, originales y alcance del módulo.

## Reproductor compartido del Inspector multimedia 0.15.3.0

- El Inspector mantiene una única sesión de previsualización para Pistas, Espectrograma, waveform y barra inferior; las vistas no pueden introducir reproductores o estados `isPlaying` independientes.
- Sustituir una pista conserva posición y estado Play/Pausa. En Pausa la nueva fuente se prepara sin iniciar decodificación ni salida de audio hasta que el usuario reanuda.
- Los seek de controles globales conservan Play/Pausa. Un gesto cuya semántica explícita sea «escuchar desde aquí», como el clic en el gráfico del espectrograma, puede iniciar reproducción.
- El layout del Espectrograma debe ceder altura del área gráfica antes que ocultar el reproductor inferior; no se usa scroll global como solución a falta de altura.
- Estas decisiones no alteran privacidad, red, archivos originales, dependencias, motores ni alcance de edición.

## Resolución central de controles del Inspector multimedia 0.15.4.0

- Los botones `Escuchar/Pausar` de Pistas y Espectrograma no deciden localmente si una fuente está activa: consultan la misma resolución de estado en `MultimediaInspectorViewModel`.
- Mientras existe una sustitución pendiente, `requestedPreviewSourceID` tiene prioridad sobre la fuente confirmada y sobre el contexto interno anterior. Esto evita que una vista trate como activa una fuente obsoleta durante la transición.
- La acción de cada botón delega en el ViewModel la decisión iniciar/cambiar/pausar/reanudar; las vistas se limitan a representar `Cargando…`, `Pausar` o `Escuchar`.
- La barra inferior continúa siendo un control global de la misma sesión y no introduce una identidad de pista alternativa.
- No se modifica `MultimediaAudioPreviewService`, `PreviewSourceReplacementGate`, la política de privacidad ni el comportamiento de archivos.


## Identidad estable de controles del Inspector multimedia 0.15.5.0

- `requestedPreviewSourceID` representa exclusivamente una sustitución en curso y solo gobierna la presentación durante `.loading`.
- En `.playing`, `.paused` y `.finished`, una fila o control de pista solo se considera dueño del transporte si coincide con `previewSourceID`, la fuente confirmada por el servicio.
- La etiqueta y la acción del botón deben obtenerse de `previewPlaybackState(for:)`; no se permite una segunda regla paralela para decidir si un clic pausa, reanuda o inicia.
- La barra inferior sigue actuando sobre la misma sesión global; no se cambia `MultimediaAudioPreviewService`, `PreviewSourceReplacementGate`, privacidad, archivos ni motores.


## Identidad estable de filas del Inspector multimedia 0.15.6.0

- Las colecciones de audio y subtítulos mostradas en modo de inspección deben conservar una identidad SwiftUI estable durante toda la sesión; no se permite regenerar `MediaEditableTrack` con UUID nuevos como efecto de recomposiciones de la vista.
- `MultimediaInspectorViewModel` materializa esas pistas una vez por inspección y las sustituye únicamente al abrir/publicar una inspección distinta o al cerrar/fallar la sesión.
- El draft de edición continúa siendo la fuente de verdad de sus propias pistas mientras el modo edición está activo.
- La identidad estable de filas es independiente de `previewSourceID`/`requestedPreviewSourceID`: no introduce otro reproductor ni altera el transporte, privacidad, motores o archivos.


## Inspector multimedia — análisis automático mono-pista 0.15.7.0

- La decisión de automatizar análisis complementarios se basa exclusivamente en `MediaInspectionResult.audioStreams.count`, nunca en la extensión del archivo.
- Con exactamente una pista de audio, la inspección técnica inicia automáticamente espectrograma y después sonoridad EBU R128. Con cero pistas no inicia análisis de audio y con dos o más ambos permanecen manuales para no seleccionar una pista silenciosamente.
- Espectrograma y sonoridad siguen siendo operaciones pesadas independientes con sus servicios existentes y se ejecutan secuencialmente. No se habilita paralelismo adicional ni se modifica `OperationCoordinator`.
- La cadena automática pertenece al estado efímero de la sesión del ViewModel y usa una identidad de sesión para impedir que una cancelación, cierre o sustitución inicie fases posteriores sobre un archivo antiguo.
- Los botones manuales permanecen disponibles para regenerar/reanalizar; no cambian ajustes, reproductor compartido, motores, privacidad, red ni protección del original.


## Inspector multimedia — viewport temporal compartido 0.15.8.0

- Waveform y espectrograma comparten un único `AudioTimelineViewport` propiedad de `MultimediaInspectorViewModel`; no pueden mantener ventanas temporales de zoom independientes.
- El zoom se centra preferentemente en el playhead cuando existe una posición válida y el pan se limita siempre a la duración disponible. **Vista completa** restaura el intervalo total.
- La waveform puede conservar una envolvente de hasta 65.536 intervalos, pero nunca PCM completo. La región visible se recorta y reduce en memoria; hacer zoom/pan no vuelve a ejecutar FFmpeg.
- Los capítulos confirmados por FFprobe pueden representarse como marcadores temporales de solo lectura sobre la waveform. Esta mejora no autoriza editar capítulos.
- `MultimediaAudioPreviewService` sigue siendo el único reproductor. La ventana temporal es presentación/navegación y no introduce un segundo estado de playhead, otro timer ni otra sesión de audio.
- Esta versión no incorpora todavía detección de silencios, clipping, mapa temporal de sonoridad ni comparación A/B; esos análisis requieren alcance y validación propios.
- No se añaden dependencias, red, APIs, persistencia multimedia ni escrituras sobre originales.

## Inspector multimedia — análisis de señal 0.15.9.0

- El análisis de silencios y posible clipping es local, efímero y trabaja con PCM completo por streaming; no reutiliza la waveform reducida como fuente de diagnóstico.
- Silencio predeterminado: todos los canales por debajo de -60 dBFS durante al menos 0,5 s.
- El clipping se presenta siempre como **Posible clipping**, con criterio conservador cercano a 0 dBFS y varias muestras consecutivas; no se afirma clipping absoluto a partir de una sola muestra.
- Con una sola pista, la cadena automática es espectrograma → señal → sonoridad. Con dos o más pistas, estos análisis dependientes de pista siguen siendo manuales.
- Los resultados se proyectan sobre el viewport temporal compartido y no cambian reproductor, edición/remux, red, motores ni protección del original.

## Inspector multimedia — cierre del análisis avanzado 0.16.0.0

- La evolución temporal de sonoridad reutiliza la **misma ejecución** FFmpeg/EBU R128 que calcula Integrated LUFS, LRA y True Peak; no se autoriza un cuarto recorrido pesado solo para dibujar el mapa.
- La curva principal es Short-term LUFS. Momentary e Integrated temporales se conservan para inspección puntual. La serie se mantiene acotada y puede compactarse preservando tendencia y extremos; nunca persiste PCM.
- Waveform, espectrograma y sonoridad temporal comparten `AudioTimelineViewport`, playhead y seek. La sonoridad se representa como una franja propia para no sobrecargar la waveform.
- La comparación A/B vive en Pistas, usa el **único reproductor existente** y conserva timestamp y estado Play/Pausa al sustituir la fuente. No se autorizan dos decodificadores/reproductores simultáneos para A/B.
- La pista de preview y la pista elegida para Espectrograma son responsabilidades distintas: alternar A/B no cambia `selectedAudioStreamIndex` ni invalida silenciosamente el espectrograma.
- Seleccionar A/B no dispara análisis pesados. **Completar análisis A/B** ejecuta únicamente señal/sonoridad ausentes y siempre en secuencia bajo las garantías existentes de `OperationCoordinator`.
- Los informes técnicos pasan a schema JSON 2, incorporando análisis de señal y timeline de sonoridad cuando ya existan. Exportar un informe no inicia análisis nuevos y no puede incluir rutas completas, fingerprints, `sourceID` ni PCM.
- Este bloque no añade dependencias, red, APIs, motores, persistencia multimedia ni cambios al original. Capítulos editables, attachments y edición de metadatos quedan para un bloque posterior.

## Inspector multimedia — edición estructural 0.17.0.0
- Los capítulos se editan como marcadores de inicio; el final de cada capítulo se deriva del siguiente inicio o de la duración del medio.
- Los attachments editables son streams reales `codec_type=attachment`; las `attached_pic` continúan protegidas y de solo lectura.
- Los metadatos editables se limitan a un conjunto multimedia seguro y conocido; tags desconocidos se muestran y pueden preservarse, pero no se editan arbitrariamente.
- `Preservar metadatos` controla tags y no capítulos. Los capítulos siempre siguen el `MediaEditDraft`.
- Capítulos, attachments y metadatos comparten el mismo `MediaEditDraft`/historial Undo-Redo, planner, ejecución FFmpeg, validación FFprobe y publicación segura que la edición de pistas.
- Añadir attachments puede proponer MKV únicamente cuando vídeo y audio siguen siendo stream copy; nunca se autoriza transcode implícito.


## Inspector multimedia — lotes, presets y personalización 0.18.0.0

- El lote del Inspector se limita a **inspección, análisis y exportación**. La edición estructural masiva no forma parte de 0.18.0.0.
- La entrada múltiple acepta varios archivos seleccionados o arrastrados. No se realiza búsqueda recursiva de carpetas en esta versión.
- Los elementos se procesan **estrictamente en secuencia**; no se ejecutan varios archivos ni varios análisis pesados simultáneamente. Los servicios existentes continúan coordinándose mediante `OperationCoordinator`.
- Si FFprobe detecta dos o más pistas de audio, el lote no elige ninguna silenciosamente. La inspección se conserva y los análisis dependientes de una pista se omiten con aviso.
- Los presets de lote se administran en Ajustes, se persisten mediante `SettingsRepository` con schema versionado y no pueden contener rutas, carpetas, archivos seleccionados ni otra identidad privada.
- El historial de lote es una única entrada agregada con contadores; no registra nombres ni listas de archivos.
- La filosofía de personalización del Inspector se consolida en Ajustes centralizados: automatización, preview, continuidad al cambiar de pista, zoom/pan, waveform/overlays, señal, espectrograma/exportación, informes, salida y preset predeterminado son preferencias del usuario cuando son razonablemente configurables.
- Las garantías de seguridad, privacidad, fingerprint, publicación segura, validación final, prohibición de sobrescritura silenciosa y regla de una operación pesada no son opciones desactivables.

## Inspector multimedia — ayuda contextual y accesibilidad 0.18.1.0

- Toda opción técnica, ambigua o con consecuencias del Inspector debe usar la infraestructura compartida `ContextualHelpButton`/`Help*` junto a su nombre; no se crean iconos `info.circle` o popovers paralelos dentro del módulo.
- Resumen, Pistas, Espectrograma, Metadatos y Lote mantienen una explicación general, y las métricas/indicadores no obvios incorporan ayuda específica.
- Abrir una ayuda es una acción puramente visual: no puede lanzar motores, recalcular señal/espectrograma/sonoridad, invalidar cachés ni persistir contenido multimedia.
- La ayuda debe seguir siendo accesible por teclado y VoiceOver mediante el componente común de ZEUVE.
- Los controles evidentes no reciben iconos innecesarios; la cobertura se centra en conceptos técnicos, opciones configurables y resultados que necesitan interpretación.
- Un verificador y pruebas de regresión protegen esta cobertura en futuras ampliaciones del Inspector.
