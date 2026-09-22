# Arquitectura de ZEUVE 0.20.0.0

## Navegación dinámica y Limpiador 0.20.0.0

`NavigationPreferences` vive en `ZEUVECore`; `BuiltInModuleCatalog` conserva IDs, metadata y defaults. `AppModel` normaliza la preferencia `navigation.preferences` y expone el mismo orden efectivo a Sidebar, Dashboard y commands. El recorder de teclado queda en ZEUVEApp porque depende de AppKit.

`CleanerModule` depende de `ZEUVECore`, `ZEUVEStorage` y `ZEUVEOperations`, nunca de `ZEUVEEngines`. Su lógica se separa en inventario/discovery/asociación/reglas/desarrollo/planificación/ejecución/storage; AppKit, Spotlight y Security.framework quedan detrás de providers o compilación específica de macOS. SQLite schema 3 conserva inventario resumido, raíces asociadas, decisiones, metadata y Undo.

## Inspector multimedia 0.7.0 — arquitectura actual

La sesión interactiva se organiza alrededor de un único transporte. `MultimediaInspectorViewModel` expone la posición temporal compartida y delega decodificación en servicios aislados: el audio mantiene el pipeline FFmpeg → PCM incremental → `AVAudioEngine`, mientras `MultimediaVideoPreviewService` ejecuta FFmpeg con argumentos separados, entrega frames BGRA acotados y descarta generaciones obsoletas. Ningún vídeo completo se materializa en memoria.

La edición usa `MediaEditDraft → MediaEditPlanner → MediaEditValidator → FFmpegMediaEditCommandBuilder → MultimediaEditService → FFprobe → MultimediaResultValidator → publicación segura`. El draft representa vídeo/audio/subtítulos y carátulas de forma diferenciada; fuentes externas se fingerprintan antes de ejecutar y todos los streams audiovisuales se conservan por copy.

El lote separa enumeración ligera de carpetas, inspección técnica, evaluación de reglas y ejecución. `MultimediaBatchFolderEnumerator` no sigue symlinks; el rule engine trabaja con propiedades semánticas; `MultimediaBatchPreflightService` genera un plan individual antes de confirmar; la ejecución reutiliza `MultimediaEditService` de forma secuencial.

Los análisis avanzados y OCR son servicios independientes y cancelables. FFT/energía/anomalías se calculan localmente sin persistir PCM. El OCR extrae eventos bitmap a workspace temporal y usa Vision en macOS; el texto permanece en el borrador/revisión y no entra en logs ni informes técnicos. Favoritos y rule sets se persisten mediante `SettingsRepository` y solo contienen configuración reutilizable.

## Principios

ZEUVE es una aplicación nativa para macOS Apple Silicon, con Swift 6 como base y una arquitectura modular. La interfaz no contiene lógica pesada y los módulos de negocio no dependen de SwiftUI.

```text
ZEUVEApp (SwiftUI/AppKit)
        ↓
ZEUVECore · ZEUVEStorage · ZEUVEOperations · ZEUVEEngines
        ↓
OrganizerModule · UniversalDownloaderModule · ChatAnalyzerModule · UniversalConverterModule · InstagramFollowersModule · MultimediaInspectorModule · CleanerModule
        ↓
Foundation · SQLite del sistema · motores externos aprobados
```

## Componentes compartidos

### `ZEUVECore`

Contiene contratos estables:

- `ModuleManifest`, permisos, capacidades y presentación;
- `ModuleManifestLoader`, que decodifica y valida el manifiesto común sin sustituir el error específico de recurso de cada módulo;
- `ModuleRegistry`;
- protocolo JSON para futuros procesos aislados;
- modelos de operaciones;
- historial presentable por módulo;
- rutas y registros locales.

### `ZEUVEStorage`

Utiliza SQLite del SDK/sistema mediante `CSQLite`, sin Homebrew ni `pkg-config` en tiempo de ejecución. Gestiona:

- ajustes;
- historial de operaciones;
- migraciones;
- historial global dirigido por `moduleID`.

La pantalla global obtiene nombre e icono desde los manifiestos registrados. Los presenters de los módulos built-in y sus aliases se aportan desde `BuiltInModuleCatalog`, mientras `GlobalHistoryService` continúa siendo dirigido por `moduleID`. Una nueva herramienta no exige añadir una sección fija a la vista ni un caso especial en `GlobalHistoryViewModel`.

### Integración de interfaz compartida

`ContextualHelp.swift` contiene únicamente los componentes reutilizables (`ContextualHelpTopic`, botones y filas). Los contenidos de ayuda se agrupan junto al dominio que los utiliza (`GeneralHelp`, `OrganizerHelp`, `UniversalDownloaderHelp`, `ChatAnalyzerHelp` y `UniversalConverterHelp`) mediante extensiones de `ZEUVEHelpTopics`. Esta separación no cambia textos ni comportamiento y evita que un único archivo común crezca con cada módulo.

Las claves persistentes propias del Organizador se declaran en `OrganizerStorageKeys`; las claves legacy siguen separadas explícitamente y conservan sus valores literales. Las claves globales de aplicación, como el tema, se centralizan en la capa `ZEUVEApp`.

### Catálogo de módulos built-in

`Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift` concentra la integración transversal de los módulos oficiales incorporados. Cada descriptor declara la identidad interna estable, el identificador principal, aliases históricos, el orden de navegación ya aprobado, si aporta Ajustes, su comando/atajo y los presenters de historial.

`AppModel` continúa creando ViewModels concretos y fuertemente tipados; el catálogo no convierte los módulos en plugins dinámicos ni usa reflexión/type erasure. `RootView`, `DashboardView`, `SettingsView` y `ZEUVEApp.Commands` consumen los módulos registrados a través de este catálogo. `BuiltInModuleViewRouter` concentra el único `switch` de vistas principales y `BuiltInModuleSettingsRouter` el de contenidos de Ajustes.

Solo un manifiesto registrado correctamente genera una herramienta navegable. Un fallo de carga, validación o registro se acumula en el aviso de arranque y ese módulo no aparece en Inicio, barra lateral, Ajustes ni comandos. Los ViewModels pueden seguir existiendo como dependencias internas de `AppModel`, pero no existe una ruta visible hacia una herramienta no registrada.

El Dashboard conserva el orden que ya proporcionaba `ModuleRegistry` mediante `manifest.presentation.order`; la barra lateral, Ajustes y los atajos mantienen sus órdenes aprobados anteriores mediante metadatos explícitos del catálogo. No existe todavía personalización de orden, visibilidad o atajos.

Los aliases legacy del catálogo también dirigen la presentación del historial. El Descargador universal asocia `com.zeuve.youtube-downloader` con su módulo actual, de modo que `GlobalHistoryViewModel` no contiene una rama especial de YouTube y puede combinar de forma genérica cualquier alias histórico futuro aprobado.

### Infraestructura común de carpetas

`ZEUVECore` expone `FolderBookmarkCodec`, `SystemFolderBookmarkCodec`, `FolderBookmarkResolution` y `SecurityScopedResourceAccess` para la mecánica de bookmarks y acceso `security-scoped` de macOS. Los módulos siguen siendo responsables de sus propias claves persistentes, validación de destino, migraciones y políticas de publicación. Compartir esta capa no autoriza a un módulo a leer carpetas de otro ni cambia los bookmarks ya guardados.

`ZEUVEHistoryPersistence` define que el historial es persistencia secundaria al resultado principal: captura el fallo de guardado y produce únicamente un aviso y metadatos de log saneados. Nunca almacena rutas, contenido, URLs o credenciales para diagnosticar ese fallo.

### `ZEUVEOperations`

`OperationCoordinator` permite una única operación pesada principal. Los módulos conservan su progreso detallado, pero deben reservar y liberar la operación global. Cada operación debe tener un único propietario de ese ciclo. Para módulos nuevos se prefiere que sea la capa de servicio que posee la ejecución pesada; cuando la aplicación orquesta explícitamente varias responsabilidades, la capa App puede mantener esa propiedad, como ocurre actualmente en Organizador y Descargador universal. En ambos casos `finish`/cancelación deben quedar garantizados aunque falle una tarea secundaria como historial o logging.

### Verificación y QA del proyecto

`Scripts/verify_project.sh` es el punto de entrada estable para la verificación integral, pero no contiene reglas de dominio embebidas. Actúa como orquestador de `Scripts/verify/*.py`, agrupados por integración de aplicación, estructura, motores, documentación, rendimiento y módulos. Esto permite añadir un módulo sin seguir ampliando un único script global.

Las garantías que pueden comprobarse ejecutando código permanecen en XCTest/Swift Testing o en `Tests/ScriptTests`; las búsquedas textuales se reservan para invariantes estructurales o contenido expresamente prohibido/aprobado. La reorganización de un archivo no debe obligar a debilitar una garantía: cuando la ubicación cambia, la comprobación se dirige a la responsabilidad nueva.

`Scripts/verify/xcode_integration.py` compara los productos de biblioteca de SwiftPM con los productos enlazados por el generador Xcode y con el `.pbxproj` regenerado. `Scripts/verify/app_sources.py` parsea automáticamente todos los Swift de `ZEUVEApp`. En macOS Apple Silicon, `Scripts/verify_app_macos.sh` completa la validación con motores y `xcodebuild` real; en otros entornos esa etapa se declara omitida y nunca se presenta como compilación final.

### `ZEUVEEngines`

Infraestructura reutilizable para motores incluidos:

- lectura y validación de `engines.json`;
- rutas seguras y rechazo de traversal o escapes por enlaces simbólicos;
- comprobación SHA-256, tamaño, arquitectura, versión, permisos y licencias;
- inspección de dependencias dinámicas;
- ejecución sin shell;
- lectura incremental de stdout y stderr;
- grupos de procesos independientes;
- cancelación y terminación de descendientes;
- diagnóstico común en español.

No contiene reglas de YouTube, selección de formatos ni argumentos de yt-dlp.

### Inspección multimedia compartida

`ZEUVEEngines/MediaInspection` concentra FFprobe para consumidores que necesitan un modelo técnico de audio/vídeo. `MediaInspectionService` ejecuta FFprobe sin shell, limita la salida acumulada, tolera campos opcionales mediante modelos `Codable` y mantiene una caché únicamente en memoria indexada por `FileFingerprint`. No conoce UI, presets ni decisiones de conversión.

