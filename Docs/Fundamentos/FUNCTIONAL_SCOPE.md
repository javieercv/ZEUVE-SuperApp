# Alcance funcional de ZEUVE 0.20.2.0

## Optimización del Inspector multimedia 0.7.2

Se optimiza únicamente la latencia percibida del transporte existente: corte inmediato de salida al pausar, cancelación corta de FFmpeg de preview y eliminación de publicaciones redundantes durante pausa. No cambia ninguna función visible, formato soportado, opción, política de edición ni resultado.

## Corrección del Inspector multimedia 0.7.1

- Controles de audio/vídeo coherentes por identidad completa, pausa real, sustituciones protegidas y fullscreen sobre la ventana propietaria.
- Cancelación de edición conservadora para sesiones externas o mixtas.
- Rolloff, banda efectiva y caída persistente separados; cobertura y truncado visibles en UI e informes.

## Navegación y Limpiador 0.20.0.0

- Orden único personalizable para los módulos en Sidebar, Inicio y comandos; atajos configurables para módulos e Historial, con restauración independiente y dentro del reset global.
- Limpiador con Resumen, Aplicaciones, Residuos, Limpieza y Espacio.
- Inventario de apps, historial local, Spotlight/NSWorkspace verificados, identidad y firma nativa cuando están disponibles.
- Residuos con evidencia/confianza/estado/riesgo separados y decisión persistente `Conservar`.
- Cachés/logs, DerivedData regenerable, instaladores antiguos y LaunchItems rotos con guardas conservadoras.
- Análisis de desinstalación, app abierta, desinstalador oficial relacionado, Papelera/permanente, revalidación, resultados parciales y Undo.
- Fuera de V1: root/helper, receipts PKG avanzados, Homebrew cleaner, KEXT/System Extensions, duplicados, snapshots APFS, Keychain, daemon residente e IA de borrado.

## Inspector multimedia 0.7.0 — alcance actual

- Inspección FFprobe de contenedor, vídeo, audio, subtítulos, chapters, programs, data, attachments y carátulas.
- Preview local de vídeo/audio con play/pause, seek, stream seleccionado, velocidad, volumen, saltos, fullscreen, escalado y playhead compartido con waveform/espectrograma/análisis.
- Preview de subtítulos textuales sincronizados; estilos ASS/SSA avanzados quedan fuera. Bitmap se revisa mediante OCR local, no mediante sustitución automática.
- Edición estructural reversible de vídeo/audio/subtítulos, capítulos, attachments, carátulas y metadata compatible, siempre mediante remux/stream copy salvo conversiones auxiliares de subtítulos ya autorizadas.
- Extracción y gestión segura de `attached_pic`/attachments según compatibilidad real del contenedor.
- Espectrograma, waveform, EBU R128, señal, silencios, posible clipping, A/B, indicios explicables de fuente previamente lossy y anomalías espectrales localizables en la timeline.
- Batch de archivos o carpetas con enumeración ligera, filtros, reglas semánticas, preflight, confirmación y ejecución secuencial.
- OCR local revisable de subtítulos bitmap y exportación SRT explícita.
- Presets, conjuntos de reglas y favoritas de configuración sin rutas multimedia.
- Informes TXT/Markdown/JSON schema 3 sanitizados.

Quedan fuera: transcode audiovisual, cambio de resolución/FPS/bitrate/codec, montaje, recortes, transiciones, color grading, mezcla creativa/DAW, plugins externos, servicios OCR/cloud, reconocimiento facial/objetos y monitorización HDR de referencia.

## Ajustes

- Navegación central entre General y los módulos con preferencias visibles, incluido Inspector multimedia.
- Apariencia, privacidad, registros, versión y estado técnico general.
- Valores predeterminados del Organizador separados de las opciones de la operación actual.
- Valores predeterminados, presets y diagnóstico del Descargador en subsecciones propias.
- Restauración segura de ajustes por módulo.
- Restauración global confirmada desde General: devuelve a fábrica las preferencias persistentes de la aplicación y los módulos, mantiene historial, preajustes, favoritas, perfiles personalizados, carpetas recientes, motores y archivos, y elimina únicamente la sesión de Instagram y las carpetas de salida que se habían pedido recordar.
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

## Descargador universal

