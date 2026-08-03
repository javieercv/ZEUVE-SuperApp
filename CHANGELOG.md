# Historial de cambios

## 0.7.5 — 2026-07-30

### Conversión real de vídeo
- El modo simple recodifica siempre la pista de vídeo; MP4 con códec automático utiliza H.264 y ya no puede resolverse como copia exacta o remux silencioso.
- La copia rápida sin recodificación permanece como opción avanzada explícita y desactivada por defecto, con ayuda y vista previa que explican que no reduce tamaño ni cambia calidad.
- Los ajustes persistentes migran de esquema 3 a 4 y el preajuste oficial `Vídeo MP4 compatible` pasa a recodificación; los preajustes personalizados se conservan.
- FFprobe verifica el códec de las salidas recodificadas antes de publicarlas.

### Vídeo a fotogramas
- Los fotogramas se escriben directamente en una carpeta visible `Procesando` dentro del destino y se publica mediante renombrado en el mismo volumen, sin una segunda copia completa.
- La cancelación, los errores y los cierres inesperados conservan los fotogramas válidos en una carpeta `Incompleto`; el CSV parcial se identifica por separado y solo puede retirarse el último fotograma si está dañado.
- PNG utiliza compresión nivel 3 y predictor Up manteniendo codificación sin pérdida.
- `tiempos.csv` se crea durante la misma ejecución de FFmpeg con `showinfo=checksum=0`, eliminando la segunda pasada completa de FFprobe.
- El progreso muestra la fase y el número real de fotogramas generados; la validación recorre la carpeta progresivamente y conserva una muestra acotada.

### Pruebas y versión
- Añadidas ocho pruebas Swift Testing para recodificación real, remux avanzado, configuración predeterminada, CSV en una pasada, publicación visible, conservación incompleta, último fotograma dañado y recuperación de operaciones abandonadas.
- Realizadas pruebas funcionales con vídeo sintético y un benchmark comparativo del flujo de fotogramas.
- ZEUVE elevada a 0.7.5, build interno 26; Conversor universal elevado a 0.2.2.
- No se añaden dependencias, motores, Internet, APIs ni cambios en los originales.

## 0.7.4 — 2026-07-30

### Rendimiento
- Añadida una caché compacta y temporal para búsquedas del Analizador, creada bajo demanda y con almacenamiento mapeado para volúmenes excepcionalmente grandes.
- La inserción en SQLite temporal reutiliza una única sentencia preparada y se elimina un resumen completo cuyo resultado se descartaba.
- Descargador y Conversor comparten el registro y diagnóstico de motores, manteniendo invalidación automática y actualización manual.
- El progreso frecuente de yt-dlp y FFmpeg se agrupa mediante control de generación para evitar redibujados excesivos y resultados obsoletos.
- El Conversor reutiliza su escáner, precalcula las rutas originales protegidas y genera instantáneas de progreso en una sola pasada.
- Los rankings de conversaciones se preparan dentro de la instantánea analítica; la limpieza de temporales y el historial salen del hilo principal.
- Añadido un índice SQLite global por fecha para el historial.

### Seguridad y compatibilidad
- Los índices de búsqueda permanecen dentro del espacio temporal de la sesión y se eliminan al cerrar o sustituir el análisis.
- Si la caché no puede construirse, se conserva la búsqueda directa anterior.
- No se añaden dependencias, motores, formatos, Internet, APIs ni cambios en la protección de originales.

### Pruebas y versión
- Añadidas seis pruebas XCTest para caché, temporales, SQLite, historial y agrupación de progreso.
- ZEUVE elevada a 0.7.4, build interno 25.
- Descargador elevado a 0.4.1, Analizador a 0.1.6 y Conversor a 0.2.1.

## 0.7.3 — 2026-07-16

### Cambios
- Eliminado LibreOffice del registro de motores, localización, diagnóstico, ejecución, preparación, firma y empaquetado.
- Eliminados del Conversor los formatos DOC, DOCX, XLS, XLSX, PPT, PPTX, ODT, ODS, ODP y RTF.
- Los archivos ofimáticos se rechazan explícitamente y no se interpretan como ZIP genéricos.
- CSV permanece como formato genérico de datos y conserva el uso auxiliar de `tiempos.csv`.
- Retirada la ruta SVG a PDF que dependía de LibreOffice.
- Actualizadas pruebas, documentación, proyecto Xcode y versión a build 24.

## 0.7.2 — 2026-07-07

### Motores y distribución
- Corregida la instalación de x264 r3222: el script deja de invocar el objetivo inexistente `install-headers`.
- Se mantiene únicamente `make install-lib-static`, cuyo objetivo dependiente `install-lib-dev` instala las cabeceras `x264.h`, `x264_config.h` y el archivo `x264.pc` antes de instalar `libx264.a`.
- Añadida una regresión que exige el objetivo compatible y prohíbe recuperar `install-headers`.

### Versión
- ZEUVE elevada de 0.7.1 a 0.7.2, build interno 23.
- El módulo Conversor permanece en 0.2.0 porque la corrección afecta exclusivamente al script de preparación de motores.

## 0.7.1 — 2026-07-07

