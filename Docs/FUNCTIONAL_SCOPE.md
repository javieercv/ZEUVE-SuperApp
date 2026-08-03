# Alcance funcional de ZEUVE 0.7.5

## Ajustes

- Navegación central entre General, Organizador de archivos, Descargador de YouTube, Analizador de chats y Conversor universal.
- Apariencia, privacidad, registros, versión y estado técnico general.
- Valores predeterminados del Organizador separados de las opciones de la operación actual.
- Valores predeterminados, presets y diagnóstico del Descargador en subsecciones propias.
- Restauración segura de ajustes por módulo.
- Sin ruedas ni ventanas independientes de configuración dentro de las herramientas.

## Organizador

- Selección y arrastre de carpetas.
- Modos simple y detallado.
- Subcarpetas opcionales.
- Agrupación por mismo nombre.
- Reglas de extensiones y reglas personalizadas en el núcleo.
- Ocultos opcionales.
- Vista previa, búsqueda y selección.
- Conflictos seguros.
- Exportación CSV.
- Ejecución, progreso, cancelación, historial y deshacer.

## Descargador de YouTube

### Incluido

- Vídeos, enlaces cortos, playlists y múltiples URLs.
- Validación, canonicalización y duplicados.
- Análisis previo cancelable.
- Título, canal, miniatura, duración, fecha, disponibilidad y estado de directo.
- Formatos de vídeo y audio, resolución, FPS, codecs, bitrate, HDR, contenedor e idioma cuando yt-dlp los ofrece.
- Subtítulos manuales y automáticos diferenciados.
- Modos simple y avanzado; el modo simple permite elegir resolución y formato de vídeo.
- Mejor calidad, límites de resolución y streams exactos.
- Audio original, M4A, MP3, FLAC, WAV y Opus; MP3 permite 128, 192, 256 y 320 kbps.
- Unión, remux o conversión mediante FFmpeg.
- Playlist completa, selección individual e intervalos.
- Playlists grandes con lectura incremental y lista virtualizada.
- Metadatos, miniaturas, descripción, capítulos y JSON sanitario opcional.
- Carpeta de salida, bookmarks, nombres seguros y conflictos.
- Progreso real, cancelación de grupos y resumen acumulado.
- Temporales, FFprobe y publicación segura.
- Historial, presets, favoritos, diagnóstico centralizado y ayuda contextual en opciones técnicas.
- `cookies.txt` manual y proxy opcional.

### No incluido en 0.4.0

- Descarga de directos activos o programados.
- Lectura directa de cookies de navegadores.
- DRM o elusión de restricciones.
- Argumentos libres de yt-dlp.
- Descargas pesadas simultáneas.
- Actualización automática de motores.
- Importación de módulos por el usuario.

## Analizador de chats

### Incluido

- ZIP o TXT de WhatsApp, detección por muestra real, lectura progresiva y selección entre varios TXT válidos.
- ZIP completo de Instagram o ZIP con una conversación directa, catálogo por categorías, buscador y selección automática cuando solo existe un chat.
- HTML o carpeta descomprimida en modo avanzado.
- Fechas españolas, inglesas y numéricas; cuatro estrategias horarias.
- Adjuntos referenciados, faltantes, no vinculados o no comprobados sin abrir su contenido; stickers de WhatsApp diferenciados de imágenes WEBP normales.
- Modelo común, orden estable y deduplicación conservadora.
- Resumen, actividad, gráficos, mapa de calor, participantes y perfiles.
- Tooltips interactivos por hover en líneas, barras, comparaciones y mapa de calor, con valor exacto, fecha o categoría, total cuando corresponde y posicionamiento dinámico junto al cursor sin recortes en los bordes.
- Palabras, bigramas, stopwords, emojis simples y compuestos.
- Búsqueda avanzada, contexto, resúmenes y paginación.
- Conversaciones temporales, turnos y tiempos de respuesta.
- Comparación de dos participantes y fusiones temporales.
- Ayuda contextual general en las nueve pestañas y ayuda específica en métricas, gráficos, opciones y columnas no evidentes.
- Regreso inmediato a la pantalla inicial: cerrar conserva las fuentes y analizar otro chat las limpia.
- Instantáneas analíticas en caché, cálculo diferido por pestaña, procesamiento en segundo plano, cancelación de resultados obsoletos y búsqueda con espera de 200 ms.
- Filtros globales, incluido intervalo horario que atraviesa medianoche.
- Progreso, cancelación, SQLite temporal, limpieza, historial privado y ajustes centralizados, incluido un límite opcional por archivo desactivado por defecto.