Desde 0.13.0 el Conversor universal y el Inspector multimedia consumen esta misma capa. No debe reaparecer un segundo parser FFprobe específico de módulo salvo una necesidad aprobada incompatible con el contrato común.

### `CZEUVEProcess`

Capa C mínima para macOS/POSIX. Utiliza `posix_spawn` con `POSIX_SPAWN_SETPGROUP`, tuberías separadas y directorio de trabajo controlado. El grupo creado no incluye el proceso principal de ZEUVE.

## Módulos oficiales

### Organizador

Conserva su planificación, ejecución, historial y deshacer. En 0.2.0 solo se corrige su manifiesto para declarar `openExternalApplications`, porque abre Finder.

### Descargador universal

`UniversalDownloaderModule` registra `com.zeuve.universal-downloader` y separa el código por responsabilidad real:

- `Analysis`: coordinación universal y adaptadores de análisis de yt-dlp, gallery-dl e Instagram;
- `Download`: ciclo de operación, construcción del plan y validación de salida;
- `Models`: modelos universales separados de los modelos propios de yt-dlp;
- `Engines`: yt-dlp, gallery-dl, instaloader-zeuve y descarga HTTP directa;
- `Platforms`: únicamente lógica realmente específica de YouTube, Instagram y TikTok;
- `Publishing`, `Files`, `Storage`, `Validation` y `Discovery`: servicios compartidos independientes de una plataforma concreta.

Los nombres de YouTube se conservan solo donde la responsabilidad es realmente específica —por ejemplo la canonicalización de URLs y la política anónima de clientes de yt-dlp para YouTube— o donde un literal legacy debe mantenerse para compatibilidad. `gallery-dl`, instaloader y HTTP directo no se presentan como componentes de YouTube.

`UniversalDownloaderSettingsStore` mantiene la persistencia sobre `SettingsRepository` y reconoce claves históricas sin borrarlas. El historial continúa leyendo tanto `com.zeuve.universal-downloader` como `com.zeuve.youtube-downloader`. El directorio histórico `Temporary/YouTube` se conserva como dato legacy en esta fase para no introducir una migración funcional innecesaria.

La aplicación sitúa vistas y ViewModel en `ZEUVEApp/UniversalDownloader`. `UniversalDownloaderViewModel` sigue siendo el coordinador SwiftUI, mientras persistencia, construcción de planes y sesión de Instagram tienen responsabilidades separadas. La UI nunca construye comandos ni ejecuta motores directamente.

### Inspector multimedia

`MultimediaInspectorModule` implementa inspección, edición estructural de audio/subtítulos y espectrograma. La UI vive en `ZEUVEApp/MultimediaInspector`; la lógica pesada se mantiene fuera de SwiftUI.

La edición sigue `MediaEditDraft → MediaEditValidator → MediaEditPlanner → MediaEditPlan → FFmpegTrackEditCommandBuilder → MultimediaEditService → MultimediaResultValidator → MultimediaOutputPublisher`. El draft es reversible y el plan inmutable. Vídeo y audio nunca se recodifican automáticamente; las conversiones auxiliares se limitan a subtítulos expresamente autorizados.

El espectrograma usa FFmpeg para entregar PCM float32 incremental y Accelerate/vDSP en macOS para el análisis espectral. `SpectrogramAccumulator` mantiene memoria acotada compactando columnas y no materializa PCM ni bitmaps completos de archivos largos.

El descriptor built-in usa `settingsOrder: nil` en 0.13.0: existe `MultimediaInspectorPreferences` para inyección de defaults futuros, pero no una pantalla de ajustes independiente.

### Comparador de seguidores de Instagram

`InstagramFollowersModule` separa catálogo, lectura ZIP, parser JSON, normalización, comparación, exportación e historial. Las vistas y el ViewModel se encuentran en `ZEUVEApp/InstagramFollowers`; la interfaz no interpreta JSON ni accede directamente a `CLibArchive`.

El módulo reutiliza `CLibArchive` y `OperationCoordinator`, pero mantiene un lector propio para no alterar los contratos aprobados del Analizador de chats o del Conversor universal. No depende de motores externos ni de `ZEUVEEngines`.

## Recursos de motores

```text
Resources/Engines/
├── yt-dlp/yt-dlp_macos
├── deno/deno
├── ffmpeg/ffmpeg
├── ffmpeg/ffprobe
├── gallery-dl/                 # obligatorio, preparado en macOS ARM64
├── instaloader/                # obligatorio, preparado en macOS ARM64
├── playwright-browser/         # marcador opcional, no proporcionado ni enrutable en 0.12.4
├── licenses/
└── engines.json
```

FFmpeg y FFprobe se almacenan una sola vez y pueden ser reutilizados por futuros módulos como el Conversor universal.

## Ciclo de análisis universal

```text
URL elegida
        ↓
Validación HTTPS / excepción local explícita
        ↓
yt-dlp analiza la fuente original
        ↓
Si es una página: inspección HTML controlada
        ↓
Análisis secuencial de candidatos
        ↓
Deduplicación segura + posibles duplicados visibles
        ↓
Selección del usuario
```

La inspección no sigue enlaces internos ni ejecuta un navegador automatizado. Las miniaturas no se solicitan directamente desde la vista.

## Ciclo de una descarga

