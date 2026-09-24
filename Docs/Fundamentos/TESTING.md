# Pruebas — ZEUVE 0.20.2.0

## Resultados actuales de 0.20.2.0

- `ExternalProcessRunnerTests`: la cancelación opt-in de preview con 50 ms termina padre/hijo y limpia el registro; en el helper que ignora SIGTERM completó en ~0,11 s frente a ~2,09 s con el default global de 2 s.
- `swiftc -parse` de los archivos SwiftUI modificados: PASS en el entorno portable.
- Las suites completas y verificadores se registran en `Docs/Historico/Pruebas/TEST_RESULTS_0.20.2.0.md`; el build Xcode/macOS debe ejecutarse en Apple Silicon.

## Resultados de 0.20.1.0

- `swift test --jobs 1`: PASS; Inspector multimedia **121 pruebas**, 0 fallos.
- Regresiones Python específicas de preview/análisis: **18/18**, PASS.
- `Scripts/verify/multimedia_inspector.py` y parseo de **80 fuentes Swift** de ZEUVEApp: PASS.
- `Scripts/verify_app_macos.sh`: PASS en macOS Apple Silicon; Xcode Debug, motores y firma local validados.
- Cobertura nueva: resolver de transporte, pausa de vídeo, ownership al cancelar, señales sintéticas, cutoff conocido, bajo dominante, gap espectral, cobertura temporal y agrupación/truncado de anomalías.


## Resultados actuales de 0.20.0.0

Entorno utilizado: Linux x86_64 con Swift 6.2.1. Esta validación cubre la lógica portable, persistencia, reglas de seguridad, manifests, documentación y generación Xcode, pero no sustituye el build ni el QA de AppKit/Security.framework/Spotlight/Papelera/Full Disk Access en macOS Apple Silicon.

- `./Scripts/run_tests.sh`: **PASS (RC=0)**.
- XCTest: **234 tests ejecutados**, 0 fallos y **1 omitido** por requerir macOS/ARM64.
- Swift Testing: **164 tests**, 0 fallos.
- `CleanerModuleTests`: **15/15**, 0 fallos.
- `NavigationPreferencesTests`: **4/4**, 0 fallos.
- Tests Python/estructurales: **108 tests**, 0 fallos y **1 omitido** por requerir Combine/macOS.
- Verificadores de integración, estructura, documentación, manifests, Xcode/SwiftPM, módulos y Limpiador: **PASS**.
- Parseo portable de ZEUVEApp: **79 fuentes Swift**, PASS.
- `swift build -c release --target CleanerModule --jobs 1`: **PASS**.
- El build Release SwiftPM global fue iniciado sin errores de compilación, pero no terminó dentro del límite de ejecución remoto; no se declara como PASS.
- `Scripts/verify_app_macos.sh`: etapa macOS omitida explícitamente al no disponer de macOS Apple Silicon con Xcode.

La cobertura 0.20.0.0 incluye normalización/persistencia de orden y atajos, conflictos y restauración; inventario del Limpiador con raíces inyectadas en tests; múltiples copias y volúmenes ausentes; App Groups; decisiones `Conservar`; LaunchItems; Xcode sin Archives; instaladores; symlinks; revalidación; resultados parciales; bloqueo seguro de datos asociados si la app no puede retirarse; Papelera/Undo y conflicto de restauración.

## Resultados históricos de 0.19.0.0

Entorno utilizado: Linux x86_64 con Swift 6.2.1. Esta validación cubre la lógica portable, políticas, manifests, documentación y generación Xcode, pero no sustituye las pruebas de SwiftUI/AppKit/AVFoundation/CoreVideo/VideoToolbox/Vision, firma, Hardened Runtime ni los motores Mach-O ARM64 en macOS Apple Silicon.

- `./Scripts/run_tests.sh`: PASS.
- Suites XCTest portables: **215 tests**, 0 fallos y **1 omitido** intencionadamente por requerir diagnóstico ejecutable macOS/ARM64.
- Swift Testing global: **164 tests**, 0 fallos.
- Inspector multimedia dentro de su suite portable: **109 tests**, 0 fallos.
- Pruebas Python de `Tests/ScriptTests`: **107/107**, 0 fallos.
- `Scripts/verify/multimedia_inspector.py`: PASS para manifest 0.7.0, preview, edición, batch, análisis, OCR, favoritas, privacidad, ayuda y schema 3.
- `Scripts/verify/project_structure.py`: PASS para ZEUVE 0.19.0.0, marketing 0.19.0, build 65 e Inspector 0.7.0.
- Proyecto Xcode regenerado mediante `Scripts/generate_xcode_project.py`; integra **75 fuentes Swift de ZEUVEApp** y las nuevas fuentes del módulo.