### No incluido en 0.7.0

- Exportar informes, CSV, PDF o HTML.
- Guardar o reabrir análisis.
- Analizar varias conversaciones de Instagram a la vez.
- Telegram, Signal, Discord, Messenger o iMessage.
- Acceso a cuentas, IA, sentimiento, OCR, transcripción o visualización de adjuntos.
- Internet, APIs o descarga de recursos.

## Próximos módulos previstos

- Importación de módulos externos; el Conversor universal ya está integrado como módulo oficial.
- Resolutor de enlaces.
- Sistema de módulos importables y firmados.

## Conversor universal

- Tres accesos principales: un archivo, varios archivos y ZIP; se conservan carpetas y arrastrar y soltar.
- Detección por contenido, estructura, UTI, MIME y motores, con discrepancias visibles.
- Lotes con distintos formatos de una misma categoría y matriz central que oculta conversiones no ejecutables.
- Imágenes rasterizadas y vectoriales, animaciones, audio, vídeo, PDF, texto, marcado, datos y ebooks según motores disponibles.
- FFmpeg/FFprobe, ImageIO, PDFKit, Pandoc, Calibre y Ghostscript mediante rutas locales seguras.
- Secuencias y animaciones, vídeo a audio, audio a vídeo y extracción de fotogramas con las limitaciones documentadas en `UNIVERSAL_CONVERTER.md`.
- ZIP conservado o aplanado, límites configurables, contraseña temporal, inspección progresiva y empaquetado opcional de resultados.
- Vista previa con nombres y colisiones resueltos, espacio estimado, motor y advertencias.
- Preajustes oficiales, favoritas, políticas de metadatos, bookmarks, patrones de nombres, progreso individual, cancelación e historial.
- Validación específica antes de publicar y protección frente a todas las rutas originales del lote.

### Fuera de alcance o pendiente de validación

- Fuentes y modelos 3D.
- Formatos ofimáticos: Word, Excel, PowerPoint, OpenDocument y RTF.
- PDF a documento editable con fidelidad garantizada u OCR.
- Validación nativa final en macOS Apple Silicon y preparación física de los motores opcionales.

## Rendimiento 0.7.4

La versión 0.7.4 mantiene el alcance funcional de 0.7.3 y optimiza búsqueda, almacenamiento temporal, diagnósticos, progreso, historial y cálculos de interfaz sin añadir formatos, motores, dependencias ni conexiones nuevas.


## Conversión multimedia 0.7.5

- Convertir un vídeo en modo simple siempre recodifica la pista de vídeo; una salida MP4 automática utiliza H.264 y no se presenta como conversión una mera copia de pistas.
- La copia rápida/remux permanece disponible únicamente en modo avanzado, se muestra de forma explícita y está desactivada de manera predeterminada.
- Vídeo → fotogramas escribe directamente en una carpeta visible `Procesando` dentro de la ubicación elegida. Al completar, la carpeta adopta el nombre definitivo sin copiar todo el árbol.
- Si la operación se cancela o falla, se conservan los fotogramas válidos y el CSV parcial en una carpeta `Incompleto`. Las operaciones abandonadas por un cierre inesperado se recuperan de la misma forma cuando ZEUVE vuelve a iniciarse.
- PNG sigue siendo sin pérdida; utiliza compresión nivel 3 y predictor Up para reducir tiempo sin alterar los píxeles.
- `tiempos.csv` se obtiene de la misma ejecución de FFmpeg y el progreso muestra el número real de fotogramas creados.