### Motores y distribución
- Corregida la URL de respaldo de la licencia de Calibre 9.11.0: el script descarga `LICENSE` desde el tag oficial en lugar del archivo inexistente `COPYING`.
- La licencia se guarda en `licenses/calibre/LICENSE` y esa ruta se registra en el manifiesto generado.
- Añadida una regresión estática que impide recuperar la URL que devolvía HTTP 404.

### Versión
- ZEUVE elevada de 0.7.0 a 0.7.1, build interno 22.
- El módulo Conversor se mantiene en 0.2.0 porque no cambia su contrato ni su comportamiento funcional.

## 0.7.0 — 2026-07-07

### Conversor universal 0.2.0
- Sustituida la detección basada en extensión por una detección combinada de firma, contenido, UTI, MIME, estructura interna y capacidades de los motores, con nivel de confianza y avisos de discrepancia.
- Separadas las categorías de documentos, hojas de cálculo, presentaciones, texto, marcado, vectoriales, animaciones y libros electrónicos para impedir conversiones incoherentes.
- Añadido un registro central de compatibilidad que relaciona entrada, salida, motor, recodificación, copia directa, pérdidas, opciones y disponibilidad real.
- Permitidos lotes con formatos distintos de una misma categoría cuando todos admiten la misma receta; los elementos incompatibles se identifican individualmente.
- Reforzada la protección absoluta de originales: cada salida se compara con todas las entradas del lote y nunca puede publicar sobre un original, ni siquiera con reemplazo autorizado.
- Resueltos antes de convertir la carpeta efectiva, nombres, colisiones, estructura ZIP y sobrescrituras para que la vista previa coincida con el resultado publicado.
- Añadidos los preajustes oficiales Bajo, Medio, Alto, Máxima calidad y Personalizado, con Máxima calidad como valor predeterminado y migración segura desde 0.6.0.
- Añadidas favoritas persistentes y exportables, bookmarks de carpeta, políticas de metadatos, subcarpeta de salida, nombres avanzados, límites ZIP, paralelismo y limpieza de temporales.
- Añadidas rutas seguras para Pandoc, Calibre y Ghostscript; soporte de H.264 por software con libx264, WebP mediante libwebp, secuencias, animaciones y validación específica por formato.
- Añadido soporte de contraseña para ZIP y PDF compatible con PDFKit, mantenida únicamente en memoria y nunca persistida.
- Ampliados progreso individual y global, cancelación, comprobación de espacio, validación de resultados, diagnóstico de motores y clasificación de errores.

### Motores y distribución
- Aprobados Pandoc 3.10, Calibre 9.11.0, Ghostscript 10.07.1, x264 r3222 y libwebp 1.6.0 para preparación local y offline en Apple Silicon.
- FFmpeg 8.1.2 se prepara con libx264 y libwebp; libx265 continúa excluido.
- Los scripts preservan las firmas oficiales de LibreOffice y Calibre y firman únicamente los ejecutables compilados o gestionados por ZEUVE.
- `engines.json` registra los motores opcionales como no proporcionados hasta que el script de macOS los prepare y sustituya por hashes y tamaños reales.
- Ghostscript se ejecuta con modo seguro y rutas de recursos internas; ningún motor se obtiene dinámicamente durante el uso de la aplicación.

### Pruebas y documentación
- Añadidas regresiones de detección, estructura OOXML/ODF/EPUB, ZIP anidado, matriz por motor, lotes mixtos, originales, favoritos, migraciones, argumentos seguros y limpieza de temporales.
- Actualizados README, arquitectura, seguridad, compilación, alcance, matriz de compatibilidad e informes de implementación, pruebas y entrega.
- Validación realizada en Linux x86_64; las pruebas nativas, firma, empaquetado y apertura de la aplicación siguen pendientes de un Mac Apple Silicon.

### Versión
- ZEUVE elevada de 0.6.0 a 0.7.0, build interno 21.
- `com.zeuve.universal-converter` elevado de 0.1.0 a 0.2.0.

## 0.6.0 — 2026-07-06

### Conversor universal
- Añadido el módulo oficial `com.zeuve.universal-converter` 0.1.0 para imágenes, audio, vídeo, documentos, PDF, texto, datos y entradas ZIP.
- Incorporadas detección por contenido, inspección progresiva de carpetas y lectura segura de ZIP sin extraer archivos pesados durante el catálogo.
- Añadidas vista previa, caché selectiva, revisión de planes para descartar resultados obsoletos, progreso, cancelación, historial y ajustes centralizados.
- Añadida extracción de todos los fotogramas a PNG o TIFF, con resolución original, frecuencia variable conservada y `tiempos.csv` opcional.
- Añadida creación de vídeo desde audio con fondo negro o imagen elegida, H.264 VideoToolbox y audio copiado cuando es compatible.
- Añadidas conversiones PDF por páginas, extracción de texto real y creación de PDF a partir de imágenes multipágina.
- Añadida conversión de documentos mediante LibreOffice 26.2.4 ARM64, ejecutado sin interfaz y con perfil temporal aislado.
- Las imágenes se convierten mediante ImageIO nativo para evitar dependencias adicionales y procesar todas las páginas o fotogramas.
- Los resultados se generan en temporales controlados, se validan y se publican atómicamente sin modificar los originales.
- Añadida opción para conservar la estructura de un ZIP y volver a comprimir únicamente los resultados.
- Añadido soporte para ZIP cifrados mediante contraseña temporal exclusivamente en memoria, sin persistencia ni registro.
- Añadidos preajustes del Conversor: creación, renombrado, duplicado, eliminación y restauración desde Ajustes, con selector rápido dentro del módulo.
- Añadidos controles avanzados de imagen, audio y vídeo, copia exacta cuando no existe transformación y conservación opcional de portadas integradas en MP3, M4A y FLAC.