```text
Entrada y validación
        ↓
OperationCoordinator.begin
        ↓
Diagnóstico y resolución de motores
        ↓
Motor elegido en grupo POSIX propio
        ↓ salida incremental
Parser de progreso y JSON
        ↓
Temporal exclusivo de la operación
        ↓
Comprobación de archivo candidato y respaldo aprobado
        ↓
FFprobe valida los resultados
        ↓
Publicación segura y resolución de conflictos
        ↓
Historial local + resumen
        ↓
OperationCoordinator.finish
```

## Cancelación

1. Se marca la operación como cancelada.
2. Se envía SIGTERM al grupo del motor.
3. Se espera un periodo limitado.
4. Si el grupo continúa, se envía SIGKILL.
5. Se espera realmente al proceso padre y se verifica la desaparición del grupo.
6. Se eliminan únicamente temporales propios.
7. Se conservan resultados ya publicados y válidos.

El registro compartido de procesos se utiliza también al cerrar la aplicación.

## Arquitectura de ajustes

`SettingsView` es el único punto de configuración persistente de la aplicación. Su navegación secundaria se genera desde los módulos registrados cuyo descriptor de `BuiltInModuleCatalog` declara contenido de Ajustes. En 0.12.4 el resultado visible permanece:

- General;
- Organizador de archivos;
- Descargador universal;
- Analizador de chats;
- Conversor universal.

El Comparador de seguidores de Instagram no aparece porque su descriptor no declara ajustes persistentes en 0.8.0.

Cada ViewModel mantiene dos estados distintos cuando corresponde:

- valores predeterminados persistentes, almacenados mediante `SettingsRepository` con claves del espacio del módulo;
- opciones de la operación actual, que se modifican dentro de la herramienta sin sobrescribir los predeterminados.

El Descargador conserva únicamente un selector rápido para aplicar presets. Su creación, edición, eliminación y restauración, junto con el diagnóstico de motores, se realiza desde Ajustes. Los módulos futuros deben integrarse en este mismo sistema y no crear ruedas o ventanas de configuración independientes.

General ofrece además un restablecimiento global coordinado por `AppModel`. No vacía la tabla `settings`: invoca las rutas de restauración de cada módulo para mantener sincronizados el estado en memoria y la persistencia. Conserva contenido creado por el usuario —historial, presets, favoritas, perfiles personalizados y carpetas recientes— y solo elimina estado recordado que forma parte de los valores de configuración restaurados, como la sesión de Instagram del Llavero y los bookmarks de carpetas de salida. La acción no se habilita mientras existe una operación activa.

## Persistencia y privacidad

- Ajustes con prefijos estables por módulo.
- Presets con versión de esquema.
- Bookmarks de seguridad para carpetas autorizadas.
- Historial con IDs canónicos, no con URLs completas.
- Cookies, credenciales, cabeceras y URLs firmadas no se almacenan.
- Los JSON informativos son generados por ZEUVE con un esquema sanitario.

## Módulos importables futuros

La versión 0.7.0 solo ejecuta módulos oficiales `builtIn`. El contrato mantiene `isolatedProcess` para una futura importación de paquetes firmados. La instalación dinámica, confianza, permisos y desinstalación todavía no están implementadas.


## Analizador de chats

```text
ZIP/TXT/HTML/carpeta seleccionada
        ↓
validación y catálogo seguro con CLibArchive
        ↓
WhatsApp por lotes / Instagram página a página
        ↓
SQLite temporal: deduplicación + cronología estable
        ↓
resultado inmutable compacto + store de sesión
        ↓
analíticas diferidas por lotes + búsqueda paginada
        ↓
publicación atómica en SwiftUI, historial agregado y limpieza de temporales
```

`ChatAnalyzerModule` contiene modelos, lectura de archivos, importadores, normalización, estadísticas, almacenamiento temporal e historial. `ZEUVEApp/ChatAnalyzer` contiene exclusivamente ViewModel y vistas. El módulo no depende de `ZEUVEEngines` ni ejecuta procesos externos.

La vista raíz del Analizador encapsula el ViewModel en una vista observada. El cambio de `session` actualiza directamente la transición entre importación y resultados, sin depender de que `AppModel` publique otro cambio. Los componentes de resultados reutilizan `ContextualHelpButton` mediante títulos, tarjetas, gráficos, grupos, filas y cabeceras comunes.

`ChatAnalyzerViewModel` mantiene instantáneas compactas e inmutables para el núcleo y las secciones analíticas. Los cambios de filtros o fusiones recalculan fuera del actor principal mediante `ChatStoreAnalytics`, que recorre `TemporaryChatStore` por lotes y publica únicamente agregados o páginas necesarias. Las pestañas de actividad, participantes, palabras, conversaciones, respuestas y comparación siguen siendo diferidas. Cada tarea captura una revisión del estado, propaga la cancelación a su trabajador y solo publica si la revisión sigue vigente. El último resultado completo se conserva durante la actualización.

La búsqueda espera 200 ms, recorre el store por bloques y conserva únicamente la página de coincidencias y su contexto. Cambiar de página puede volver a recorrer SQLite sin construir una copia completa de la conversación. Los ajustes de operación invalidan únicamente las analíticas que dependen de ellos. Las vistas no invocan análisis pesados desde propiedades calculadas.