- Una o varias URLs HTTPS públicas; HTTP y red local solo mediante opción avanzada explícita.
- Vídeo, audio, fotos, carruseles, stories, highlights y galerías mediante el motor más adecuado para cada plataforma.
- Página web concreta con varios vídeos, sin rastrear subpáginas.
- Detección complementaria en `video`, `source`, `iframe`, Open Graph/Twitter, JSON-LD, HLS y DASH.
- Vista previa y selección antes de descargar.
- Deduplicación segura dentro del análisis actual antes de crear la cola.
- Posibles duplicados visibles y seleccionables.
- Elementos descargados anteriormente desmarcados inicialmente, sin impedir repetirlos.
- Enlaces directos y colecciones: vídeo o audio, formatos, resolución, subtítulos, metadatos, capítulos, miniaturas auxiliares y presets.
- Vídeos encontrados dentro de una página: descarga original sin recodificación, límite de resolución, formato forzado ni archivos auxiliares.
- Reutilización de la referencia multimedia ya resuelta durante el análisis, con respaldo automático mediante la URL estable si caduca o falla.
- TikTok usa gallery-dl como motor principal y reintenta con el yt-dlp incluido cuando el primer proceso falla o termina sin archivos; ningún intento vacío se presenta como descarga correcta.
- Aceleración HLS/DASH adaptativa desde 16 fragmentos y reducción segura a 8, 4 o 1.
- Publicación por movimiento atómico en el mismo volumen para evitar una segunda copia completa.
- Operaciones mixtas con política individual por elemento.
- Nombres limpios para vídeos de páginas; todos los títulos repetidos se numeran desde `(1)`.
- Procedencia opcional en metadatos, fecha opcional y atributo independiente «De dónde» de macOS, todo desactivado por defecto.
- Instagram acepta nombre de usuario, perfil o enlace concreto; muestra progresivamente publicaciones, reels, stories activas, stories individuales de highlights y la foto de perfil actual.
- Los enlaces concretos públicos de Instagram se analizan y descargan de forma anónima; no se leen ni se adjuntan cookies salvo que el elemento haya requerido autenticación confirmada.
- Los perfiles privados requieren una sesión ya autorizada: texto Cookie, cookies.txt o importación expresa desde navegador; la sesión es temporal por defecto y puede guardarse en el Llavero.
- Historial local opcional y búsqueda manual de fotos de perfil antiguas en Wayback Machine, sin garantía de resultados.
- Plataforma elegible junto al campo: Instagram admite perfiles; el resto de redes exige un enlace concreto.
- Contenido adulto bloqueado por defecto y activable desde Ajustes antes de analizar o mostrar miniaturas.
- Cookies Netscape manuales y proxy por operación.
- Descarga secuencial, progreso, cancelación, validación, publicación segura e historial mínimo.
- Logs locales desde el inicio del análisis.

### No incluido

- Rastreo de sitios o subpáginas.
- Desplazamiento infinito o interacción automática con la web.
- Chromium, Playwright o WebKit automatizado; el fallback opcional anterior está temporalmente deshabilitado y no existe una ruta ejecutable aprobada en 0.12.4.
- Lectura automática o silenciosa de cookies de navegador.
- Directos activos o programados.
- Evasión de DRM, pagos o controles de acceso.
- Garantía permanente de compatibilidad con cualquier página, DRM o controles de acceso.

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
- SQLite temporal como fuente principal, analíticas compactas por lotes, cálculo diferido por pestaña, procesamiento en segundo plano, cancelación de resultados obsoletos y búsqueda paginada con espera de 200 ms.
- Filtros globales, incluido intervalo horario que atraviesa medianoche.
- Progreso, cancelación cooperativa también dentro de la lectura ZIP, SQLite temporal, limpieza, historial privado y ajustes centralizados, incluido un límite opcional por archivo desactivado por defecto.

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
- Imágenes rasterizadas y vectoriales compatibles, animaciones, audio, vídeo, PDF, texto, marcado y datos según motores disponibles.
- FFmpeg/FFprobe, ImageIO, PDFKit y Pandoc mediante rutas locales seguras.
- EPUB, MOBI, AZW/AZW3, FB2 y EPS se reconocen para rechazarlos con un mensaje claro; no se convierten.
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

## Comparador de seguidores de Instagram

### Incluido

