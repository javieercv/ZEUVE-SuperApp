# Pruebas — ZEUVE 0.7.5


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
- Persistencia separada mediante `youtube.defaultSettings`, `youtube.defaultAdvancedMode` y `organizer.defaultOptions`.
- Comprobación de que las opciones de una operación del Organizador no sobrescriben sus valores predeterminados.
- Presencia del selector rápido de presets dentro del Descargador.
- Análisis sintáctico de todas las vistas SwiftUI/AppKit afectadas.

La batería automatizada actual contiene 107 pruebas XCTest, 37 pruebas Swift Testing y 21 pruebas Python.


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