### Motores, pruebas y documentación
- Los scripts de macOS preparan, verifican y empaquetan LibreOffice completo conservando su firma original.
- FFmpeg debe exponer `h264_videotoolbox`, `hevc_videotoolbox` y `prores_ks`; siguen prohibidos libx264 y libx265.
- Añadidas pruebas de rutas, caché, 600 archivos, ZIP con estructura y cifrado, conflictos, huellas, preajustes, copia exacta, portada integrada, opciones avanzadas, fotogramas y vídeo desde audio.
- Actualizados versión, proyecto Xcode, arquitectura, alcance, seguridad, compilación y documentación de entrega.


## 0.5.6 — 2026-07-06

### Reglas y políticas
- Incorporadas catorce reglas permanentes sobre interfaz responsiva, cálculos fuera del hilo principal, caché, invalidación selectiva, cálculo bajo demanda, cancelación de resultados obsoletos y separación del estado visual y analítico.
- Definido un estándar común para gráficos interactivos, tooltips siempre visibles, interacción ligera y coherencia entre todos los gráficos de un módulo.
- Añadidas reglas de regresión de rendimiento, pruebas con volúmenes representativos y validación final en el entorno macOS objetivo.
- La regla final se renumera como 78, manteniendo intacto su contenido y prioridad.

### Documentación
- `PROJECT_DECISIONS.md` consolidado para ZEUVE 0.5.6 sin duplicar decisiones ya registradas del Analizador.
- Actualizadas las referencias de versión, compilación, seguridad, alcance, arquitectura y pruebas.
- Añadidos los informes de pruebas y entrega de 0.5.6.

### Versión
- ZEUVE elevada a 0.5.6, build interno 19.
- El módulo `com.zeuve.chat-analyzer` permanece en 0.1.5 porque no se modifica su código ni su comportamiento.


## 0.5.5 — 2026-07-03

### Corregido
- Los tooltips de los gráficos dejan de estar anclados al borde superior y siguen ahora la posición real del cursor.
- El cuadro se desplaza automáticamente al lado opuesto cuando el puntero se acerca al borde superior o derecho.
- La posición final se limita al área visible del gráfico o mapa de calor para evitar recortes en cualquiera de sus bordes.
- El mapa de calor transforma la posición local de cada celda al espacio común de la tarjeta y utiliza el mismo posicionamiento dinámico.

### Interfaz y rendimiento
- La guía, el punto, la barra o la celda resaltada permanecen asociados al dato exacto mientras el tooltip se mueve junto al cursor.
- El movimiento solo actualiza coordenadas efímeras de interfaz y sigue utilizando las instantáneas en caché, sin recalcular estadísticas.
- Eliminadas las anotaciones `position: .top` de Swift Charts que provocaban que el contenido quedara oculto en la parte superior.

### Pruebas
- La regresión de interfaz exige posicionamiento junto al cursor, inversión en los bordes, límites dentro del contenedor y ausencia de tooltips fijados arriba.
- Se mantiene la cobertura de los ocho gráficos Swift Charts y del mapa de calor.

### Versión
- ZEUVE elevada a 0.5.5, build interno 18.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.5.

## 0.5.4 — 2026-07-03

### Interfaz
- Todos los gráficos del Analizador muestran un tooltip al pasar el cursor, sin necesidad de hacer clic.
- Los gráficos temporales resaltan el punto y la fecha o periodo exacto mediante una guía vertical.
- Las barras resaltan la categoría activa y muestran su valor exacto; el mapa de calor resalta la celda con día, franja horaria y mensajes.
- Los gráficos comparativos muestran las dos series del instante o categoría seleccionada y su total conjunto.
- Las fechas, horas, cifras y duraciones se presentan en español y con formato legible.

### Rendimiento
- La interacción utiliza exclusivamente las instantáneas ya calculadas y no vuelve a recorrer los mensajes ni invalida la caché analítica.
- La localización del punto temporal más cercano usa búsqueda binaria sobre las fechas mostradas.
- El histograma de respuestas se calcula en una sola pasada sobre sus muestras.
- El estado de hover se descarta al cambiar de gráfico, participante, granularidad o pestaña.

### Arquitectura
- Añadido `InteractiveChartSupport.swift` con tooltip, seguimiento de fechas, seguimiento de categorías y formateadores comunes.
- La interacción se implementa con una capa `chartOverlay` independiente de la lógica analítica y se reutiliza en líneas, barras y comparaciones.

### Pruebas
- Añadida una regresión estática que exige hover ligero en todos los gráficos, tooltip común, uso de `ChartProxy` y ausencia de cálculos analíticos pesados en la capa de interacción.
- 101 pruebas Swift y 19 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release, análisis sintáctico de las vistas y `Scripts/verify_project.sh` completados correctamente.