- Importación simple del ZIP completo generado por Meta.
- Importación avanzada de un `following.json` y uno o varios `followers_<número>.json`.
- Catálogo previo con nombre, ruta interna, tamaño y secuencia de cada JSON detectado.
- Carpeta raíz arbitraria dentro del ZIP y numeración no consecutiva.
- Lectura selectiva sin extraer el contenido completo.
- Compatibilidad con valores, URLs de perfil, títulos y estructura heredada aprobada.
- Normalización sin distinguir mayúsculas, deduplicación y conservación de puntos y guiones bajos.
- Tres categorías de comparación y contadores generales.
- Búsqueda parcial con espera breve, orden A–Z/Z–A y estados vacíos.
- Apertura manual de perfiles mediante la aplicación externa predeterminada.
- Exportación TXT o CSV de la categoría completa o de los resultados visibles.
- Historial global con datos agregados y sin listas privadas.
- Cancelación segura y descarte de resultados parciales.

### No incluido en 0.8.0

- Inicio de sesión en Instagram.
- Consulta en tiempo real, API, scraping o automatización de navegador.
- Seguimiento automático de cambios entre exportaciones.
- Almacenamiento permanente de listas, nombres de usuario o búsquedas.
- Ajustes persistentes propios.
- Importación de formatos HTML de seguidores.

## Inspector multimedia — 0.13.0

Incluye inspección técnica local de audio/vídeo mediante FFprobe compartido, edición estructural de pistas y espectrograma. Todo archivo empieza en solo lectura y requiere `Editar` para crear un borrador.

Edición/remux inicial: MKV, MP4, MOV y WebM. Audio y vídeo solo se copian; no existe recodificación automática. Se pueden añadir/eliminar/reordenar pistas de audio y subtítulos, editar idioma/título y flags default/forced. Las conversiones auxiliares de subtítulos requieren autorización explícita y no incluyen OCR.

El espectrograma admite pista/canal, mezcla, Hann/Hamming/Blackman–Harris, varios tamaños FFT, rango dinámico, escala lineal/logarítmica, zoom/pan, lectura de tiempo/frecuencia y PNG. No incluye detección de “FLAC falso”, batch, A/B ni informes automáticos.

Metadatos es una vista de lectura basada en tags de FFprobe; no incorpora un editor EXIF/IPTC/XMP ni nuevas herramientas externas.


## Mantenimiento del Inspector — 0.13.1.0

No se amplía el alcance funcional aprobado de 0.13.0. La versión corrige fidelidad y rendimiento del espectrograma: exportación coherente con la escala seleccionada, mezcla multicanal por potencia espectral, FFT reutilizable, memoria de columnas acotada y cancelación tratada como estado normal. No aparecen nuevos controles ni nuevas responsabilidades de edición.

## Rendimiento del Inspector — 0.13.2.0

No se añaden controles ni funciones de edición. La generación larga utiliza un presupuesto adaptativo de hasta ocho ventanas por columna, mientras los archivos cortos conservan el análisis denso. Rango dinámico, escala y zoom son ajustes de visualización y reutilizan el modelo. Pista, canal, FFT y ventana requieren un análisis distinto, que puede recuperarse de una caché temporal en memoria si el archivo no ha cambiado.


## Inspector multimedia — ampliación 0.14.0.0

Se añade previsualización local de audio de archivos independientes, streams contenidos en vídeo y audios externos del draft, con play/pause, seek, saltos y volumen. El espectrograma añade ejes, leyenda, crosshair y sincronización de playhead. Pistas añade drag & drop seguro y Resumen/Metadatos amplían lectura, búsqueda y copia técnica.

Sigue fuera de alcance: reproductor universal de vídeo, timeline, cortes, mezcla/efectos, edición de chapters/attachments, batch, detector de transcodificación y ajustes visibles del Inspector.

## Inspector multimedia — ampliación 0.15.0.0

- La sesión actual puede cerrarse o sustituirse por otro archivo sin abandonar el módulo. Los borradores sucios exigen confirmación antes de descartarse.
- El reproductor de audio usa una waveform bipolar como scrubber, conserva la posición al cambiar de pista y comparte el playhead con el espectrograma.
- Los capítulos válidos pueden usarse para navegar al tiempo correspondiente; siguen siendo de solo lectura.
- El análisis de sonoridad ofrece LUFS/LRA/True Peak/Sample Peak cuando FFmpeg puede obtenerlos. Se inicia automáticamente solo si FFprobe detecta exactamente una pista de audio; con varias pistas sigue siendo voluntario y por pista.
- Se muestran offsets de inicio y diferencias de duración como datos técnicos, sin diagnóstico automático de sincronía.
- Puede exportarse un informe técnico TXT, Markdown o JSON mediante acción explícita y publicación segura.
- Inspector dispone de preferencias centralizadas persistentes y restauración a valores predeterminados.
- Sigue fuera de alcance el reproductor universal de vídeo, la edición temporal, mezcla creativa, efectos, batch y edición general de metadatos/chapters/attachments.