`InteractiveChartSupport.swift` constituye una capa visual separada. Recibe las fechas o categorías ya representadas, convierte la posición local del puntero mediante `ChartProxy`, selecciona el elemento más cercano y publica únicamente un estado efímero de hover. También conserva la coordenada local del cursor y dibuja `ChartTooltipCard` en una superposición común que mide su tamaño, cambia de lado cerca de los bordes y limita su centro al área visible. El mapa de calor transforma la posición de cada celda al mismo espacio de coordenadas. Esta capa no conoce la base temporal ni llama a `ChatAnalytics`, por lo que no invalida las instantáneas ni bloquea el hilo principal con recorridos del chat.

`CLibArchive` enlaza `libarchive` del SDK/sistema mediante `module.modulemap`. La lectura es progresiva y selectiva: las muestras de detección leen únicamente un prefijo, el TXT de WhatsApp se transmite por bloques y el ZIP completo y sus adjuntos no se cargan en memoria ni se extraen junto al original.

Cada sesión crea una carpeta temporal marcada como propiedad de ZEUVE. La base SQLite es la fuente principal de los mensajes, se indexa por fecha, autor, plataforma y tipo, deduplica durante la importación y materializa una cronología estable. El cierre de sesión elimina primero la base y después la carpeta, únicamente si conserva el marcador de propiedad.

## Conversor universal

`UniversalConverterModule` separa modelos, detección, catálogo ZIP, matriz de compatibilidad, planificación definitiva, ejecución, validación y publicación. ImageIO y PDFKit cubren formatos nativos; `ZEUVEEngines` resuelve FFmpeg/FFprobe y Pandoc únicamente cuando están realmente disponibles. Los ebooks y EPS conservan detección explícita, pero no generan planes de conversión. La interfaz observa un ViewModel propio, las tareas pesadas se ejecutan fuera del hilo principal y los planes llevan revisión para impedir que un resultado obsoleto sustituya al actual. La publicación recibe el conjunto completo de originales, valida el temporal con el motor adecuado y solo después realiza el movimiento o reemplazo atómico.

## Optimización transversal 0.7.4

`AppModel` crea un único `EngineRegistry` y un único `EngineDiagnosticService` para el Descargador y el Conversor. `LatestValueCoalescer` limita publicaciones visuales demasiado frecuentes sin modificar el progreso real. Las caches temporales siguen asociadas a la sesión u operación que las creó.


## Flujo multimedia 0.7.5

La planificación de vídeo distingue entre recodificación y remux. En modo simple, una conversión de vídeo siempre construye una orden con codificador de vídeo; `-c:v copy` solo puede aparecer cuando el modo avanzado y la opción explícita de copia rápida están activos. Tras una recodificación, FFprobe confirma el códec producido.

Vídeo → fotogramas utiliza `VisibleFrameOutputCoordinator`. La carpeta de trabajo se crea en el mismo volumen y directorio de salida con sufijo `Procesando`, queda asociada a un registro privado de operación y se renombra al destino final al completar. La cancelación, el error o la recuperación posterior conservan el prefijo válido como `Incompleto`. Esta ruta evita la antigua copia completa entre el temporal interno y el destino.

`FrameTimingCSVCollector` consume incrementalmente las líneas `showinfo` emitidas por la misma ejecución de FFmpeg. El validador recorre progresivamente la carpeta, conserva una muestra acotada y solo puede retirar el último fotograma cuando está vacío, dañado o no coincide con el formato esperado.

## Flujo del Comparador de seguidores 0.8.0

```text
ZIP completo o JSON elegidos
        ↓
catálogo y validación segura
        ↓
confirmación manual «Analizar exportación»
        ↓
lectura selectiva + parser flexible
        ↓
normalización y deduplicación
        ↓
comparación inmutable en tres categorías
        ↓
búsqueda/orden en memoria + exportación opcional
        ↓
historial exclusivamente agregado
```

La inspección y el análisis capturan una revisión para descartar resultados obsoletos. La búsqueda aplica una espera de 180 ms y filtra las colecciones ya calculadas. Los nombres de usuario solo viven en el resultado de la sesión y no se guardan en SQLite.

## Organización interna por responsabilidad — Fase 4

Los archivos fuente se dividen cuando existe una frontera funcional real y puede conservarse la API y el comportamiento. No existe un límite numérico de líneas que obligue a fragmentar un coordinador: si separar un ViewModel exige ampliar estado privado, repartir tareas/cancelación entre extensiones o crear capas sin responsabilidad propia, el coordinador se mantiene unido.

En el Analizador, `ZEUVEApp/ChatAnalyzer/Results` contiene las secciones visuales de resultados y `ChatAnalyzerResultsView` actúa únicamente como coordinador de la selección. En `ChatAnalyzerModule/Analysis`, `ChatAnalytics` conserva el namespace y la API pública mientras modelos, actividad, participantes, palabras, conversaciones, búsqueda, snapshots, soporte y tokenización viven en fuentes separadas. La división no modifica algoritmos, caches ni reglas de invalidación.

En el Conversor, `Models` se organiza por formatos, operaciones, ajustes, opciones, presets, entradas, planificación, resultados y progreso manteniendo los mismos tipos y claves `Codable`. `FFmpegProgressSupport.swift` aloja únicamente la recolección de diagnóstico y progreso anteriormente privada del coordinador de ejecución; `UniversalConverterExecutionService` conserva la propiedad del ciclo de conversión, temporales, publicación y cancelación.