### Cobertura nueva de 0.19.0.0

- vídeo editable participa en draft/planner/command builder/result validator sin transcode;
- preview de vídeo respeta stream exacto, límites de resolución/FPS/buffer y fallback software;
- continuidad de playhead/Play-Pausa en cambios de streams;
- subtítulos textuales se parsean localmente y ASS/SSA mantiene la limitación documentada;
- carpetas no siguen symlinks y respetan profundidad/filtros;
- reglas semánticas no dependen de ordinal de pista y el preflight clasifica incompatibilidades;
- favoritas/rule sets no contienen archivos seleccionados ni rutas;
- OCR SRT se genera desde un borrador revisable y no exporta ruta de origen;
- informes schema 3 incluyen resúmenes nuevos sin rutas, fingerprints, IDs internos ni texto OCR;
- preferencias antiguas decodifican con defaults seguros para todos los campos 0.7.0.

### Validación pendiente exclusivamente de macOS

`./Scripts/build_macos.sh Release` no puede ejecutarse en este entorno Linux. Antes de considerar validados los componentes dependientes de plataforma deben probarse en un Mac Apple Silicon: render de frames, sincronización A/V perceptual, fullscreen, VideoToolbox y fallback real, Vision OCR con PGS/VobSub, VoiceOver, modo claro/oscuro, motores ARM64, firma y Gatekeeper.

`./Scripts/verify_project.sh` se lanzó en este entorno y completó sus suites antes de que el wrapper remoto alcanzara su límite durante una fase de build. Sus verificadores se ejecutan también por separado para registrar un resultado inequívoco; el build macOS sigue siendo necesariamente externo.

## Resultados verificados para 0.7.0

Entorno utilizado: Linux x86_64.

- `swift test`: 107 pruebas XCTest y 37 pruebas Swift Testing, 0 fallos.
- Pruebas Swift del Conversor: 37, 0 fallos.
- Pruebas Python de scripts y políticas: 19, 0 fallos.
- Sintaxis Bash/Python y manifiesto de motores: verificados.

Estos resultados no validan SwiftUI, AppKit, ImageIO, PDFKit, VideoToolbox, firma, Gatekeeper ni la apertura de la aplicación macOS. Esas comprobaciones permanecen pendientes de un Mac Apple Silicon con los motores opcionales preparados.

## Suite automática normal

```bash
./Scripts/run_tests.sh
```

No accede a YouTube ni requiere Internet. Cubre:

- 30 pruebas anteriores del núcleo, almacenamiento, coordinador y Organizador;
- manifiestos y permisos;
- historial global con un tercer módulo simulado;
- registro de motores, SHA-256, rutas y ausencia de bloqueo por diferencias de tamaño o hash tras la firma;
- salida incremental acotada;
- ejecución sin shell;
- cancelación de padre e hijo en un grupo real;
- terminación durante el cierre global;
- URLs válidas, cortas, playlists, inválidas y duplicadas;
- comandos simples, audio, formatos exactos, resolución, proxy, cookies y redacción de secretos;
- ausencia de actualización o descarga automática de motores;
- formatos, FPS, HDR, idiomas, subtítulos y directos;
- progreso conocido, desconocido, fragmentado y FFmpeg;
- playlist de 5.000 elementos mediante fixtures;
- nombres, conflictos, temporales, publicación y archivos `.part`;
- bookmarks obsoletos;
- historial, presets, favoritos y ausencia de secretos;
- JSON sanitizado sin URLs o credenciales;
- 8 pruebas del `pkg-config` local: versión, variables, requisitos agrupados, flags estáticos y errores;
- 3 pruebas de la política de firma: yt-dlp queda fuera de la refirma, el verificador empaquetado ejecuta `yt-dlp --version` y el build por Terminal vuelve a comprobar la app final;
- detalles técnicos del diagnóstico, incluida la salida estándar, la salida de error, el código y la señal de terminación.

## Cobertura añadida en la Fase 3 de mantenibilidad de 0.12.3