### Versión
- ZEUVE elevada a 0.5.4, build interno 17.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.4.

## 0.5.3 — 2026-07-03

### Rendimiento
- El Analizador deja de recalcular estadísticas pesadas desde las propiedades de las vistas SwiftUI.
- Añadida una caché central de instantáneas para resumen, actividad, participantes, palabras, conversaciones, respuestas, comparación y búsqueda.
- Los cálculos analíticos se ejecutan en tareas separadas del hilo principal y los resultados se publican una sola vez al finalizar.
- Las pestañas pesadas se calculan de forma diferida al abrirlas y reutilizan sus resultados mientras el estado relevante no cambie.
- Los cálculos anteriores se cancelan cuando cambian filtros, fusiones, ajustes, participantes, granularidad o consulta; una revisión interna descarta resultados obsoletos.
- La búsqueda espera 200 ms después de la última edición y reutiliza su índice al cambiar de página, tamaño o contexto.
- Los filtros aplican una espera breve de 120 ms y mantienen visible el último resultado válido mientras se actualizan las estadísticas.
- Los cambios de ajustes analíticos invalidan únicamente las secciones relacionadas, sin reconstruir el núcleo completo del análisis.

### Optimizado
- La ausencia de filtros reutiliza directamente la colección normalizada y evita una copia completa innecesaria.
- Los componentes de calendario solo se calculan cuando existe un filtro por día u hora.
- Actividad, mapa de calor, horas y días se generan en una única pasada sobre los mensajes.
- Palabras, frases de dos palabras, emojis, frecuencias por participante y tipos de contenido se generan en una única pasada.
- Las series temporales ya no construyen claves de texto por cada mensaje.
- Las expresiones regulares compartidas de enlaces y tokenización se compilan una sola vez.
- Salir de Búsqueda cancela inmediatamente su tarea en segundo plano y evita indicadores bloqueados.

### Interfaz
- Añadidos indicadores discretos `Actualizando estadísticas…` y `Buscando…` sin bloquear la navegación.
- Los resultados anteriores permanecen visibles hasta que existe una instantánea completa y coherente del nuevo estado.

### Pruebas
- Añadidas regresiones para equivalencia entre instantáneas optimizadas y cálculos directos, reutilización del índice de búsqueda y un chat sintético de 35.000 mensajes.
- Añadidas comprobaciones estáticas de caché, segundo plano, cancelación, espera de búsqueda y ausencia de recálculos pesados en las vistas.
- 101 pruebas Swift y 18 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` completados correctamente.

### Versión
- ZEUVE elevada a 0.5.3, build interno 16.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.3.

## 0.5.2 — 2026-07-03

### Corregido
- `Analizar otro chat` cierra la sesión temporal, limpia las fuentes y vuelve inmediatamente a la pantalla inicial del Analizador.
- `Cerrar análisis` cierra la sesión temporal, conserva las fuentes seleccionadas y vuelve inmediatamente a la pantalla inicial.
- La vista raíz del Analizador observa directamente su `ChatAnalyzerViewModel`, por lo que ya no es necesario cambiar de módulo para que aparezca la pantalla inicial.

### Añadido
- Ayuda contextual general en las nueve pestañas de resultados: Resumen, Actividad, Participantes, Palabras y emojis, Búsqueda, Conversaciones, Tiempos de respuesta, Comparación y Fusiones.
- Explicaciones específicas en tarjetas de métricas, gráficos, opciones, resúmenes y columnas de tablas no evidentes.
- Nuevos componentes reutilizables para títulos de sección, tarjetas, gráficos, grupos, filas y cabeceras con `info.circle`.
- Cuatro pruebas de regresión para la navegación, la diferencia entre cerrar y analizar otro chat, la cobertura de ayuda contextual y las nuevas reglas permanentes.

### Reglas del proyecto
- Incorporadas reglas generales sobre coherencia entre modos, regreso al estado inicial, selección automática, archivos grandes, estados no comprobables, uso temporal de archivos reales, ayuda en resultados e inspección eficiente de comprimidos.
- Actualizadas las decisiones aprobadas del Analizador con el comportamiento de los dos botones y la ayuda contextual de resultados.

### Versión
- ZEUVE elevada a 0.5.2, build interno 15.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.2.

## 0.5.1 — 2026-07-03

### Corregido
- Los ZIP de WhatsApp ya no rechazan `_chat.txt` por superar los 256 KB usados únicamente como muestra de detección.
- La detección lee un prefijo real y la importación de WhatsApp procesa el TXT progresivamente, sin cargarlo completo en memoria.
- Al importar solo un TXT, los adjuntos citados se muestran como no comprobados en lugar de clasificarse erróneamente como faltantes.
- Los archivos WEBP cuyo nombre contiene el marcador de sticker de WhatsApp se contabilizan como stickers, sin cambiar la clasificación de los WEBP normales.
- El cuadro de importación, el diálogo de macOS y los formatos permitidos cambian ahora entre WhatsApp, Instagram y Ambas plataformas.
- Se aceptan ZIP de Instagram que contienen directamente una sola conversación, además de las exportaciones completas de Meta.
- Las rutas multimedia de esos ZIP individuales se adaptan a la estructura realmente incluida para no marcar como ausentes adjuntos presentes.
- Cuando una exportación de Instagram contiene un único chat, queda seleccionado automáticamente.

### Ajustes
- Añadido un límite opcional para cada archivo de conversación en `Ajustes > Analizador de chats`.
- El valor predeterminado es **sin límite**. Si el usuario activa un máximo, el archivo que lo supere se rechaza completo y nunca se analiza parcialmente.

### Seguridad y privacidad
- Se mantienen los límites estructurales del ZIP, la validación de rutas, cifrado, enlaces y relaciones de compresión; el nuevo ajuste no desactiva estas protecciones.
- Los archivos originales continúan abriéndose solo para lectura y no se incorporan conversaciones reales a las pruebas permanentes ni a la entrega.

### Pruebas
- 97 pruebas Swift superadas sin fallos, incluidas regresiones para TXT grandes, límite opcional, adjuntos no comprobados, stickers y ZIP individual de Instagram.
- 11 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` completados correctamente.
- Los dos ZIP reales aportados se utilizaron únicamente como prueba temporal de integración y sus huellas se conservaron sin cambios.