## Inspector multimedia — corrección 0.15.1.0

La previsualización permite cambiar realmente entre pistas de audio conservando la posición temporal y la waveform realiza seek visual inmediato sin rebote a la posición previa. No se amplía el alcance funcional hacia edición temporal o vídeo.

### Sustitución atómica 0.15.2.0

Los cambios de pista completan el cierre de FFmpeg y AVAudioEngine antes de iniciar la nueva fuente. Cambios consecutivos conservan el instante y gana siempre la última pista solicitada; el comportamiento cubre pistas originales, externas, pausa y duraciones menores sin ampliar formatos ni funciones de edición.

## Inspector multimedia — corrección 0.15.3.0

- Pistas, Espectrograma y barra inferior controlan la misma sesión de audio y reflejan el mismo Play/Pausa.
- Cambiar de pista conserva posición temporal y estado Play/Pausa; una pista más corta limita el seek al último instante válido.
- Mover la waveform conserva Pausa cuando la sesión estaba pausada.
- El botón del Espectrograma reanuda la sesión actual en vez de reiniciar a `00:00`; hacer clic sobre el gráfico sigue significando reproducir desde el instante pulsado.
- El Espectrograma adapta verticalmente su gráfico para mantener visible el reproductor inferior sin añadir scroll global.
- No se amplía el alcance hacia vídeo, timeline, edición temporal, mezcla, efectos ni transcodificación audiovisual.

## Inspector multimedia — corrección 0.15.4.0

- El botón que inicia la reproducción en Pistas o Espectrograma puede pausar y reanudar esa misma sesión sin depender de cambiar de pestaña.
- Pistas y Espectrograma representan `Cargando…`, `Pausar` y `Escuchar` desde una única resolución de identidad/estado del ViewModel.
- Se mantiene sin cambios el audio reproducido, la posición, el cambio de pista, la waveform, la barra inferior y el layout adaptable de 0.15.3.0.
- No se amplía alcance funcional ni se añaden opciones, motores o dependencias.


## Inspector multimedia — corrección 0.15.5.0

- El botón `Escuchar/Pausar` de Pistas pausa y reanuda la fuente confirmada tanto si la reproducción empezó en esa fila como si empezó en la barra inferior o en Espectrograma.
- Una fuente pendiente solo se considera activa durante `Cargando…`; una solicitud transitoria no puede sustituir la identidad confirmada durante reproducción o pausa.
- Pistas y Espectrograma usan la misma decisión del ViewModel para iniciar, cambiar, pausar y reanudar.
- No cambia el alcance funcional, los tiempos compartidos, el cambio entre pistas, el layout ni la edición multimedia.


## Inspector multimedia — corrección 0.15.6.0

- Las filas de audio y subtítulos de solo lectura mantienen identidad estable durante toda la inspección.
- Las actualizaciones del playhead no regeneran los UUID de las filas, por lo que `Escuchar/Pausar` permanece interactivo mientras avanza la reproducción.
- Se conserva sin cambios el reproductor compartido, el tiempo común entre superficies, la continuidad Play/Pausa al cambiar de pista y el layout adaptable del Espectrograma.
- No se amplía el alcance funcional del módulo.


## Inspector multimedia — análisis automático mono-pista 0.15.7.0

- Al abrir un archivo, FFprobe realiza primero la inspección técnica y determina el número real de pistas de audio.
- Con **0 pistas**, ZEUVE no intenta generar espectrograma ni calcular sonoridad.
- Con **1 pista**, ZEUVE genera automáticamente el espectrograma y, cuando termina, calcula automáticamente la sonoridad de esa misma pista.
- Con **2 o más pistas**, ambos análisis continúan siendo manuales para que el usuario seleccione explícitamente qué pista analizar.
- Los controles manuales de regeneración/reanálisis permanecen disponibles también después de una ejecución automática.
- La automatización no cambia el reproductor, waveform, edición estructural, informes, exportación PNG ni selección de parámetros del espectrograma.


## Inspector multimedia — navegación temporal compartida 0.15.8.0