- Existencia de un único catálogo con los cinco módulos built-in y el alias legacy del Descargador.
- Registro de manifiestos, barra lateral, Dashboard y comandos consumiendo el catálogo en lugar de listas paralelas.
- Inyección de ViewModels por `BuiltInModuleViewRouter`, sin cinco `environmentObject` globales en `ZEUVEApp`.
- Ajustes dirigidos por metadatos del catálogo e Instagram Followers manteniéndose sin sección persistente.
- Presenters y aliases de historial centralizados, incluido `com.zeuve.youtube-downloader`, sin una rama específica en `GlobalHistoryViewModel`.
- Conservación del orden actual de la barra lateral y de los atajos ⌘1–⌘5.

## Cobertura añadida en 0.11.3

- Política de respaldo de TikTok cuando `gallery-dl` falla o termina correctamente sin producir archivos.
- Conservación de la URL pública estable reportada `7675703483303071009` en los comandos de ambos motores.
- Rechazo del falso éxito cuando `yt-dlp` tampoco deja archivos candidatos.
- Clasificación accionable del resultado vacío, referencia técnica y estado de fallo total.
- Presencia del título de fallo, aviso de que no se guardó ningún archivo y acción para abrir los registros.

## Cobertura añadida en 0.11.4

- Un enlace concreto de Instagram prioriza `yt-dlp`, conserva `gallery-dl` como respaldo y no usa la ruta de catálogo de perfiles.
- Un elemento público de Instagram ignora cookies manuales, `cookies.txt` y sesiones de navegador aunque estén configuradas.
- Un elemento que el análisis ha marcado como privado o autenticado sí puede recibir la sesión proporcionada.
- Los errores ambiguos de rate limit o redirección a login no se convierten automáticamente en una petición de inicio de sesión; solo las señales explícitas de contenido privado lo hacen.
- El reel público de referencia se analiza y descarga con el motor incluido sin argumentos de cookies.

## Validación ampliada

```bash
./Scripts/verify_project.sh
```

Añade:

- compilación Release de los paquetes Swift;
- pruebas de regresión de `static_pkg_config.py`, de la publicación segura de motores y de la política de firma de yt-dlp;
- validaciones estáticas de versión, manifiestos y arquitectura;
- comprobación de que FFmpeg no se duplica;
- comprobación de que no existe una vía de descarga automática de motores;
- validación de documentación y ejemplos;
- análisis sintáctico de todas las vistas SwiftUI/AppKit;
- regeneración del proyecto Xcode;
- en macOS ARM64: verificación de motores y compilación Debug con Xcode.

## Verificación específica de motores

```bash
./Scripts/verify_engines_macos.sh
```

Comprueba:

- campos obligatorios de `engines.json`;
- SHA-256 y tamaño;
- licencias;
- arquitectura ARM64 o universal esperada;
- versión informada por el ejecutable;
- permisos;
- dependencias con `otool -L`;
- ausencia de rutas Homebrew, MacPorts o `/usr/local`;
- libmp3lame y libopus presentes;
- libx264 y libwebp presentes en la preparación aprobada; libx265 ausente;
- FFmpeg y FFprobe almacenados una sola vez.


## Verificación de motores ya empaquetados

```bash
./Scripts/verify_packaged_engines_macos.sh /ruta/ZEUVE.app
```

Comprueba la firma de los cuatro ejecutables incluidos y ejecuta `yt-dlp --version` dentro del paquete. La fase de build lo llama automáticamente y detiene la compilación si falla.

## Pruebas reales contra YouTube

Son opcionales, se ejecutan manualmente y no forman parte de la suite normal porque la respuesta de YouTube cambia. El script permanece desactivado salvo que se proporcionen variables explícitas:

```bash
ZEUVE_ENABLE_YOUTUBE_INTEGRATION_TESTS=1 \
ZEUVE_YOUTUBE_TEST_URL='https://www.youtube.com/watch?v=ID_AUTORIZADO' \
./Scripts/run_youtube_integration_tests_macos.sh
```

Para permitir además una descarga temporal se añade `ZEUVE_YOUTUBE_ALLOW_DOWNLOAD=1`. Debe utilizarse contenido público y autorizado para comprobar:

- análisis de vídeo;
- audio original y MP3;
- vídeo con unión de streams;
- playlist y selección de intervalo;
- subtítulos;
- cancelación en descarga y FFmpeg;
- contenido privado, eliminado, restringido y directos;
- funcionamiento sin conexión.

## Pruebas manuales macOS pendientes en esta entrega

