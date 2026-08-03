# Arquitectura de ZEUVE 0.7.5

## Principios

ZEUVE es una aplicación nativa para macOS Apple Silicon, con Swift 6 como base y una arquitectura modular. La interfaz no contiene lógica pesada y los módulos de negocio no dependen de SwiftUI.

```text
ZEUVEApp (SwiftUI/AppKit)
        ↓
ZEUVECore · ZEUVEStorage · ZEUVEOperations · ZEUVEEngines
        ↓
OrganizerModule · YouTubeDownloaderModule · ChatAnalyzerModule · UniversalConverterModule
        ↓
Foundation · SQLite del sistema · motores externos aprobados
```

## Componentes compartidos

### `ZEUVECore`

Contiene contratos estables:

- `ModuleManifest`, permisos, capacidades y presentación;
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

La pantalla global obtiene nombre e icono desde `ModuleRegistry`. Cada módulo puede registrar un `ModuleHistoryPresenter` para interpretar su carga útil. Una nueva herramienta no exige añadir una sección fija a la vista.

### `ZEUVEOperations`

`OperationCoordinator` permite una única operación pesada principal. Los módulos conservan su progreso detallado, pero deben reservar y liberar la operación global.

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

### `CZEUVEProcess`

Capa C mínima para macOS/POSIX. Utiliza `posix_spawn` con `POSIX_SPAWN_SETPGROUP`, tuberías separadas y directorio de trabajo controlado. El grupo creado no incluye el proceso principal de ZEUVE.

## Módulos oficiales

### Organizador

Conserva su planificación, ejecución, historial y deshacer. En 0.2.0 solo se corrige su manifiesto para declarar `openExternalApplications`, porque abre Finder.

### Descargador de YouTube

`YouTubeDownloaderModule` separa:

- modelos;
- validación de URLs y rutas;
- construcción de argumentos;
- selección de formatos;
- análisis JSON;
- playlists y subtítulos;
- progreso;
- temporales y publicación;
- historial, presets y bookmarks;
- políticas de privacidad.

Las vistas y el ViewModel se encuentran en `ZEUVEApp/YouTubeDownloader`. La UI nunca construye comandos ni ejecuta motores directamente.

## Recursos de motores

```text
Resources/Engines/
├── yt-dlp/yt-dlp_macos
├── deno/deno
├── ffmpeg/ffmpeg
├── ffmpeg/ffprobe
├── licenses/
└── engines.json
```

FFmpeg y FFprobe se almacenan una sola vez y pueden ser reutilizados por futuros módulos como el Conversor universal.

## Ciclo de una descarga

```text
Entrada y validación
        ↓
OperationCoordinator.begin
        ↓
Diagnóstico y resolución de motores
        ↓
yt-dlp en grupo POSIX propio
        ↓ salida incremental
Parser de progreso y JSON
        ↓
Temporal exclusivo de la operación
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

`SettingsView` es el único punto de configuración persistente de la aplicación. Presenta una navegación secundaria dirigida por módulo:

- General;
- Organizador de archivos;
- Descargador de YouTube.
- Analizador de chats.

Cada ViewModel mantiene dos estados distintos cuando corresponde:

- valores predeterminados persistentes, almacenados mediante `SettingsRepository` con claves del espacio del módulo;
- opciones de la operación actual, que se modifican dentro de la herramienta sin sobrescribir los predeterminados.

El Descargador conserva únicamente un selector rápido para aplicar presets. Su creación, edición, eliminación y restauración, junto con el diagnóstico de motores, se realiza desde Ajustes. Los módulos futuros deben integrarse en este mismo sistema y no crear ruedas o ventanas de configuración independientes.

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
WhatsAppImporter / InstagramImporter
        ↓
NormalizedMessage + deduplicación conservadora
        ↓
SQLite temporal indexado + resultado inmutable de sesión
        ↓
instantánea central filtrada y versionada
        ↓
tareas analíticas diferidas por pestaña + caché de búsqueda
        ↓
publicación atómica en SwiftUI, historial agregado y limpieza de temporales
```

`ChatAnalyzerModule` contiene modelos, lectura de archivos, importadores, normalización, estadísticas, almacenamiento temporal e historial. `ZEUVEApp/ChatAnalyzer` contiene exclusivamente ViewModel y vistas. El módulo no depende de `ZEUVEEngines` ni ejecuta procesos externos.