En la capa de aplicación del Descargador, `UniversalDownloaderView` conserva la composición principal y `Views/UniversalDownloaderSettingsCard.swift` encapsula su tarjeta de ajustes sin introducir una nueva superficie de configuración. El ViewModel permanece cohesionado porque mantiene el estado de UI, tareas y cancelación asociados al ciclo del módulo.


## Espectrograma — saneamiento 0.13.1.0

El pipeline conserva PCM incremental, pero `SpectrogramAccumulator` ya no desplaza arrays en cada hop. Mantiene buffers de canal con índice de lectura y compactación amortizada. Para mezcla de visualización procesa los canales individualmente y promedia potencia espectral, evitando cancelaciones artificiales por suma de PCM. La ventana y el setup FFT viven durante toda la petición.

`SpectrogramRenderMapping` es la única definición del eje de frecuencia para UI y exportación. `SpectrogramRasterizer` genera RGBA acotado para PNG; la UI precalcula los bins por fila y utiliza el mismo mapeo.

## Espectrograma — planificación adaptativa 0.13.2.0

`SpectrogramAnalysisPlanner` transforma duración, sample rate, FFT y máximo de columnas en una secuencia ordenada de ventanas. Conserva el hop del 50 % mientras el análisis completo cabe en el presupuesto. Para contenido largo asigna hasta ocho estratos por columna, de forma que transitorios y cambios breves tengan varias oportunidades de quedar representados sin ejecutar todas las FFT intermedias.

El acumulador descarta PCM que no pertenece a una ventana planificada, rellena buffers reutilizables solo cuando corresponde y agrega potencia antes de convertir a dB. En mezcla ejecuta una FFT por canal y ventana; en canal individual procesa una sola señal. Para pistas de más de dos canales el decoder solicita únicamente el canal elegido mediante `pan`.

El resultado conserva valores espectrales sin recortar al rango visible. Rango dinámico, escala y zoom producen interpretaciones del mismo modelo. `SpectrogramAnalysisService` mantiene una caché LRU exclusivamente en memoria, acotada a cuatro modelos y 64 MiB, cuya clave incluye fingerprint, stream, canal, FFT y ventana.

SwiftUI solicita un raster a una tarea separada y Canvas compone una imagen, evitando crear un `Path` por píxel en el actor principal. El proceso externo recibe una máscara de señales limpia, de modo que cancelar detiene el grupo FFmpeg aunque la tarea Swift de origen bloquee `SIGTERM` o `SIGINT`.


## Inspector multimedia — previsualización de audio 0.14.0.0

La reproducción se mantiene fuera de SwiftUI:

`UI/ViewModel → MultimediaAudioPreviewService → ExternalProcessRunner/FFmpeg → PCM f32le acotado → AVAudioEngine/AVAudioPlayerNode`.

El servicio es actor, la cola aplica back-pressure y no comparte buffers mutables con la UI. SwiftUI consume snapshots inmutables de estado/posición. La reproducción no publica archivos ni reserva `OperationCoordinator`; espectrograma y reproductor pueden coexistir. La selección de canal y los formatters técnicos viven en `MultimediaInspectorModule`, no en vistas.

## Inspector multimedia — análisis y navegación de audio 0.15.0.0

El estado de archivo se gestiona como una sesión explícita. `MultimediaInspectorViewModel` centraliza abrir/cerrar/resetear la sesión y conserva únicamente preferencias persistentes al sustituir el origen.

La waveform se mantiene fuera de SwiftUI: `MultimediaWaveformAnalysisService` solicita PCM incremental a FFmpeg, `MultimediaWaveformAccumulator` resume cada intervalo en mínimo, máximo y RMS, y la UI reduce esa envolvente al ancho visible sin volver a decodificar. No se conserva PCM completo ni se persiste la forma de onda.

La reproducción sigue usando `MultimediaAudioPreviewService` y AVAudioEngine. La posición publicada por ese servicio es la única referencia temporal para waveform y playhead del espectrograma.

`AudioLoudnessAnalysisService` usa FFmpeg EBU R128 y `OperationCoordinator`; `AudioTimingAnalyzer` deriva únicamente offsets/timing confirmables desde FFprobe; `MultimediaTechnicalReportExporter` serializa un modelo saneado y publica mediante `MultimediaOutputPublisher`.

Las preferencias se almacenan con `MultimediaInspectorSettingsStore` sobre `SettingsRepository` y se exponen exclusivamente desde la superficie central de Ajustes.

## Inspector multimedia — arbitraje de preview 0.15.1.0

`MultimediaInspectorViewModel` asigna una generación a cada operación de preview y serializa la sustitución de fuente/seek respecto a la tarea anterior. El actor `MultimediaAudioPreviewService` continúa siendo el único propietario de AVAudioEngine y FFmpeg; la UI no crea un segundo reproductor. Los monitores solo publican snapshots si pertenecen a la generación vigente.

En 0.15.2.0, `PreviewSourceReplacementGate` añade arbitraje dentro del propio servicio. Cada reemplazo retira del estado compartido un `DetachedPreviewPlaybackResources`, cancela inmediatamente scheduler/tarea y espera el cierre acotado del grupo FFmpeg y AVAudioEngine antes del siguiente arranque. El ticket generacional evita que una llamada reentrante antigua recupere el control tras un `await`.