- compilación Debug y Release de `ZEUVE.app`;
- apertura real de ambas configuraciones;
- firma y Gatekeeper;
- navegación, dashboard y global history;
- NSOpenPanel, bookmarks y `cookies.txt`;
- arrastrar y soltar;
- modos claro y oscuro;
- progreso, cancelación y cierre de aplicación;
- motores ausentes, firmados, con arquitectura incorrecta o con versión incorrecta;
- descarga real de vídeo, audio y playlist.
- fluidez real del Analizador al cambiar filtros, pestañas, búsqueda, granularidad y ajustes con chats grandes;
- comportamiento visual de los indicadores `Actualizando estadísticas…` y `Buscando…`.

No deben darse por superadas hasta ejecutarlas en un Mac Apple Silicon con los motores preparados.

## Cobertura añadida en 0.4.0

- Conservación de las pruebas de MP4, MP3, 320 kbps, Título y migración de presets.
- Validación estática de las secciones General, Organizador y Descargador dentro de Ajustes.
- Validación de las subsecciones Predeterminados, Presets y Diagnóstico del Descargador.
- Ausencia de botones Presets, Diagnóstico o ruedas de ajustes dentro de los módulos.
- Persistencia actual mediante `universalDownloader.defaultSettings` y `universalDownloader.defaultAdvancedMode`, manteniendo `youtube.defaultSettings` y `youtube.defaultAdvancedMode` únicamente como claves legacy de lectura/migración; `organizer.defaultOptions` continúa independiente.
- Comprobación de que las opciones de una operación del Organizador no sobrescriben sus valores predeterminados.
- Presencia del selector rápido de presets dentro del Descargador.
- Análisis sintáctico de todas las vistas SwiftUI/AppKit afectadas.

Tras ZEUVE 0.4.0, la batería contenía 107 pruebas XCTest, 37 pruebas Swift Testing y 21 pruebas Python; las cifras actuales se recogen en la sección 0.8.0.


## Cobertura añadida en 0.5.0

- 22 pruebas Swift específicas del Analizador de chats.
- WhatsApp: variantes de cabecera, multilínea, adjuntos y conservación del original.
- Instagram: catálogo, páginas, duplicados, enlaces, fechas y zonas horarias.
- Seguridad: rutas ZIP, temporales propios y manifiesto sin red.
- Motor: filtros nocturnos, palabras, bigramas, emojis, conversaciones, respuestas, búsqueda y deduplicación.
- Privacidad: historial completado, cancelado y fallido sin datos privados.
- Ajustes, cancelación y limpieza de la base temporal.

Los casos de prueba se generan en directorios temporales. No se utilizan ni se incorporan chats personales.


## Cobertura añadida en 0.5.1

- ZIP de WhatsApp cuyo `_chat.txt` supera la muestra de 256 KB, sin convertir esa muestra en un límite de archivo.
- Límite opcional por archivo: desactivado por defecto y rechazo completo cuando el usuario lo configura.
- TXT directo con adjuntos no comprobados y nombres de sticker WEBP correctamente clasificados.
- ZIP de Instagram con una conversación directamente en la raíz lógica y rutas multimedia reubicadas.
- Validaciones estáticas del cuadro de importación según plataforma y de la selección automática de un único chat.
- Prueba temporal con los dos ZIP reales aportados, sin copiar su contenido al proyecto ni a la suite permanente.

## Cobertura añadida en 0.5.2

- La vista raíz del Analizador observa directamente su ViewModel y alterna de inmediato entre resultados e importación.
- `Cerrar análisis` conserva las fuentes seleccionadas y `Analizar otro chat` las limpia.
- Las nueve pestañas de resultados incluyen una ayuda contextual general.
- Las métricas, gráficos, grupos y columnas no evidentes reutilizan el componente común `info.circle`.
- Las ocho reglas permanentes nuevas y la renumeración de la regla final se verifican automáticamente.
- Análisis sintáctico de todas las vistas SwiftUI/AppKit afectadas.

## Cobertura añadida en 0.5.3

- Equivalencia entre las instantáneas optimizadas y los cálculos directos de actividad, horas, días, mapa de calor, palabras, bigramas y emojis.
- Reutilización del índice de búsqueda al cambiar de página sin repetir la consulta completa.
- Chat sintético de 35.000 mensajes para resumen, filtros, actividad, participantes y búsqueda.
- Validaciones estáticas de cálculo en segundo plano, propagación de cancelación, revisiones contra resultados obsoletos y espera de 200 ms en búsqueda.
- Comprobación de que las vistas consumen instantáneas y no llaman directamente a cálculos pesados.
- Comprobación de que salir de Búsqueda cancela la tarea y de que los ajustes no relacionados no reconstruyen el núcleo completo.
- Compilación SwiftPM Release y análisis sintáctico de las vistas modificadas.