La vista raíz del Analizador encapsula el ViewModel en una vista observada. El cambio de `session` actualiza directamente la transición entre importación y resultados, sin depender de que `AppModel` publique otro cambio. Los componentes de resultados reutilizan `ContextualHelpButton` mediante títulos, tarjetas, gráficos, grupos, filas y cabeceras comunes.

`ChatAnalyzerViewModel` mantiene instantáneas inmutables para el núcleo y las secciones analíticas. Los cambios de filtros o fusiones reconstruyen el núcleo fuera del actor principal; las pestañas de actividad, participantes, palabras, conversaciones, respuestas y comparación se calculan de forma diferida. Cada tarea captura una revisión del estado, propaga la cancelación a su trabajador y solo publica si la revisión sigue vigente. El último resultado completo se conserva durante la actualización.

La búsqueda usa una instantánea independiente: espera 200 ms, recorre la cronología una sola vez para crear `ChatSearchIndex` y reutiliza sus índices al paginar o cambiar el contexto. Los ajustes de operación invalidan únicamente las cachés que dependen de ellos. Las vistas no invocan análisis pesados desde propiedades calculadas.

`InteractiveChartSupport.swift` constituye una capa visual separada. Recibe las fechas o categorías ya representadas, convierte la posición local del puntero mediante `ChartProxy`, selecciona el elemento más cercano y publica únicamente un estado efímero de hover. También conserva la coordenada local del cursor y dibuja `ChartTooltipCard` en una superposición común que mide su tamaño, cambia de lado cerca de los bordes y limita su centro al área visible. El mapa de calor transforma la posición de cada celda al mismo espacio de coordenadas. Esta capa no conoce la base temporal ni llama a `ChatAnalytics`, por lo que no invalida las instantáneas ni bloquea el hilo principal con recorridos del chat.

`CLibArchive` enlaza `libarchive` del SDK/sistema mediante `module.modulemap`. La lectura es progresiva y selectiva: las muestras de detección leen únicamente un prefijo, el TXT de WhatsApp se transmite por bloques y el ZIP completo y sus adjuntos no se cargan en memoria ni se extraen junto al original.

Cada sesión crea una carpeta temporal marcada como propiedad de ZEUVE. La base SQLite se indexa por fecha, autor, plataforma y tipo. El cierre de sesión elimina primero la base y después la carpeta, únicamente si conserva el marcador de propiedad.

## Conversor universal

`UniversalConverterModule` separa modelos, detección, catálogo ZIP, matriz de compatibilidad, planificación definitiva, ejecución, validación y publicación. ImageIO y PDFKit cubren formatos nativos; `ZEUVEEngines` resuelve FFmpeg/FFprobe, Pandoc, Calibre y Ghostscript únicamente cuando están realmente disponibles. La interfaz observa un ViewModel propio, las tareas pesadas se ejecutan fuera del hilo principal y los planes llevan revisión para impedir que un resultado obsoleto sustituya al actual. La publicación recibe el conjunto completo de originales, valida el temporal con el motor adecuado y solo después realiza el movimiento o reemplazo atómico.

## Optimización transversal 0.7.4

`AppModel` crea un único `EngineRegistry` y un único `EngineDiagnosticService` para el Descargador y el Conversor. `LatestValueCoalescer` limita publicaciones visuales demasiado frecuentes sin modificar el progreso real. Las caches temporales siguen asociadas a la sesión u operación que las creó.


## Flujo multimedia 0.7.5

La planificación de vídeo distingue entre recodificación y remux. En modo simple, una conversión de vídeo siempre construye una orden con codificador de vídeo; `-c:v copy` solo puede aparecer cuando el modo avanzado y la opción explícita de copia rápida están activos. Tras una recodificación, FFprobe confirma el códec producido.

Vídeo → fotogramas utiliza `VisibleFrameOutputCoordinator`. La carpeta de trabajo se crea en el mismo volumen y directorio de salida con sufijo `Procesando`, queda asociada a un registro privado de operación y se renombra al destino final al completar. La cancelación, el error o la recuperación posterior conservan el prefijo válido como `Incompleto`. Esta ruta evita la antigua copia completa entre el temporal interno y el destino.

`FrameTimingCSVCollector` consume incrementalmente las líneas `showinfo` emitidas por la misma ejecución de FFmpeg. El validador recorre progresivamente la carpeta, conserva una muestra acotada y solo puede retirar el último fotograma cuando está vacío, dañado o no coincide con el formato esperado.