## 0.5.0 — 2026-07-03

### Añadido
- Nuevo módulo oficial `Analizador de chats` (`com.zeuve.chat-analyzer`) para WhatsApp e Instagram.
- Importación directa de ZIP, catálogo de conversaciones de Instagram y modo avanzado para TXT, HTML y carpetas descomprimidas.
- Modelo normalizado común, deduplicación conservadora y conversión horaria mediante zonas reales.
- Resumen, gráficos, filtros, perfiles, palabras, frases, emojis, búsqueda, conversaciones, respuestas, comparación y fusiones temporales.
- SQLite temporal, historial agregado privado, ayuda contextual y ajustes centralizados.
- Puente mínimo a `libarchive` del SDK/sistema para lectura progresiva y segura de ZIP.
- 22 pruebas sintéticas específicas del nuevo módulo.

### Seguridad y privacidad
- Procesamiento completamente local, sin permiso de red, APIs, WebKit, telemetría ni apertura de enlaces.
- Protección frente a traversal, rutas absolutas, enlaces simbólicos, cifrado, entradas duplicadas, ZIP malformados y límites desproporcionados.
- Adjuntos clasificados sin abrirse y temporales eliminados únicamente cuando existe un marcador verificable de propiedad.
- Historial y logs sin mensajes, participantes, búsquedas, nombres privados o rutas completas.

### Cambiado
- Versión de ZEUVE elevada a 0.5.0 y build interno 13.
- Ajustes añade la sección Analizador de chats.
- Inicio, navegación, atajos e historial global reconocen el tercer módulo oficial.
- Proyecto Xcode, scripts de validación, documentación y alcance actualizados.