## Continuidad del reproductor del Inspector 0.15.3.0

`MultimediaAudioPreviewService` sigue siendo el único propietario de `AVAudioEngine` y `AVAudioPlayerNode`. `MultimediaInspectorViewModel` expone una única fuente, posición, duración y estado a Pistas, Espectrograma, waveform y barra inferior.

`replaceSource(... preservePlaybackState:)` decide la continuidad a partir del estado real del servicio antes de entrar en la sustitución generacional. En Pausa prepara únicamente el contexto de la nueva fuente y no crea engine/player ni lanza FFmpeg; en reproducción conserva el ciclo atómico existente. `seek(... preservePlaybackState:)` permite que la UI mueva el playhead sin convertir Pausa en reproducción.

La UI no mantiene copias de `isPlaying`. `requestedPreviewSourceID` continúa siendo únicamente identidad transitoria de la sustitución y `PreviewSourceReplacementGate` conserva la autoridad sobre qué generación puede publicar la sesión definitiva.

## Resolución de controles del Inspector 0.15.4.0

`MultimediaInspectorViewModel` es también la única autoridad para asociar un botón de Pistas o Espectrograma con la sesión de preview. La resolución usa, en este orden, fuente solicitada, fuente confirmada y fuente activa interna de respaldo. Las vistas consumen `previewPlaybackState(for:)` y no duplican reglas para determinar si un clic significa iniciar, pausar o reanudar.

Esta capa no crea otro estado de reproducción: solo proyecta el estado global existente sobre una identidad de fuente concreta. `MultimediaAudioPreviewService` y su arbitraje generacional permanecen sin cambios.


## Resolución estable de controles del Inspector 0.15.5.0

`MultimediaInspectorViewModel` distingue ahora de forma explícita la identidad de transición de la identidad estable. Durante `.loading`, `requestedPreviewSourceID` identifica únicamente la fuente que se está preparando. Cuando el estado es `.playing`, `.paused` o `.finished`, `previewPlaybackState(for:)` solo reconoce `previewSourceID`, es decir, la fuente que `MultimediaAudioPreviewService.snapshot()` ha confirmado.

`previewTrack(...)` y `previewSelectedSpectrogram(...)` consumen esa misma proyección para decidir pausar/reanudar o iniciar/cambiar. Ya no existe una segunda función que pueda interpretar de forma distinta el mismo clic. El servicio de audio, `PreviewSourceReplacementGate`, la posición y el motor permanecen sin cambios.


## Identidad estable de filas del Inspector 0.15.6.0

En modo de inspección, `MultimediaInspectorViewModel` conserva snapshots de `MediaEditableTrack` para audio y subtítulos. Esas colecciones se construyen una sola vez cuando FFprobe publica una inspección válida y se reutilizan mientras la sesión permanezca abierta. La UI deja así de crear UUID nuevos en cada recomposición de SwiftUI provocada por el playhead.

El draft de edición conserva su propia colección mutable como hasta ahora. Al cerrar/fallar una inspección se limpian los snapshots; al abrir otro archivo o publicar un resultado editado se reconstruyen desde la nueva inspección. Esta corrección no introduce otra fuente de verdad de reproducción ni modifica `MultimediaAudioPreviewService`.


## Orquestación automática de análisis de audio 0.15.7.0

`MediaInspectionService` sigue siendo la primera fase y FFprobe continúa siendo ligero, sin reservar `OperationCoordinator`. Cuando publica una inspección válida, `MultimediaInspectorViewModel` consulta `MultimediaAutomaticAudioAnalysisPolicy` con el número real de streams de audio.

Solo el caso de exactamente un stream crea una cadena automática. El ViewModel reutiliza `SpectrogramAnalysisService` y espera a que su tarea termine y libere su operación antes de iniciar `AudioLoudnessAnalysisService`. No se ejecutan dos FFmpeg pesados en paralelo ni se duplica `begin/finish`; cada servicio conserva la propiedad de su propio ciclo en `OperationCoordinator`.

La cadena mantiene una identidad efímera por sesión y se cancela junto con espectrograma/sonoridad al cerrar, sustituir o cancelar el análisis. Pistas, Espectrograma, waveform y `MultimediaAudioPreviewService` no cambian.


## Inspector multimedia — timeline compartido 0.15.8.0

`AudioTimelineViewport` es un modelo puro del target `MultimediaInspectorModule`. Expresa una ventana normalizada y calcula intervalos visibles, zoom y pan sin depender de SwiftUI ni del reproductor. `MultimediaInspectorViewModel` posee una única instancia observable y la usa para reinterpretar tanto waveform como espectrograma.

La waveform conserva el pipeline `FFmpeg → PCM incremental → MultimediaWaveformAccumulator`, pero el presupuesto sube de forma acotada hasta 65.536 buckets. `MultimediaWaveformRenderSampler` recibe el intervalo visible, selecciona solo ese tramo y lo reduce al número de muestras que necesita la vista. Por tanto, cambiar la ventana temporal no crea procesos FFmpeg ni duplica análisis.

El espectrograma conserva su modelo espectral completo ya calculado y aplica el mismo intervalo al recorte visual. Los controles de ambas superficies llaman al ViewModel; no hay estado de zoom local por pestaña. El playhead sigue perteneciendo a `MultimediaAudioPreviewService` y únicamente se proyecta sobre el intervalo visible.