## Cobertura añadida en 0.5.5

- Los ocho gráficos Swift Charts y el mapa de calor disponen de interacción por hover.
- El tooltip conserva la posición del cursor, cambia de lado en los bordes superior y derecho y limita su posición dentro del área visible.
- No quedan anotaciones fijadas al borde superior mediante `annotation(position: .top)`.
- La capa común utiliza `chartOverlay`, `ChartProxy.plotFrame` y `onContinuousHover` para transformar la posición del cursor sin recalcular estadísticas.
- Los gráficos temporales muestran una guía, puntos resaltados, periodo exacto y valores de todas las series visibles.
- Las comparaciones incluyen ambas personas y el total; las barras y el mapa de calor resaltan la categoría o celda activa.
- La búsqueda del punto temporal más cercano se realiza sobre fechas ordenadas mediante búsqueda binaria.
- Una prueba estática impide introducir llamadas analíticas pesadas en `InteractiveChartSupport.swift`.
- Se analiza sintácticamente el nuevo componente SwiftUI y la vista completa de resultados.

## Cobertura añadida en 0.6.0

- Numeración y presencia de las reglas permanentes 64 a 78.
- Existencia de una única `REGLA FINAL`.
- Presencia de las políticas aprobadas sobre interfaz responsiva, caché, resultados obsoletos, cálculo bajo demanda, interacción gráfica ligera y validación en macOS.
- Coherencia entre la versión 0.6.0, el build 20, la vista de Ajustes, el proyecto Xcode y los informes de entrega.
- Conservación de la versión 0.1.5 del Analizador al no existir cambios funcionales en su código.

## Conversor universal

Las pruebas de 0.6.0 se conservan. En 0.7.0 el Conversor alcanza 37 pruebas Swift específicas y añade detección discrepante, estructura OOXML/ODF/EPUB, inspección dentro de ZIP, matriz por motor, lotes heterogéneos de una categoría, rechazo entre categorías, protección frente a otro original del lote, límites de profundidad, migraciones, favoritas sin datos privados, formatos portables, capacidades de FFmpeg, limpieza de temporales y argumentos seguros de Pandoc, Calibre y Ghostscript.

## Cobertura añadida en 0.7.4

- Equivalencia entre búsqueda directa e índice compacto temporal.
- Cambio automático a almacenamiento temporal mapeado y eliminación de sus archivos.
- Reutilización de una sentencia SQLite para inserciones por lotes.
- Presencia del índice global del historial.
- Agrupación del último progreso pendiente y entrega inmediata de estados finales.
- Regresiones estáticas para diagnóstico compartido, escáner reutilizable, rutas originales precalculadas y eliminación del resumen descartado.


## Cobertura añadida en 0.7.5

- El modo simple MP4 → MP4 y otras conversiones de vídeo no pueden seleccionar copia exacta ni generar `-c:v copy`.
- La copia rápida de la pista de vídeo se conserva únicamente cuando el modo avanzado y la opción de remux están activos.
- Los valores predeterminados y el preajuste oficial MP4 priorizan recodificación real.
- La extracción PNG utiliza compresión nivel 3, predictor Up y `showinfo=checksum=0`.
- `FrameTimingCSVCollector` genera `tiempos.csv` desde la misma salida de FFmpeg.
- La carpeta visible se completa mediante movimiento/renombrado en el mismo volumen, sin copiar el árbol de fotogramas.
- La cancelación o el fallo conservan resultados como `Incompleto`, renombran el CSV parcial y eliminan únicamente un último fotograma dañado.
- Una operación visible abandonada puede recuperarse de forma segura usando el registro del workspace.
- Prueba funcional sintética: 90 fotogramas extraídos y MP4 recodificado con H.264, huella distinta y contenido verificable mediante FFprobe.
- Benchmark sintético Linux 1080p/150 fotogramas: 5,15 s en el flujo anterior simulado frente a 2,99 s en el nuevo; la medición no sustituye la validación en Apple Silicon.

## Cobertura añadida en 0.8.0