### Pruebas
- 93 pruebas Swift superadas sin fallos.
- 11 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` completados correctamente.
- Interfaz analizada sintácticamente y proyecto Xcode regenerado.
## 0.4.0 — 2026-07-02

### Añadido
- Navegación centralizada de Ajustes con secciones General, Organizador de archivos y Descargador de YouTube.
- Valores predeterminados persistentes e independientes para nuevas operaciones de ambos módulos.
- Subsecciones Predeterminados, Presets y Diagnóstico dentro de los ajustes del Descargador.
- Restauración segura de valores predeterminados y opción para olvidar carpetas recientes del Organizador.
- Selector rápido de presets dentro del Descargador sin duplicar su gestión.
- Regla permanente que obliga a los módulos futuros a integrar su configuración en el apartado general Ajustes.

### Cambiado
- Eliminados los botones independientes Presets y Diagnóstico de la barra del Descargador.
- Las opciones de una operación ya no sobrescriben los valores predeterminados persistentes del Organizador.
- Presets, diagnóstico, preferencias recordadas y opciones avanzadas persistentes se administran desde Ajustes.
- Cambiar valores predeterminados no altera silenciosamente una operación ya preparada o en curso.
- Versión de ZEUVE elevada a 0.4.0 y build interno 12.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.4.0.

### Pruebas
- Validaciones estáticas de centralización, ausencia de ruedas o botones propios de ajustes y separación entre preferencias y operación actual.
- Compatibilidad del manifiesto y suite existente actualizadas para la versión 0.4.0.
- 71 pruebas Swift y 11 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release completada correctamente.

## 0.3.0 — 2026-07-02

### Añadido
- Selector de formato de vídeo también en el modo simple, con MP4 como valor predeterminado.
- Selector de calidad MP3 de 128, 192, 256 y 320 kbps, visible únicamente cuando se elige MP3.
- Componente reutilizable de ayuda contextual mediante iconos de información en Descargador, Organizador y Ajustes.
- Explicaciones accesibles en español para opciones técnicas, con recomendaciones cuando corresponde.
- Pruebas de valores predeterminados, argumentos de bitrate y migración de presets.

### Cambiado
- MP3 pasa a ser el formato de audio predeterminado y 320 kbps su calidad inicial.
- El nombre predeterminado de los archivos pasa de Título e ID a Título.
- El esquema de presets del Descargador pasa a la versión 2 manteniendo compatibilidad con presets anteriores.
- Versión de ZEUVE elevada a 0.3.0 y build interno 11.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.3.0.

## 0.2.4 — 2026-07-02

### Rendimiento del Descargador de YouTube
- El diagnóstico de yt-dlp, Deno, FFmpeg y FFprobe se conserva durante la sesión y solo se repite si cambian los archivos o el usuario solicita una comprobación manual.
- yt-dlp utiliza una caché local privada en `~/Library/Caches/ZEUVE/yt-dlp`; no se sincroniza ni se envía a terceros.
- El ejecutable autónomo se sustituye por la distribución oficial descomprimida `yt-dlp_macos.zip` 2026.06.09 para reducir el coste de arranque de cada proceso.
- Se registran localmente los tiempos de resolución de motores, análisis, descarga/posprocesado, validación y publicación.
- Se mantiene una única descarga principal cada vez y la validación final con FFprobe.

### Proyecto
- Versión de ZEUVE elevada a 0.2.4 y build interno 10.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.4.
- Scripts, pruebas y documentación actualizados para el nuevo empaquetado de yt-dlp.

## 0.2.3 — 2026-07-02

### Corregido
- `yt-dlp` conserva ahora la firma original del ejecutable oficial dentro de `ZEUVE.app`; ya no se vuelve a firmar con Hardened Runtime.
- Deno, FFmpeg y FFprobe continúan firmándose explícitamente con la identidad de ZEUVE.
- Añadida una verificación del paquete que comprueba las cuatro firmas y ejecuta `yt-dlp --version`; la compilación se detiene si el ejecutable incluido no arranca.
- El diagnóstico de motores conserva ahora el código de salida, la señal de terminación, `stdout` y `stderr` cuando un motor falla.
- La ventana de diagnóstico permite desplegar y copiar los detalles técnicos sin sustituir el mensaje comprensible para el usuario.

### Modificado
- Versión de ZEUVE elevada a 0.2.3 y build interno 9.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.3; la API y la compatibilidad mínima no cambian.
- `Scripts/build_macos.sh` repite la verificación sobre la aplicación final después de `xcodebuild`.
- Proyecto Xcode, validaciones, decisiones y documentación actualizados.

### Pruebas
- 62 pruebas Swift superadas sin fallos.
- 11 pruebas Python superadas sin fallos, incluidas 3 pruebas nuevas de la política de firma.
- Compilación SwiftPM Debug comprobada durante las pruebas.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` superados en el entorno disponible.
- La compilación y apertura real de `ZEUVE.app` quedan pendientes de un Mac Apple Silicon con Xcode.

## 0.2.2 — 2026-07-02

### Corregido
- Eliminada la comparación en tiempo de ejecución del tamaño y la huella SHA-256 de yt-dlp, Deno, FFmpeg y FFprobe.
- Evitado que la firma de macOS haga que los cuatro motores se marquen erróneamente como no disponibles.
- El diagnóstico sigue comprobando existencia, licencia, permiso de ejecución, arquitectura, dependencias dinámicas, lanzamiento y versión.

### Seguridad y empaquetado
- SHA-256 y tamaño continúan verificándose durante la preparación y antes de firmar mediante `verify_engines_macos.sh`.
- No se han añadido dependencias, servicios, APIs, telemetría ni descargas automáticas.

### Modificado
- Versión de ZEUVE elevada a 0.2.2 y build interno 8.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.2; la API y la compatibilidad mínima no cambian.
- Proyecto Xcode, validaciones y documentación actualizados.

### Pruebas
- La prueba de diagnóstico confirma que un cambio de tamaño o SHA-256 no produce `hashMismatch` en ejecución.
- Las comprobaciones finales se documentan en `Docs/TEST_RESULTS_0.2.2.md`.

## 0.2.1 — 2026-07-01

### Corregido
- Corregida la preparación de Opus, LAME y FFmpeg con el SDK de macOS y Clang seleccionados mediante `xcrun`.
- Corregido `Scripts/static_pkg_config.py` para responder a `--version`, `--atleast-pkgconfig-version`, `--variable`, requisitos de versión agrupados, flags de compilación y flags de enlace estáticos.
- Evitado que opciones como `--variable=includedir` se interpreten erróneamente como nombres de paquetes.
- Generado de forma explícita `libmp3lame.pc`, ya que LAME 3.100 no lo instala.
- Eliminada la ruta temporal fija ligada a la versión 0.2.0.
- Eliminados del proyecto entregado los motores parciales producidos por intentos de preparación fallidos.

### Seguridad y robustez
- La preparación se realiza en un directorio temporal del sistema sin depender del nombre de la carpeta del proyecto.
- Los motores se construyen y verifican en una zona provisional antes de sustituir `Resources/Engines`.
- Si la publicación o la verificación final fallan, se restauran los motores anteriores.
- Las descargas de desarrollo siguen fijadas por versión y SHA-256; no se añade Homebrew, una API, telemetría ni descarga automática durante el uso normal.

### Modificado
- Versión de ZEUVE elevada a 0.2.1 y build interno 7.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.1; su compatibilidad mínima permanece en ZEUVE 0.2.0 porque la API del módulo no ha cambiado.
- Proyecto Xcode, generador, ajustes, validaciones y documentación actualizados.
- `verify_engines_macos.sh` admite verificar una carpeta provisional antes de la publicación definitiva.

