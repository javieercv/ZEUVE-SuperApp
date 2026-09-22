extension ZEUVEHelpTopics {
    // MARK: - Vistas generales

    static let multimediaInspectorOverview = ContextualHelpTopic(
        "Inspector multimedia",
        explanation: "Analiza localmente la estructura, pistas, metadatos y audio de un archivo. El archivo se abre siempre en solo lectura; la edición solo comienza al pulsar Editar y trabaja sobre un borrador hasta generar y validar un archivo nuevo.",
        recommendation: "Empieza por Resumen para revisar el archivo y usa Pistas, Espectrograma o Metadatos cuando necesites más detalle."
    )
    static let multimediaSummaryTab = ContextualHelpTopic(
        "Resumen",
        explanation: "Reúne la información principal del contenedor, vídeo, audio, subtítulos, sonoridad y sincronización. El detalle técnico procede de FFprobe y puede ser parcial si el formato no declara todos los campos.",
        recommendation: "Usa esta vista para una primera comprobación y despliega Detalle técnico solo cuando necesites valores específicos."
    )
    static let multimediaTracksTab = ContextualHelpTopic(
        "Pistas",
        explanation: "Muestra las pistas de vídeo, audio y subtítulos. En modo inspección puedes escuchar y analizar audio; en modo edición puedes gestionar las pistas permitidas sin recodificar vídeo ni audio.",
        recommendation: "Comprueba idioma, título y flags antes de publicar una edición."
    )
    static let multimediaSpectrogramTab = ContextualHelpTopic(
        "Espectrograma",
        explanation: "Representa la energía del audio por tiempo y frecuencia. Comparte la misma ventana temporal con la waveform y la sonoridad temporal, y puede superponer silencios y posibles clippings ya calculados.",
        recommendation: "Ajusta FFT, ventana, canal y rango dinámico según el tipo de detalle que quieras observar."
    )
    static let multimediaMetadataTab = ContextualHelpTopic(
        "Metadatos",
        explanation: "Muestra los tags que FFprobe encuentra en el contenedor y sus streams. En modo edición solo se habilita un conjunto de campos multimedia conocido y compatible; los tags desconocidos se conservan como solo lectura.",
        recommendation: "No borres un valor si quieres conservarlo en el archivo resultante."
    )
    static let multimediaBatchMode = ContextualHelpTopic(
        "Análisis por lotes",
        explanation: "Procesa varios archivos de forma estrictamente secuencial. Puede combinar inspección, análisis de señal, sonoridad, espectrograma e informes. Con varias pistas de audio no elige una pista automáticamente.",
        recommendation: "Usa un preset y revisa la carpeta de salida antes de iniciar un lote que genere archivos."
    )

    // MARK: - Ajustes generales

    static let multimediaInitialTab = ContextualHelpTopic(
        "Pestaña inicial",
        explanation: "Elige qué vista se abre primero al iniciar una nueva inspección. No cambia el contenido del análisis ni el archivo.",
        recommendation: "Resumen es la opción más cómoda para una revisión general."
    )
    static let multimediaTechnicalDetail = ContextualHelpTopic(
        "Detalle técnico",
        explanation: "Controla cuánto detalle técnico muestra el Inspector por defecto. Los datos proceden de FFprobe y un nivel mayor puede hacer la interfaz más densa, pero no ejecuta análisis adicionales.",
        recommendation: "Usa el nivel normal para el día a día y amplía el detalle cuando necesites diagnóstico técnico."
    )
    static let multimediaPreserveMetadata = ContextualHelpTopic(
        "Preservar metadatos",
        explanation: "Conserva los tags no editados del contenedor y los streams durante una edición compatible. Los capítulos siguen su propio borrador y no dependen de esta opción.",
        recommendation: "Déjalo activado salvo que quieras generar deliberadamente un resultado con menos metadatos."
    )
    static let multimediaAutomaticSpectrogram = ContextualHelpTopic(
        "Espectrograma automático",
        explanation: "Genera el espectrograma al abrir un archivo cuando FFprobe detecta exactamente una pista de audio. Con varias pistas no se selecciona ninguna silenciosamente.",
        recommendation: "Actívalo si sueles inspeccionar audio de una sola pista y quieres tener el gráfico listo al abrir."
    )
    static let multimediaAutomaticSignal = ContextualHelpTopic(
        "Análisis de señal automático",
        explanation: "Busca silencios y posible clipping automáticamente cuando existe exactamente una pista de audio. Recorre el audio a resolución PCM y puede tardar en archivos largos.",
        recommendation: "Actívalo si quieres detectar estos eventos en cada archivo mono-pista sin pulsar Analizar señal."
    )
    static let multimediaAutomaticLoudness = ContextualHelpTopic(
        "Sonoridad automática",
        explanation: "Calcula Integrated LUFS, LRA, True Peak, Sample Peak y la evolución temporal EBU R128 cuando existe exactamente una pista de audio.",
        recommendation: "Actívalo si trabajas habitualmente con niveles y sonoridad; desactívalo si priorizas una apertura más rápida."
    )
    static let multimediaPreviewVolume = ContextualHelpTopic(
        "Volumen inicial",
        explanation: "Define el volumen con el que comienza la previsualización de audio en una nueva sesión. Solo afecta a la escucha dentro de ZEUVE y nunca modifica el archivo.",
        recommendation: "Un nivel medio evita sobresaltos al comparar archivos con niveles muy distintos."
    )
    static let multimediaPreviewSkip = ContextualHelpTopic(
        "Salto rápido",
        explanation: "Define cuántos segundos avanza o retrocede el reproductor cuando usas los controles de salto rápido.",
        recommendation: "10 segundos suele ser un buen equilibrio para inspección general."
    )
    static let multimediaTrackSwitchPosition = ContextualHelpTopic(
        "Conservar posición al cambiar de pista",
        explanation: "Al cambiar de pista de audio, intenta continuar en el mismo instante temporal en lugar de empezar desde el principio. Si la nueva pista es más corta, la posición se limita a su duración.",
        recommendation: "Déjalo activado para comparar pistas en el mismo pasaje."
    )
    static let multimediaTrackSwitchPlayback = ContextualHelpTopic(
        "Conservar Play/Pausa al cambiar de pista",
        explanation: "Mantiene el estado de reproducción al sustituir una pista: si estaba reproduciendo continúa; si estaba pausada permanece pausada. Puede existir una breve pausa mientras cambia la fuente.",
        recommendation: "Déjalo activado para una comparación A/B más fluida."
    )
    static let multimediaTimelineZoom = ContextualHelpTopic(
        "Paso de zoom temporal",
        explanation: "Define cuánto reduce o amplía la ventana temporal en cada acción de zoom. Waveform, espectrograma y sonoridad temporal comparten este mismo viewport.",
        recommendation: "Un paso intermedio facilita acercamientos progresivos sin perder contexto."
    )
    static let multimediaTimelinePan = ContextualHelpTopic(
        "Paso de desplazamiento temporal",
        explanation: "Indica qué fracción de la ventana visible se desplaza al navegar a izquierda o derecha cuando hay zoom.",
        recommendation: "Valores alrededor del 50 % permiten avanzar sin perder completamente la zona anterior."
    )
    static let multimediaWaveformStyle = ContextualHelpTopic(
        "Estilo de waveform",
        explanation: "Cambia la forma visual de representar la envolvente de audio. No modifica las muestras, el análisis ni el archivo.",
        recommendation: "Elige el estilo que te resulte más legible; no hay diferencia de calidad."
    )
    static let multimediaWaveformRepresentation = ContextualHelpTopic(
        "Representación de waveform",
        explanation: "Determina cómo se resume la amplitud del audio dentro de cada intervalo visual. Las representaciones pueden enfatizar picos o el nivel medio de forma distinta.",
        recommendation: "Usa la representación de picos cuando quieras localizar transitorios y la más suavizada para una lectura general."
    )
    static let multimediaWaveformCenterGuide = ContextualHelpTopic(
        "Guía central de waveform",
        explanation: "Muestra una referencia visual en el centro vertical de la forma de onda. Es solo una ayuda gráfica y no afecta al audio.",
        recommendation: nil
    )
    static let multimediaChapterMarkers = ContextualHelpTopic(
        "Marcadores de capítulos",
        explanation: "Superpone en la waveform los inicios de los capítulos del contenedor o del borrador de edición. En ZEUVE los capítulos editables se modelan como marcadores de inicio; su final se deriva del siguiente capítulo.",
        recommendation: "Actívalos para navegar y comprobar visualmente la estructura de capítulos."
    )
    static let multimediaSignalOverlays = ContextualHelpTopic(
        "Overlays de señal",
        explanation: "Muestra sobre waveform o espectrograma los silencios y eventos de posible clipping que ya haya calculado el análisis de señal. Activarlos o desactivarlos no vuelve a analizar el audio.",
        recommendation: "Úsalos cuando quieras localizar visualmente los eventos detectados."
    )

    // MARK: - Análisis de señal

    static let multimediaSignalAnalysis = ContextualHelpTopic(
        "Análisis de señal",
        explanation: "Recorre la pista completa en PCM para detectar intervalos de silencio y grupos de muestras muy próximas al límite digital. Los resultados son orientativos y dependen de los umbrales configurados.",
        recommendation: "Combina estos resultados con la escucha y la sonoridad antes de sacar conclusiones."
    )
    static let multimediaSilenceThreshold = ContextualHelpTopic(
        "Umbral de silencio",
        explanation: "Nivel en dBFS por debajo del cual una ventana puede considerarse silenciosa. ZEUVE exige que todos los canales estén por debajo del umbral para evitar falsos silencios por cancelación entre canales.",
        recommendation: "−60 dBFS es un punto de partida conservador para muchos archivos."
    )
    static let multimediaSilenceDuration = ContextualHelpTopic(
        "Duración mínima de silencio",
        explanation: "Tiempo mínimo continuo que debe permanecer el audio bajo el umbral para registrar un segmento de silencio. Un valor menor detecta pausas muy cortas y genera más eventos.",
        recommendation: "0,5 s evita que micro-pausas normales se conviertan en demasiados marcadores."
    )
    static let multimediaClippingThreshold = ContextualHelpTopic(
        "Umbral de posible clipping",
        explanation: "Nivel cercano a 0 dBFS a partir del cual una muestra puede participar en un evento de posible clipping. Estar cerca del límite no demuestra por sí solo que exista distorsión.",
        recommendation: "Mantén un criterio conservador cercano a 0 dBFS y confirma los casos relevantes escuchando el audio."
    )
    static let multimediaClippingSamples = ContextualHelpTopic(
        "Muestras consecutivas para posible clipping",
        explanation: "Número mínimo de muestras consecutivas por encima del umbral necesario para crear un evento. Exigir más muestras reduce falsos positivos por picos aislados.",
        recommendation: "3 muestras es un valor conservador para la detección inicial."
    )

    // MARK: - Espectrograma

    static let multimediaSpectrogramOverview = ContextualHelpTopic(
        "Análisis espectral",
        explanation: "FFmpeg decodifica localmente la pista seleccionada a PCM y ZEUVE calcula el espectrograma por bloques. El gráfico muestra tiempo en horizontal, frecuencia en vertical e intensidad en dB mediante color.",
        recommendation: "Usa FFT, ventana, canal y rango dinámico para adaptar la lectura al material."
    )
    static let multimediaSpectrogramTrack = ContextualHelpTopic(
        "Pista del espectrograma",
        explanation: "Selecciona qué stream de audio se analiza. Cambiar esta selección no cambia automáticamente la pista A/B que estés escuchando.",
        recommendation: "Comprueba el índice, idioma y códec antes de generar un análisis costoso."
    )
    static let multimediaSpectrogramChannel = ContextualHelpTopic(
        "Canal del espectrograma",
        explanation: "Mezcla combina los canales para visualización; un canal individual permite inspeccionar una posición concreta del layout. La selección solo afecta al espectrograma, no al archivo.",
        recommendation: "Empieza con Mezcla y pasa a un canal concreto cuando investigues diferencias entre canales."
    )
    static let multimediaFFTSize = ContextualHelpTopic(
        "Tamaño FFT",
        explanation: "La FFT divide el audio en frecuencias. Un tamaño mayor distingue mejor frecuencias cercanas, pero reduce la precisión temporal; un tamaño menor muestra mejor cambios rápidos, con menos detalle frecuencial.",
        recommendation: "4096 es un punto de partida equilibrado para la mayoría de archivos."
    )
    static let multimediaWindow = ContextualHelpTopic(
        "Ventana espectral",
        explanation: "La función de ventana reduce la fuga espectral en los bordes de cada bloque de audio. Hann es una opción general equilibrada; Hamming y Blackman–Harris cambian el compromiso entre anchura del pico y rechazo de lóbulos laterales.",
        recommendation: "Mantén Hann salvo que necesites comparar el comportamiento de otra ventana."
    )
    static let multimediaDynamicRange = ContextualHelpTopic(
        "Rango dinámico del espectrograma",
        explanation: "Define los niveles en dB que se representan. Un mínimo más bajo muestra componentes más débiles y también más ruido; elevar el máximo permite representar valores por encima de 0 dB cuando el mapeo lo requiera sin modificar el audio.",
        recommendation: "−120…0 dB conserva bastante detalle para la mayoría de análisis."
    )
    static let multimediaFrequencyScale = ContextualHelpTopic(
        "Escala de frecuencia",
        explanation: "La escala lineal dedica la misma altura a cada intervalo de Hz. La logarítmica amplía visualmente las frecuencias bajas. El límite superior es Nyquist: la mitad del sample rate real de la pista.",
        recommendation: "Usa lineal para medidas técnicas y logarítmica para una lectura más cercana a la percepción musical."
    )
    static let multimediaNyquist = ContextualHelpTopic(
        "Frecuencia de Nyquist",
        explanation: "Es la mitad del sample rate de la pista y representa la frecuencia máxima que puede describirse sin aliasing en ese muestreo. No significa que exista contenido útil hasta ese límite.",
        recommendation: nil
    )
    static let multimediaSpectrogramColumns = ContextualHelpTopic(
        "Columnas máximas del espectrograma",
        explanation: "Limita la resolución temporal retenida en memoria para archivos largos. Más columnas preservan más detalle pero consumen más memoria y pueden aumentar el tiempo de renderizado.",
        recommendation: "Mantén el valor predeterminado salvo que necesites más detalle temporal en archivos largos."
    )
    static let multimediaSpectrogramExportSize = ContextualHelpTopic(
        "Tamaño de exportación PNG",
        explanation: "Define el ancho y alto en píxeles del PNG exportado. Una imagen mayor puede mostrar más detalle visual, pero ocupa más memoria y disco durante la exportación.",
        recommendation: "Usa el tamaño predeterminado para informes y aumenta la resolución solo si vas a ampliar o imprimir."
    )

    // MARK: - Sonoridad y sincronización

    static let multimediaLoudness = ContextualHelpTopic(
        "Sonoridad EBU R128",
        explanation: "ZEUVE usa el filtro EBU R128 de FFmpeg para medir sonoridad percibida y picos. Estos valores describen nivel; no corrigen ni normalizan el audio.",
        recommendation: "Interpreta Integrated LUFS junto con LRA y True Peak, no como una cifra aislada."
    )
    static let multimediaIntegratedLUFS = ContextualHelpTopic(
        "Integrated LUFS",
        explanation: "Estimación de la sonoridad percibida media del programa completo según EBU R128, aplicando el gating del estándar. No es lo mismo que el pico máximo.",
        recommendation: "Úsalo para comparar el nivel global entre archivos o pistas."
    )
    static let multimediaLRA = ContextualHelpTopic(
        "Loudness Range (LRA)",
        explanation: "Expresa en LU la variación de sonoridad a medio/largo plazo. Un LRA mayor suele indicar más contraste entre partes suaves y fuertes, pero depende del contenido y del gating.",
        recommendation: "Compáralo entre materiales similares; no existe un valor ideal universal."
    )
    static let multimediaTruePeak = ContextualHelpTopic(
        "True Peak",
        explanation: "Estima el pico que podría aparecer al reconstruir la señal entre muestras, expresado en dBTP. Puede ser superior al Sample Peak y ayuda a detectar riesgo de sobrecarga en reproducción o codificación posterior.",
        recommendation: "Úsalo junto con la escucha y el análisis de posible clipping."
    )
    static let multimediaSamplePeak = ContextualHelpTopic(
        "Sample Peak",
        explanation: "Es el mayor valor de las muestras digitales observado, expresado en dBFS. No captura necesariamente picos entre muestras.",
        recommendation: "No lo confundas con True Peak; ambos describen aspectos distintos del nivel máximo."
    )
    static let multimediaShortTermStats = ContextualHelpTopic(
        "Short-term LUFS",
        explanation: "Resume la sonoridad de ventanas cortas a lo largo del tiempo. Mínimo, máximo y media ayudan a ver la evolución, pero no sustituyen el Integrated LUFS global.",
        recommendation: "Úsalo para localizar cambios de nivel y después revisa el mapa temporal."
    )
    static let multimediaLoudnessTimeline = ContextualHelpTopic(
        "Sonoridad temporal",
        explanation: "La curva muestra cómo evoluciona la sonoridad EBU R128 de la pista a lo largo del tiempo. ZEUVE usa Short-term LUFS como curva principal y conserva Momentary e Integrated para el detalle del cursor. El mapa se obtiene durante el mismo análisis de sonoridad global; no inicia una segunda decodificación.",
        recommendation: "Úsala para localizar cambios de nivel. Los LUFS temporales complementan, pero no sustituyen, el Integrated LUFS, LRA y True Peak del análisis completo."
    )
    static let multimediaAudioTiming = ContextualHelpTopic(
        "Sincronización declarada",
        explanation: "Compara timestamps de inicio y duraciones declaradas entre pistas. Un offset indica una diferencia temporal en el contenedor, pero no demuestra por sí solo que exista una desincronización audible.",
        recommendation: "Confirma cualquier diferencia importante escuchando el mismo pasaje en las pistas implicadas."
    )

    // MARK: - Edición estructural y metadatos

    static let multimediaStreamCopy = ContextualHelpTopic(
        "Copia exacta de pistas",
        explanation: "Inspector multimedia remultiplexa las pistas sin recodificar vídeo ni audio. Cambia la estructura del contenedor, no la señal audiovisual.",
        recommendation: "Si una combinación requiere cambiar el códec de vídeo o audio, utiliza el Conversor universal."
    )
    static let multimediaDefaultFlag = ContextualHelpTopic(
        "Pista predeterminada",
        explanation: "El flag Default indica qué pista debería preferir un reproductor al abrir el archivo. Es una indicación del contenedor y cada reproductor puede interpretarla de forma distinta.",
        recommendation: "Marca como predeterminada solo la pista que quieras proponer como opción principal."
    )
    static let multimediaForcedFlag = ContextualHelpTopic(
        "Subtítulo forzado",
        explanation: "El flag Forced identifica subtítulos pensados para aparecer aunque el usuario no active una pista completa, por ejemplo diálogos en otro idioma. No todos los reproductores lo respetan igual.",
        recommendation: "Úsalo únicamente cuando la pista haya sido preparada realmente como subtítulo forzado."
    )
    static let multimediaSubtitleConversion = ContextualHelpTopic(
        "Conversión auxiliar de subtítulos",
        explanation: "Algunos contenedores no pueden guardar ciertos subtítulos por copia directa. Inspector multimedia solo permite convertir la pista de subtítulos cuando es una adaptación segura y el usuario la autoriza expresamente; vídeo y audio permanecen sin recodificar.",
        recommendation: "Revisa la conversión propuesta: los formatos de texto con estilos pueden perder formato al pasar a un formato más simple."
    )
    static let multimediaAudioPreview = ContextualHelpTopic(
        "Previsualización de audio",
        explanation: "La reproducción sirve para escuchar una pista durante la inspección o antes de publicar un borrador. FFmpeg decodifica localmente a PCM y ZEUVE lo reproduce sin modificar ni exportar el archivo.",
        recommendation: "Úsala para comprobar que has elegido la pista correcta. La reproducción no crea historial ni convierte audio."
    )
    static let multimediaABComparison = ContextualHelpTopic(
        "Comparación A/B",
        explanation: "A/B permite alternar entre dos pistas usando el mismo reproductor. ZEUVE conserva el instante y el estado Play/Pausa al sustituir la fuente, sin cambiar la pista seleccionada para el espectrograma.",
        recommendation: "Selecciona dos pistas distintas y alterna A/B para compararlas en el mismo pasaje. Completa el análisis solo si necesitas comparar también sonoridad, silencios o posible clipping."
    )
    static let multimediaChapters = ContextualHelpTopic(
        "Capítulos",
        explanation: "ZEUVE trata cada capítulo editable como un marcador de inicio. El final se deriva del inicio del capítulo siguiente o de la duración del archivo. Los cambios permanecen en el borrador hasta generar una salida nueva.",
        recommendation: "Mantén los inicios ordenados y usa la reproducción para comprobar la posición antes de publicar."
    )
    static let multimediaAttachments = ContextualHelpTopic(
        "Attachments y attached_pic",
        explanation: "Los attachments reales del contenedor, habituales en MKV, pueden incluir fuentes u otros archivos y son editables cuando el contenedor lo permite. Las imágenes attached_pic son carátulas separadas de las pistas de vídeo normales: pueden extraerse y, en contenedores compatibles, añadirse, sustituirse o eliminarse mediante stream copy y validación posterior.",
        recommendation: "No elimines fuentes adjuntas si los subtítulos ASS dependen de ellas. Las carátulas solo se escriben cuando el contenedor y su códec permiten hacerlo sin convertir la imagen."
    )
    static let multimediaAttachmentMIME = ContextualHelpTopic(
        "MIME de un attachment",
        explanation: "Describe el tipo de contenido del archivo adjunto dentro del contenedor. Un MIME incorrecto puede dificultar que otros programas identifiquen el adjunto aunque sus bytes sean válidos.",
        recommendation: "Conserva el MIME original o usa el tipo correcto para el archivo añadido."
    )
    static let multimediaMetadata = ContextualHelpTopic(
        "Metadatos multimedia",
        explanation: "Son tags del contenedor o de cada stream, como título, artista, álbum o idioma. Su soporte varía por formato; ZEUVE solo permite editar un conjunto conocido y preserva los tags desconocidos como solo lectura cuando corresponde.",
        recommendation: "Usa valores simples y comprueba el resultado después de generar el archivo nuevo."
    )
    static let multimediaPartialInspection = ContextualHelpTopic(
        "Análisis parcial",
        explanation: "FFprobe pudo abrir el archivo, pero algunos campos no estaban disponibles, eran inválidos o no pudieron interpretarse con seguridad. ZEUVE conserva los datos fiables en lugar de inventar valores.",
        recommendation: "Revisa el detalle técnico si necesitas confirmar qué información falta antes de editar."
    )

    // MARK: - Informes, salida y lotes

    static let multimediaReportFormat = ContextualHelpTopic(
        "Formato de informe",
        explanation: "TXT y Markdown priorizan lectura humana; JSON conserva una estructura versionada adecuada para tratamiento automatizado. Exportar un informe no inicia análisis pesados que todavía no se hayan calculado.",
        recommendation: "Usa Markdown para lectura y JSON cuando vayas a reutilizar los datos con otra herramienta."
    )
    static let multimediaReportSections = ContextualHelpTopic(
        "Secciones del informe",
        explanation: "Permite elegir qué bloques se incluyen al exportar. Si una sección requiere un análisis que no se ha ejecutado, el informe no lo calcula por sorpresa y solo refleja los resultados disponibles.",
        recommendation: "Incluye solo lo que necesites para mantener informes claros."
    )
    static let multimediaOutputSuffix = ContextualHelpTopic(
        "Sufijo de salida",
        explanation: "Texto que ZEUVE añade al nombre al proponer un archivo editado. La política de conflictos sigue evitando sobrescrituras silenciosas.",
        recommendation: "Usa un sufijo reconocible como _editado para distinguir el resultado del original."
    )
    static let multimediaPreferredContainer = ContextualHelpTopic(
        "Contenedor preferido",
        explanation: "Automático intenta conservar el contenedor original. Si una edición estructural no cabe por stream copy, el planner puede proponer otro contenedor compatible; nunca recodifica vídeo o audio silenciosamente.",
        recommendation: "Mantén Automático salvo que necesites deliberadamente un contenedor concreto compatible con todas las pistas."
    )
    static let multimediaBatchPreset = ContextualHelpTopic(
        "Preset de lote",
        explanation: "Guarda qué análisis y exportaciones debe ejecutar un lote, pero nunca rutas, carpetas ni archivos del usuario. Los cambios temporales de un lote no alteran el preset guardado.",
        recommendation: "Crea presets distintos para inspección rápida, informes o análisis de audio completos."
    )
    static let multimediaBatchOperations = ContextualHelpTopic(
        "Operaciones del lote",
        explanation: "Cada opción añade una fase al procesamiento secuencial de cada archivo. Señal, sonoridad y espectrograma solo se ejecutan automáticamente cuando hay exactamente una pista de audio.",
        recommendation: "Desactiva análisis que no necesites para reducir el tiempo total del lote."
    )
    static let multimediaBatchOutputFolder = ContextualHelpTopic(
        "Carpeta de resultados del lote",
        explanation: "Solo se solicita cuando el lote genera informes o PNG. ZEUVE publica resultados con temporales seguros y resolución de conflictos; los originales permanecen protegidos.",
        recommendation: "Elige una carpeta con espacio suficiente y distinta de ubicaciones sensibles."
    )
    static let multimediaBatchStatuses = ContextualHelpTopic(
        "Estados del lote",
        explanation: "Completado indica éxito; Completado con aviso conserva un resultado válido con alguna fase omitida; Omitido significa que una operación no era aplicable; Fallido indica un error real; Cancelado identifica trabajo que no llegó a completarse.",
        recommendation: "Reintenta solo los fallidos después de revisar la causa; los avisos no implican necesariamente un problema."
    )

    // MARK: - Macro-bloque 0.7

    static let multimediaVideoPreview = ContextualHelpTopic(
        "Previsualización de vídeo",
        explanation: "FFmpeg decodifica vídeo localmente de forma incremental y ZEUVE conserva un buffer acotado. La resolución y los FPS de previsualización pueden limitarse sin modificar el archivo original.",
        recommendation: "Automático y 1080p/30 FPS suelen ser suficientes; aumenta los límites solo si la pantalla y el equipo lo justifican."
    )
    static let multimediaVideoDecoder = ContextualHelpTopic(
        "Decodificador de vídeo",
        explanation: "Automático intenta usar aceleración VideoToolbox cuando es apropiada y puede recurrir a software. Preferir hardware fuerza el intento de aceleración; Software evita ese intento.",
        recommendation: "Usa Automático salvo que estés diagnosticando un problema de compatibilidad."
    )
    static let multimediaBitmapSubtitles = ContextualHelpTopic(
        "Subtítulos bitmap y OCR",
        explanation: "PGS, VobSub/DVD y otros subtítulos bitmap no contienen texto directamente. ZEUVE puede extraer imágenes y usar Vision localmente para crear un borrador OCR revisable; nunca reemplaza la pista original automáticamente.",
        recommendation: "Revisa siempre el texto y el timing antes de exportar o añadir el SRT resultante."
    )
    static let multimediaAdvancedAudioAnalysis = ContextualHelpTopic(
        "Indicios de fuente con pérdida",
        explanation: "ZEUVE analiza distribución espectral, ancho de banda efectivo y su estabilidad para buscar indicios compatibles con compresión con pérdida previa. Ningún cutoff aislado demuestra que un archivo sin pérdida sea «falso».",
        recommendation: "Interpreta el nivel junto con las evidencias mostradas y el contexto de la grabación."
    )
    static let multimediaBatchFolders = ContextualHelpTopic(
        "Carpetas en lotes",
        explanation: "Enumera archivos de forma ligera antes de inspeccionarlos. ZEUVE no sigue enlaces simbólicos, puede limitar profundidad y ocultos, y deduplica entradas antes del preflight.",
        recommendation: "Limita la profundidad en árboles grandes y revisa el preflight antes de ejecutar edición estructural."
    )
    static let multimediaStructuralRules = ContextualHelpTopic(
        "Reglas estructurales por lotes",
        explanation: "Las reglas usan propiedades semánticas —tipo, códec, idioma, título y flags— en vez de números de pista. Cada archivo genera su propio plan y se clasifica antes de confirmar la ejecución.",
        recommendation: "Empieza con condiciones específicas y revisa todos los archivos marcados con advertencias."
    )

}