- 21 pruebas XCTest del Comparador para variantes JSON, prioridad de extracción, URLs directas y `/_u/`, valores vacíos, estructuras incompatibles y normalización.
- Deduplicación entre varios archivos, orden numérico con huecos y categorías de comparación.
- ZIP con carpeta raíz arbitraria, lectura selectiva y errores por múltiples `following.json` o ausencia de seguidores.
- Exportación CSV, rechazo de sobrescritura silenciosa e historial sin nombres privados.
- Caso sintético con 40.000 cuentas seguidas y 35.000 seguidores únicos.
- Cancelación del parser sin publicación de resultados parciales.
- Cinco regresiones Python para navegación, catálogo previo, búsqueda en memoria, apertura externa manual, permisos e historial agregado.
- Análisis sintáctico de todas las vistas SwiftUI y regeneración del proyecto Xcode.
- Suite completa validada en Linux: 128 pruebas XCTest, 45 pruebas Swift Testing y 26 pruebas Python, sin fallos.
- La compilación y prueba visual con AppKit continúan siendo obligatorias en un Mac Apple Silicon.


## Cobertura añadida en 0.9.0

- Validación de URLs universales, duplicados y bloqueo predeterminado de HTTP, localhost y red privada.
- Conservación de la normalización específica de enlaces históricos de YouTube.
- Parser HTML sintético para `video`, `source`, `iframe`, metadatos, JSON-LD, HLS y DASH.
- Deduplicación de referencias repetidas antes de la descarga.
- Normalización que elimina parámetros de seguimiento y tokens temporales solo para comparar, sin alterar la URL operativa.
- Validación y filtrado de cookies Netscape por dominio, ruta, seguridad y caducidad.
- Decodificación compatible de ajustes anteriores que no contenían la opción de red local.
- Migración de presets, bookmarks y ajustes antiguos.
- Historial bajo identificador nuevo y lectura del identificador heredado sin guardar URLs o secretos.
- Regresión del patrón de nombre de colección, temporales, publicación, cancelación, manifiesto y comandos seguros.
- Análisis sintáctico de las vistas macOS modificadas.

Las pruebas de red reales, la compilación de AppKit/SwiftUI, el empaquetado ARM64, la firma y la apertura de la aplicación continúan requiriendo un Mac Apple Silicon.

## Cobertura añadida en 0.9.1

- Separación persistente entre enlaces directos y vídeos descubiertos durante el análisis de una página.
- Verificación de que los vídeos de páginas usan `bestvideo*+bestaudio/best`, sin formato forzado, extracción de audio, límite de resolución, subtítulos, miniaturas, capítulos o metadatos estándar.
- Regresión que confirma que los enlaces directos mantienen formatos exactos, contenedor y metadatos configurados.
- Nombres limpios y numeración completa desde `(1)` cuando varios vídeos comparten título, incluyendo secuencias originales `(1)`, `(3)`, `(5)`.
- Conservación de títulos únicos que contienen un año u otro número entre paréntesis.
- Construcción de metadatos de procedencia mediante `-c copy`, URL saneada, dominio, ID de página y fecha opcional.
- Compatibilidad de decodificación con ajustes anteriores que no incluían opciones de procedencia.
- Persistencia de las opciones de procedencia dentro de los ajustes centralizados.
- Análisis sintáctico de las vistas modificadas y comprobación de que las opciones de red y cookies siguen disponibles para descargas originales.

La inserción real de metadatos, el atributo extendido «De dónde», la interfaz SwiftUI, la firma y la apertura deben validarse finalmente en un Mac Apple Silicon.
## Cobertura añadida en 0.9.2

- Extracción y conservación temporal de URLs directas, manifiestos HLS/DASH, caducidad y cabeceras necesarias durante el análisis.
- Codificación segura de `YouTubeResolvedMediaReference`: la URL firmada, tokens y cabeceras no aparecen en JSON ni almacenamiento persistente.
- Generación de comandos que utiliza el recurso resuelto en lugar de volver a abrir la página y que oculta las cabeceras en la representación redactada.
- Reducción adaptativa 16 → 8 → 4 → 1 únicamente ante errores de fragmentos, limitación o red compatibles.
- Decodificación de ajustes anteriores con aceleración adaptativa activada de forma segura.
- Publicación en el mismo volumen mediante movimiento: el archivo temporal deja de existir y aparece íntegro en destino sin una copia adicional.
- Conservación de la copia segura tradicional cuando no puede demostrarse que origen y destino pertenecen al mismo volumen.
- Reutilización de la validación FFprobe realizada al incrustar procedencia para evitar una segunda validación completa.
- Regresiones estáticas de interfaz, ajustes centralizados, ayuda contextual y minimización de datos.