### Pruebas
- 60 pruebas Swift superadas sin fallos.
- 8 pruebas nuevas del `pkg-config` local superadas sin fallos.
- Compilación SwiftPM Release superada.
- Sintaxis de scripts shell y Python validada.
- Proyecto Xcode regenerado con versión 0.2.1 y build 7.
- `Scripts/verify_project.sh` superado en el entorno disponible.
- La compilación real de FFmpeg/FFprobe ARM64, la compilación con Xcode y la apertura de `ZEUVE.app` quedan pendientes de ejecución en un Mac Apple Silicon.

## 0.2.0 — 2026-07-01

### Añadido
- Módulo oficial `com.zeuve.youtube-downloader` integrado en navegación, dashboard y comandos.
- Entrada de una o varias URLs, pegado, arrastrar texto, validación, canonicalización y eliminación de duplicados.
- Análisis cancelable de vídeos y playlists mediante salida JSON de yt-dlp.
- Modos simple y avanzado con selección de resolución, contenedor, streams exactos, HDR/SDR, audio y subtítulos.
- Procesamiento secuencial de múltiples URLs y elementos de playlist dentro de una única operación global.
- Selección individual y por intervalo de playlists, carga incremental y lista virtualizada.
- Progreso real de descarga y postprocesado, resumen acumulado y continuación segura tras fallos aislados.
- Temporales por operación, validación con FFprobe, publicación segura y renombrado automático por defecto.
- Historial, presets versionados, favoritos, bookmarks de seguridad y diagnóstico en español.
- JSON informativo y de playlist generado por ZEUVE sin URLs, firmas, cookies, tokens, cabeceras ni credenciales.
- Target compartido `ZEUVEEngines` para manifiestos, SHA-256, arquitectura, diagnóstico y ejecución segura.
- Target C `CZEUVEProcess` para iniciar procesos con `posix_spawn` en grupos independientes.
- Terminación de grupos con SIGTERM, espera limitada, SIGKILL como último recurso y comprobación de descendientes.
- Historial global dirigido por datos y por `moduleID`, probado con un tercer módulo simulado.
- Scripts reproducibles para preparar yt-dlp 2026.06.09, Deno 2.9.0 y FFmpeg/FFprobe 8.1.2 ARM64.
- Verificación mediante `otool -L`, firma explícita de ejecutables anidados y registro `engines.json`.

### Modificado
- Versión de ZEUVE elevada a 0.2.0 y build interno 6.
- Proyecto Xcode, generador, scripts de compilación, verificación y empaquetado actualizados.
- Dashboard, navegación, ajustes e historial preparados para más de un módulo.
- El manifiesto del Organizador declara `openExternalApplications`, sin cambios en su lógica ni interfaz.
- Documentación de arquitectura, compilación, seguridad, pruebas, módulos y alcance funcional actualizada.

### Seguridad y privacidad
- No se utiliza shell, Python del sistema, Homebrew, argumentos libres, `--remote-components` ni actualización automática.
- Deno y FFmpeg se pasan a yt-dlp mediante rutas explícitas.
- Cookies y credenciales de proxy no se almacenan ni se muestran en argumentos redactados.
- Los JSON nativos de yt-dlp quedan desactivados; ZEUVE genera archivos sanitizados.
- Las rutas de motores, licencias, temporales y resultados se validan contra traversal y escapes por enlaces simbólicos.

### Pruebas realizadas en esta entrega
- 60 pruebas automáticas superadas sin fallos en el entorno disponible.
- Las 30 pruebas anteriores se mantienen y siguen superándose.
- Compilación Debug de los paquetes Swift comprobada durante `swift test`.
- Cancelación de padre e hijo verificada con un ejecutable auxiliar real.
- Pruebas de 5.000 elementos de playlist, lectura incremental y memoria acotada.
- Proyecto Xcode regenerado con versión 0.2.0 y build 6.
- La preparación de binarios ARM64, la compilación Xcode y la apertura de `ZEUVE.app` siguen pendientes de ejecución en un Mac Apple Silicon.

## 0.1.4 — 2026-07-01

### Añadido
- Guía humana completa en español para desarrollar e integrar módulos oficiales.
- Instrucciones obligatorias en inglés para otros chats de desarrollo.
- Checklist de implementación y entrega de módulos.
- Plantilla para definir los requisitos de cada módulo antes de encargarlo.
- Documento de patrones y ejemplos basado en el Organizador, Swift, motores externos y procesos aislados.
- Ejemplos JSON validados de manifiesto, petición y eventos del protocolo.
- Especificación ampliada de la API de módulos 1.0.
- Script `Scripts/validate_module_docs.py` para validar la documentación y los ejemplos JSON.
- Script `Scripts/package_release.py` para generar entregas completas y limpias.

### Mejorado
- Actualizados README, arquitectura, compilación, pruebas, seguridad, alcance funcional y decisiones del proyecto.
- Diferenciados claramente los módulos oficiales incorporados de los futuros módulos externos importables.
- Actualizado `Scripts/verify_project.sh` al patrón real de inicialización de `AppModel` basado en `initialState`.
- Añadidas comprobaciones de regresión para las llamadas a `LocalLogger`, la configuración SQLite, los manifiestos y la documentación modular.