Los capítulos se adaptan a marcadores temporales de lectura desde los datos FFprobe ya inspeccionados. No se crea almacenamiento, motor ni capa de edición nueva.

## Análisis de señal del Inspector 0.15.9.0

`AudioSignalAnalysisService` reutiliza el ejecutor seguro de procesos y el decoder incremental `Float32LEStreamDecoder`. FFmpeg entrega PCM `f32le` del stream seleccionado sin forzar sample rate ni número de canales. `AudioSignalAnalysisAccumulator` calcula ventanas RMS por canal y localiza agrupaciones conservadoras de muestras cercanas al límite digital sin conservar el PCM completo. El servicio reserva `OperationCoordinator`, comprueba fingerprints antes y después y publica únicamente modelos compactos de silencios/clipping. La UI proyecta esos modelos sobre el `AudioTimelineViewport` ya compartido.

## Inspector multimedia — sonoridad temporal y comparación A/B 0.16.0.0

La sonoridad temporal extiende la ruta existente sin crear otro motor:

`AudioLoudnessAnalysisService → FFmpeg ebur128/astats → LoudnessLineCollector → AudioLoudnessTimelineAccumulator → AudioLoudnessResult.timeline`.

`AudioLoudnessTimelineAccumulator` limita la serie residente en memoria y fusiona puntos adyacentes cuando alcanza el tope. Las medias conservan la tendencia y cada agregado retiene mínimos/máximos del intervalo. El render vive en `MultimediaLoudnessTimelineView` y consume el mismo intervalo temporal ya recortado por `AudioTimelineViewport`; no ejecuta FFmpeg.

La comparación A/B se coordina desde `MultimediaInspectorViewModel`. A y B son referencias a `MediaEditableTrack`, mientras `MultimediaAudioPreviewService` continúa siendo el único transporte. La sustitución usa la continuidad ya aprobada (`PreviewSourceReplacementGate`) y se invoca con `synchronizeSpectrogramSelection: false`; de este modo preview y Espectrograma pueden referirse a pistas distintas de forma explícita. `selectedSpectrogramSignalAnalysis` y `currentWaveformSignalAnalysis` separan asimismo el origen de los overlays.

`AudioTrackComparisonMetrics` combina datos técnicos del stream, sonoridad y análisis de señal sin volver a analizar. La acción explícita de completar A/B resuelve la fuente y ejecuta solamente signal/loudness ausentes, una pista tras otra. `MultimediaTechnicalReportExporter` usa schema 2 para serializar los resultados disponibles y mantiene fuera del payload la identidad privada de las fuentes.

## Edición estructural del Inspector en 0.17.0.0

`MediaEditDraft` incorpora capítulos, attachments y metadatos además de audio/subtítulos. `MediaEditPlanner` transforma ese borrador en un `MediaEditPlan` inmutable y valida compatibilidad antes de ejecutar. Los capítulos se materializan únicamente dentro del workspace mediante FFmetadata temporal; los attachments externos se fingerprintan igual que el resto de entradas externas.

`FFmpegMediaEditCommandBuilder` coordina streams, capítulos, attachments y metadata con argumentos separados y `-c copy` para vídeo/audio. `MultimediaResultValidator` vuelve a inspeccionar la salida mediante FFprobe y compara capítulos, attachments, metadata y streams antes de autorizar la publicación. La extracción de attachments usa un servicio independiente coordinado, temporal y publicador seguro.


## Inspector multimedia — lotes y presets 0.18.0.0

El lote se separa del estado interactivo individual. `MultimediaBatchViewModel` mantiene cola, configuración efímera y resumen visual, mientras `MultimediaBatchProcessor` orquesta los servicios existentes del módulo sin crear un segundo motor de inspección ni un coordinador paralelo.

La secuencia por elemento es `MediaInspectionService → señal → sonoridad → espectrograma/exportación → informe`, ejecutando solo las fases elegidas. Cada servicio pesado mantiene la propiedad de su reserva de `OperationCoordinator`; el procesador espera y continúa de forma secuencial. La cola retiene únicamente `MultimediaBatchInspectionSummary`, estado, avisos y referencias a salidas publicadas; los modelos pesados de inspección, señal, LUFS o espectrograma se liberan al terminar cada elemento.

`MultimediaInspectorBatchPresetStore` persiste configuraciones versionadas en `multimediaInspector.batchPresets.v1`. Los presets no conocen archivos ni carpetas. `MultimediaInspectorPreferences` conserva las preferencias generales del Inspector y expone valores predeterminados reutilizables para nuevos lotes. La UI de gestión reside en `SettingsView` a través de `MultimediaInspectorSettingsView`, no en una superficie de ajustes independiente del módulo.

## Inspector multimedia — capa de ayuda contextual 0.18.1.0

La ayuda del Inspector permanece en `ZEUVEApp`: `MultimediaInspectorHelp.swift` declara `ContextualHelpTopic` y las vistas reutilizan `ContextualHelpButton` y las filas `Help*` compartidas. El target `MultimediaInspectorModule` no conoce popovers ni estado de ayuda. Esta frontera garantiza que consultar una explicación no ejecute motores, no modifique modelos de análisis ni invalide cachés.