- Waveform y espectrograma comparten zoom, desplazamiento y **Vista completa** sobre un único intervalo temporal.
- El zoom puede centrarse en la posición actual del reproductor y el playhead permanece sincronizado en las dos representaciones.
- La waveform usa una envolvente de resolución superior acotada a 65.536 intervalos y reutiliza ese resultado para navegar sin volver a decodificar el archivo.
- Los capítulos válidos de la fuente original se muestran como marcadores informativos sobre la waveform, con título/tiempo cuando corresponde.
- No se añade edición de capítulos ni se cambia el comportamiento de reproducción, espectrograma, sonoridad o remux ya aprobado.
- Continúan fuera de alcance en esta versión la detección de silencios/clipping, el mapa temporal de sonoridad y la comparación A/B.

## Inspector multimedia — análisis de señal 0.15.9.0

Incluido: análisis manual por pista de silencios y **Posible clipping**, resumen por pista, parámetros centralizados, marcadores/intervalos sobre waveform y espectrograma, cancelación y automatización secuencial cuando existe exactamente una pista de audio. El análisis no modifica el archivo ni sustituye la sonoridad EBU R128.

Siguen fuera de este alcance el mapa temporal de LUFS/sonoridad, la comparación A/B y cualquier reparación o normalización automática del audio.

## Inspector multimedia — análisis avanzado 0.16.0.0

Incluido:

- evolución temporal EBU R128 con Short-term LUFS como curva principal y detalle Momentary/Integrated;
- mapa sincronizado con zoom/pan, playhead y seek del viewport temporal compartido;
- comparación A/B entre dos pistas de audio desde Pistas, conservando posición y estado Play/Pausa;
- comparación técnica de códec, bitrate, sample rate, canales/layout, duración, sonoridad y análisis de señal disponibles;
- acción explícita para completar únicamente los análisis A/B que falten, de forma secuencial;
- informes TXT/Markdown con resumen de señal/sonoridad temporal y JSON schema 2 con detalle estructurado disponible.

Fuera de este bloque: doble reproducción simultánea para A/B, normalización/gain matching, edición de capítulos, attachments, edición general de metadatos y trabajo por lotes. Exportar o seleccionar A/B no inicia por sí mismo análisis pesados.

## Inspector multimedia — alcance de edición estructural 0.17.0.0

- Capítulos: crear, eliminar, renombrar y cambiar el marcador de inicio; visualización inmediata en waveform y soporte Undo/Redo.
- Attachments reales: añadir, eliminar, renombrar, cambiar MIME y extraer mediante workspace y publicación segura. `attached_pic` permanece protegida y sin edición.
- Metadatos multimedia: edición de un conjunto seguro de tags globales y por stream; tags desconocidos siguen visibles y preservables, pero de solo lectura.
- El remux mantiene vídeo/audio en stream copy, valida el resultado con FFprobe y publica solo si coincide con el plan.
- No se incorpora edición general EXIF/IPTC/XMP ni recodificación multimedia.


## Inspector multimedia — lotes y personalización 0.18.0.0

Incluido:

- selección múltiple y drag & drop de varios archivos;
- cola de análisis secuencial con estados por elemento, cancelación, continuación tras fallos y reintento de fallidos;
- FFprobe para todos los elementos y, opcionalmente, análisis de señal, sonoridad, espectrograma PNG e informe TXT/Markdown/JSON;
- política 0/1/2+ pistas: sin audio no se analiza audio; con una pista puede ejecutarse lo solicitado; con varias pistas no se elige ninguna silenciosamente;
- presets de lote persistentes, versionados y administrados desde Ajustes;
- personalización centralizada de automatización mono-pista, reproductor, zoom/pan, waveform/overlays, análisis de señal, espectrograma/exportación, informes, edición/salida y preset predeterminado;
- salida con nombres previsibles, resolución segura de conflictos, protección de todos los originales y una única entrada agregada de historial por lote.

Fuera de 0.18.0.0: edición estructural masiva, exploración recursiva de carpetas, procesamiento paralelo de varios archivos, normalización automática, reparación de audio y recodificación audiovisual.

## Inspector multimedia — ayuda contextual 0.18.1.0

Incluido: ayuda general en las cinco superficies principales del Inspector y ayuda específica para opciones y resultados técnicos/ambiguos, incluida la configuración centralizada del módulo. La ayuda reutiliza la infraestructura común de ZEUVE y no ejecuta análisis. No se añaden funciones multimedia nuevas en esta corrección.