### Corregido
- Eliminadas cinco advertencias `Result of 'try?' is unused` al descartar explícitamente el valor devuelto por `LocalLogger.write`.
- Eliminadas las sugerencias de instalar `pkg-config` o SQLite mediante Homebrew. `CSQLite` enlaza directamente la biblioteca `sqlite3` del SDK/sistema mediante `module.modulemap`.
- Eliminados `.DS_Store`, `__MACOSX`, datos locales de Xcode, cachés y compilaciones de la entrega.

### Pruebas
- 30 pruebas automáticas superadas sin fallos.
- Compilaciones Debug y Release de los paquetes Swift comprobadas.
- Fuentes SwiftUI/AppKit analizadas sintácticamente.
- Documentación y ejemplos JSON validados automáticamente.
- Proyecto Xcode regenerado con versión 0.1.4 y build 5.
- La compilación y apertura final de `ZEUVE.app` con Xcode en macOS deben confirmarse en un Mac Apple Silicon.

## 0.1.3 — 2026-07-01

### Corregido
- Reorganizado el inicializador de `AppModel` para calcular primero el almacenamiento, el tema, el mensaje de error y el `OrganizerViewModel` mediante variables locales.
- `storage` y el resto de propiedades constantes se inicializan ahora una sola vez.
- El flujo de recuperación ya no consulta propiedades de `self` antes de que todas las propiedades almacenadas estén inicializadas.
- `OperationCoordinator` y `ModuleRegistry` se crean localmente y se asignan junto con el resto del estado, evitando accesos prematuros a `self`.
- No cambia el comportamiento visible, la arquitectura, SQLite, las dependencias ni la gestión de archivos.

### Pruebas
- Revisados todos los inicializadores de `Sources/ZEUVEApp`; no se ha detectado el mismo patrón en `OrganizerViewModel` ni en `OrganizerCompletion`.
- Añadida una comprobación de regresión sobre la estructura segura del inicializador de `AppModel`.
- Suite automática y compilaciones Debug/Release de los paquetes Swift ejecutadas de nuevo.
- La compilación y apertura de la interfaz con Xcode en macOS siguen pendientes de confirmación por el usuario.

## 0.1.2 — 2026-07-01

### Corregido
- Añadida la importación explícita de `ZEUVECore` en `DashboardView.swift` para que `ModuleManifest` esté disponible en ese archivo.
- Añadida la importación explícita de `ZEUVECore` en `RootView.swift` para que `OperationSnapshot` esté disponible en ese archivo.
- No cambia el comportamiento visible, la arquitectura, la gestión de archivos ni las dependencias.

### Pruebas
- Añadida una comprobación de regresión al script de validación para verificar ambas importaciones.
- Suite automática y compilaciones Debug/Release de los paquetes Swift ejecutadas de nuevo.
- La compilación y apertura de la interfaz con Xcode en macOS siguen pendientes de confirmación por el usuario.

## 0.1.1 — 2026-07-01

### Corregido
- Compatibilidad de compilación con Swift 6 y Foundation de macOS: `OrganizerPlanner` y `OrganizerExecutor` ya no declaran una conformidad `Sendable` incompatible con su propiedad `FileManager`.
- Se mantiene la ejecución de planificación y organización en tareas separadas; no cambia el comportamiento visible, la gestión de archivos ni la API pública de sus operaciones.

### Pruebas
- Suite automática completa ejecutada de nuevo.
- Compilaciones Debug y Release de los paquetes Swift verificadas de nuevo.
- La compilación y apertura de la interfaz con Xcode en macOS siguen pendientes de comprobación por el usuario.

## 0.1.0 — 2026-07-01

### Añadido
- Nuevo proyecto nativo para macOS Apple Silicon escrito en Swift 6.
- Interfaz SwiftUI con integraciones AppKit.
- Arquitectura modular basada en manifiestos y API de módulos 1.0.
- Contratos preparados para futuros módulos aislados desarrollados con distintas tecnologías.
- Coordinador global de operaciones.
- Persistencia SQLite local para ajustes e historial.
- Registros técnicos locales en JSONL, sin telemetría ni servicios externos.
- Módulo Organizador de archivos.
- Modos de organización simple y detallado.
- Agrupación de archivos relacionados por nombre.
- Análisis opcional de subcarpetas.
- Protección de archivos ocultos, temporales, enlaces simbólicos y paquetes de macOS.
- Vista previa seleccionable antes de ejecutar, con búsqueda y selección por categoría o formato.
- Renombrado seguro u omisión ante conflictos.
- Cancelación con reversión de movimientos completados, comprobada también tras iniciar el lote.
- Historial y deshacer inmediato o posterior con comprobación de huellas.
- Exportación del plan a CSV.
- Carpetas recientes y tema claro, oscuro o del sistema.
- Proyecto Xcode y esquema compartido.
- Pruebas automáticas, scripts y documentación.

### Limitaciones conocidas
- La interfaz no ha sido compilada ni abierta en este entorno porque no dispone de macOS ni Xcode.
- App Sandbox, firma, notarización e icono definitivo están pendientes.
- La importación de módulos externos todavía no está disponible.