Las pruebas sintéticas no sustituyen una medición con la página privada del usuario ni la validación final de velocidad, interfaz, atributos extendidos y publicación en macOS Apple Silicon.



## Cobertura añadida en 0.10.0

- 13 pruebas específicas del descargador social/universal.
- Bloqueo de contenido adulto y dominios configurables.
- Validación de perfiles de Instagram y enlaces concretos del resto de redes.
- Catálogo de perfiles privados, stories, foto de perfil y paginación.
- Conversión de sesión pegada a cookies Netscape con permisos 0600.
- gallery-dl con imágenes y vídeos sin recomprimir.
- historial de avatares y búsqueda histórica Wayback.
- gestión de motores externos y restauración del incluido.
- 158 pruebas XCTest/Swift, 45 pruebas Swift Testing y 32 pruebas Python superadas en Linux.

## Actualización — robustecimiento 0.12.4 (2026-09-07)

La suite portable incorpora regresiones específicas para la cancelación estructurada de procesos externos, retención/permisos de logs, conservación de bookmarks irresolubles, rechazo y cancelación de ZIP, deduplicación/orden/paginación de `TemporaryChatStore` y equivalencia de las analíticas SQLite con las analíticas heredadas sobre un dataset representativo. Los verificadores de Fase 5 se actualizan para proteger la arquitectura nueva y dejan de exigir caches o snapshots que materializaban la conversación completa.

Resultados portables antes del cierre documental: 214 XCTest ejecutados, 0 fallos y 1 omitida por requerir macOS Apple Silicon; 47 pruebas Swift Testing, 0 fallos; 79 pruebas Python, 0 fallos. La validación Xcode ARM64, firma, apertura real y motores empaquetados sigue siendo obligatoria en macOS Apple Silicon.

## Inspector multimedia — cobertura 0.13.0

La nueva cobertura se distribuye entre `ZEUVEEnginesTests/MediaInspectionTests.swift`, `MultimediaInspectorModuleTests` y regresiones Python de integración. Se comprueban parser FFprobe tolerante, estructura multimedia, racionales, modo offline/manifest, Undo/Redo, planner, política híbrida, MKV/MP4/MOV/WebM, command builder sin shell, fingerprints, symlinks, publicación sin sobrescritura y matemáticas del espectrograma.

Las pruebas DSP incluyen tonos sintéticos de 440 Hz, 1 kHz y 10 kHz, distintos sample rates, tamaños FFT, ventanas, silencio, amplitud baja, estéreo/multicanal y bloques incompletos. En Linux la DFT propia de referencia permite probar la matemática; la ruta Accelerate/vDSP y el render SwiftUI se validan finalmente en macOS Apple Silicon.

`Scripts/verify/multimedia_inspector.py` impide que pase QA una integración parcial: exige target/testTarget, manifest offline, catálogo/router/AppModel, atajo, ausencia de ajustes visibles, FFprobe compartido, eliminación del parser antiguo del Conversor, pipeline de draft/plan, stream copy, protección del original, espectrograma incremental y documentación específica.


## Inspector multimedia — cobertura Fase 1 0.13.1.0

La regresión añade comprobaciones específicas para que la escala lineal/logarítmica proceda de una función matemática compartida por UI y exportación, para que la rasterización cambie realmente al cambiar de escala, para que una señal estéreo en oposición de fase siga apareciendo en `Mezcla`, y para que una duración conocida nunca supere `maximumColumns`. También se conserva la prueba de streaming/cancelación real del decoder PCM.

El módulo pasa de 26 a 30 pruebas Swift Testing específicas antes de ejecutar la suite global. Los resultados finales de la entrega se registran en `Docs/Historico/Pruebas/TEST_RESULTS_0.13.1.0.md`.


## Cobertura añadida para Inspector multimedia 0.14.0.0

- resolución segura de nombres de canal y fallback `Canal N`;
- ticks temporales/frecuenciales y lectura dB aproximada del espectrograma;
- command builder de preview con `-map` exacto, salida `f32le`, canal individual y ausencia de shell;
- identidad efímera de fuente/fingerprint;
- formatters técnicos locales;
- regresión de draft/reordenación y del motor espectral 0.13.2.0.

El audio real de AVAudioEngine, las APIs SwiftUI de drag & drop y el build AppKit/SwiftUI deben validarse finalmente en macOS Apple Silicon.

## Cobertura añadida para Inspector multimedia 0.15.0.0

La suite del módulo cubre, además de las regresiones anteriores:

- envolvente waveform bipolar real, mezcla antífase, canal individual y límite de buckets;
- reducción visual que conserva picos;
- compatibilidad de decodificación de preferencias antiguas y persistencia en `SettingsRepository`;
- comando y parser de sonoridad EBU R128;
- offsets positivos/negativos de timestamps;
- saneamiento del informe JSON para no exportar ruta completa, fingerprint ni source ID interno.

Los verificadores estructurales comprueban también las acciones para sustituir/cerrar análisis, la superficie central de Ajustes y la presencia de waveform/sonoridad/timing/reporting.

## Cobertura añadida para Inspector multimedia 0.15.9.0

La suite añade pruebas sintéticas para silencio multicanal (incluida oposición de fase), umbral/duración, clipping consecutivo y agrupado, audio fuerte por debajo del umbral de clipping, bloques PCM interleaved partidos, límites de almacenamiento de eventos, compatibilidad de preferencias antiguas y command builder que conserva sample rate/canales. Los verificadores estructurales exigen además `OperationCoordinator`, fingerprint, streaming `f32le`, ajustes centralizados, overlays temporales y orden automático espectrograma → señal → sonoridad.

## Cobertura añadida para Inspector multimedia 0.16.0.0

La suite añade pruebas para parser periódico EBU R128, tratamiento de medidas no finitas, compactación acotada de la serie conservando extremos, métricas técnicas A/B y exportación JSON schema 2 con señal/timeline sin identidades privadas. Las regresiones Python verifican que el mapa no crea otro runner, que A/B no sincroniza silenciosamente `selectedAudioStreamIndex`, que señal/sonoridad faltantes se ejecutan secuencialmente y que waveform y Espectrograma consultan fuentes de análisis distintas cuando corresponde.

La continuidad real AVAudioEngine/SwiftUI, el cambio audible A↔B, el layout de la nueva franja y la compilación/firma Xcode se validan finalmente en macOS Apple Silicon.

## Cobertura añadida para Inspector multimedia 0.18.0.0

La suite Swift añade pruebas de normalización de configuración de lote, IDs estables de presets incluidos, persistencia sin rutas/archivos, política de nombres y estimación de espacio, secciones configurables de informes e historial agregado sin identidad privada. Las regresiones Python verifican que el procesador no genera waveform/preview, que mantiene secuencia estricta, que no elige audio multitrack, que los presets usan almacenamiento centralizado/versionado, que la nueva superficie de preferencias expone los comportamientos personalizables y que las colas grandes usan renderizado perezoso.

La suite global portable se mantiene junto con las regresiones de reproducción, A/B, espectrograma, señal, sonoridad, edición estructural, remux, publicación y motores. La interacción real de `NSOpenPanel`, drag & drop, SwiftUI, AVAudioEngine, Xcode, Hardened Runtime y motores ARM64 se valida finalmente en macOS Apple Silicon.

## Cobertura añadida para Inspector multimedia 0.18.1.0

Las regresiones verifican que Ajustes y las vistas principales mantienen los temas de ayuda aprobados, que las métricas técnicas principales tienen explicación contextual, que el Inspector reutiliza `ContextualHelpButton`/`Help*` en lugar de crear iconos `info.circle` paralelos y que el archivo de temas de ayuda no contiene acciones que ejecuten o invaliden análisis. La validación manual final en macOS cubre popovers, teclado, VoiceOver, modo claro/oscuro y layouts estrechos.

## ZEUVE 0.20.0.0 — navegación y Limpiador

La suite añade regresiones para orden/atajos persistentes y normalizados, así como un target `CleanerModuleTests`. Los scanners de mantenimiento admiten raíces/providers de test para evitar `/Applications`, `~/Library` y LaunchAgents reales. La cobertura incluye múltiples copias, volumen ausente, App Groups compartidos, decisiones `Conservar`, symlinks, Xcode/Archives, instaladores, revalidación, Papelera, Undo y conflictos de restauración. La UI AppKit, Security.framework, Spotlight/FDA y Papelera real requieren QA final en macOS Apple Silicon.
