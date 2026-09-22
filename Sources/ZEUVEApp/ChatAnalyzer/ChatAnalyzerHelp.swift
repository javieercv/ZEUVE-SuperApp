extension ZEUVEHelpTopics {
    static let chatTimeZone = ContextualHelpTopic(
        "Zona horaria de Instagram",
        explanation: "Las exportaciones de Meta pueden guardar la hora en California, UTC o ya convertida. ZEUVE utiliza zonas horarias reales y respeta los cambios de verano e invierno. Una conversión distinta puede cambiar el día asignado a un mensaje y los tiempos de respuesta.",
        recommendation: "California → España es el valor recomendado para la mayoría de exportaciones de Instagram."
    )
    static let chatNumericDates = ContextualHelpTopic(
        "Fechas numéricas ambiguas",
        explanation: "Una fecha como 07/02 puede significar 7 de febrero o 2 de julio. Esta opción define el orden utilizado cuando ambos números podrían ser un mes.",
        recommendation: "Día / mes / año es el formato habitual en España."
    )
    static let chatMultimedia = ContextualHelpTopic(
        "Definición de multimedia",
        explanation: "Determina qué tipos se incluyen en las estadísticas de multimedia. La opción clásica cuenta imágenes, vídeos, audios y stickers."
    )
    static let chatStopWords = ContextualHelpTopic(
        "Palabras vacías",
        explanation: "Son palabras muy frecuentes como «de», «la» o «y». Excluirlas facilita encontrar términos con más contenido, pero las frases siempre conservan la consecutividad real."
    )
    static let chatGranularity = ContextualHelpTopic(
        "Granularidad temporal",
        explanation: "Define si la evolución se agrupa por día, semana, mes o año. Solo cambia la presentación de los gráficos y no modifica los mensajes importados.",
        recommendation: "Mes ofrece una vista equilibrada para conversaciones largas."
    )
    static let chatConversationThreshold = ContextualHelpTopic(
        "Pausa entre conversaciones",
        explanation: "Una conversación es una agrupación temporal. Empieza otra cuando la pausa supera el umbral elegido. Si la pausa es exactamente igual, continúa en la misma conversación.",
        recommendation: "Tres horas suele separar bien bloques de conversación sin fragmentarlos demasiado."
    )
    static let chatResponseWindow = ContextualHelpTopic(
        "Ventana de respuesta",
        explanation: "Limita cuánto tiempo puede transcurrir entre el final del turno de una persona y el inicio del turno de otra para contarlo como respuesta. Es una estimación temporal, no demuestra una respuesta directa.",
        recommendation: "24 horas es un valor equilibrado para conversaciones cotidianas."
    )
    static let chatConversationFilters = ContextualHelpTopic(
        "Conversaciones y filtros",
        explanation: "Puede conservarse la agrupación creada sobre toda la cronología y filtrar después, o volver a agrupar únicamente los mensajes que pasan los filtros. La primera opción mantiene mejor el contexto original."
    )
    static let chatConversationFileLimit = ContextualHelpTopic(
        "Límite del archivo de conversación",
        explanation: "Permite rechazar archivos de conversación que superen el tamaño elegido. No recorta el chat ni produce estadísticas parciales. El límite se aplica al TXT de WhatsApp o a cada página HTML de Instagram, no al conjunto de fotos, vídeos y audios del ZIP.",
        recommendation: "Déjalo desactivado para analizar chats de cualquier tamaño que pueda procesar el Mac. Actívalo solo si quieres imponer un máximo personal."
    )
    static let chatArchiveLimits = ContextualHelpTopic(
        "Límites de ZIP",
        explanation: "Protegen el Mac frente a archivos dañados, ZIP bombs, demasiadas entradas y tamaños desproporcionados. Los archivos grandes legítimos reciben una advertencia; los límites absolutos se rechazan por seguridad."
    )
    static let chatSummaryOverview = ContextualHelpTopic(
        "Resumen del análisis",
        explanation: "Reúne las cifras principales del chat después de aplicar los filtros activos. Los totales importados pueden ser mayores que los mensajes incluidos si hay filtros."
    )
    static let chatIncludedMessages = ContextualHelpTopic(
        "Mensajes incluidos",
        explanation: "Número de mensajes que cumplen los filtros actuales. El detalle muestra el total importado antes de filtrar. Un mensaje con varias líneas cuenta como uno solo."
    )
    static let chatParticipantCount = ContextualHelpTopic(
        "Participantes",
        explanation: "Cuenta autores personales distintos presentes en los mensajes incluidos. Los avisos y eventos del sistema no se consideran participantes."
    )
    static let chatActiveDays = ContextualHelpTopic(
        "Días activos",
        explanation: "Número de fechas distintas con al menos un mensaje incluido. Un día cuenta una sola vez, independientemente de cuántos mensajes tenga."
    )
    static let chatPlatformMessages = ContextualHelpTopic(
        "Mensajes por plataforma",
        explanation: "Cantidad y porcentaje de mensajes incluidos procedentes de cada plataforma. La suma depende de las fuentes y filtros activos."
    )
    static let chatMostActiveTime = ContextualHelpTopic(
        "Hora y día más activos",
        explanation: "Hora del día y día de la semana con más mensajes incluidos. Si varias franjas empatan, se muestra una de las que alcanzan el máximo."
    )
    static let chatPeriod = ContextualHelpTopic(
        "Periodo",
        explanation: "Fechas del primer y último mensaje incluidos y día natural con mayor actividad dentro de los filtros actuales."
    )
    static let chatImportSummary = ContextualHelpTopic(
        "Resumen de importación",
        explanation: "Describe qué archivos se leyeron y qué referencias multimedia se encontraron durante la importación, antes de aplicar filtros estadísticos."
    )
    static let chatReferencedAttachments = ContextualHelpTopic(
        "Adjuntos referenciados",
        explanation: "Archivos multimedia mencionados o enlazados por los mensajes importados. No implica que ZEUVE haya abierto o decodificado su contenido."
    )
    static let chatUnverifiedAttachments = ContextualHelpTopic(
        "Adjuntos no comprobados",
        explanation: "Referencias a archivos que no pueden verificarse porque se proporcionó únicamente el TXT o HTML sin el ZIP o la carpeta multimedia correspondiente. No significa que falten."
    )
    static let chatMissingAttachments = ContextualHelpTopic(
        "Adjuntos faltantes",
        explanation: "Referencias cuyo archivo no se encontró dentro del ZIP o carpeta que sí debía contenerlo. Se diferencian de los adjuntos no comprobados."
    )
    static let chatActivityOverview = ContextualHelpTopic(
        "Actividad",
        explanation: "Muestra cómo se distribuyen los mensajes incluidos a lo largo del tiempo, por horas y por días de la semana. Todos los gráficos respetan los filtros activos."
    )
    static let chatTemporalEvolution = ContextualHelpTopic(
        "Evolución temporal",
        explanation: "Agrupa los mensajes por la granularidad elegida y dibuja el total y, cuando corresponde, cada plataforma. El eje horizontal representa fechas y el vertical mensajes."
    )
    static let chatHourlyActivity = ContextualHelpTopic(
        "Actividad por hora",
        explanation: "Cuenta los mensajes incluidos según la hora local asignada durante la importación, desde las 00:00 hasta las 23:59."
    )
    static let chatWeekdayActivity = ContextualHelpTopic(
        "Actividad por día de la semana",
        explanation: "Cuenta los mensajes incluidos por lunes, martes y resto de días, sin distinguir semanas concretas."
    )
    static let chatHeatmap = ContextualHelpTopic(
        "Mapa de calor",
        explanation: "Cruza los siete días de la semana con las 24 horas. Una celda más intensa representa más mensajes en esa combinación de día y hora."
    )
    static let chatParticipantOverview = ContextualHelpTopic(
        "Perfil del participante",
        explanation: "Resume la actividad de la persona seleccionada dentro de los filtros activos. Las fusiones de identidad se aplican antes de calcular estas cifras."
    )
    static let chatParticipantMessages = ContextualHelpTopic(
        "Mensajes del participante",
        explanation: "Número de mensajes personales atribuidos al participante y porcentaje que representan sobre todos los mensajes personales incluidos."
    )
    static let chatWordCount = ContextualHelpTopic(
        "Palabras",
        explanation: "Total de palabras detectadas en los mensajes de texto del participante. El detalle muestra la media por mensaje."
    )
    static let chatMedianWords = ContextualHelpTopic(
        "Mediana de palabras",
        explanation: "Valor central al ordenar los mensajes por número de palabras. Suele representar mejor el mensaje habitual cuando existen algunos mensajes muy largos."
    )
    static let chatAverageLength = ContextualHelpTopic(
        "Longitud media",
        explanation: "Promedio de caracteres por mensaje de texto, incluidos espacios y signos. Los mensajes sin texto aportan longitud cero cuando forman parte del cálculo."
    )
    static let chatEmojiCount = ContextualHelpTopic(
        "Emojis",
        explanation: "Número total de emojis detectados. Un mismo mensaje puede contener varios y todos se contabilizan."
    )
    static let chatQuestionCount = ContextualHelpTopic(
        "Preguntas",
        explanation: "Mensajes de texto que contienen al menos un signo de interrogación. El porcentaje se calcula sobre los mensajes del participante."
    )
    static let chatUsualActivity = ContextualHelpTopic(
        "Hora y día habituales",
        explanation: "Hora y día de la semana en los que el participante acumula más mensajes incluidos. No representa necesariamente una rutina estable."
    )
    static let chatFrequentContent = ContextualHelpTopic(
        "Contenido frecuente",
        explanation: "Términos, secuencias de dos palabras y emojis más repetidos en los mensajes del participante. Las palabras vacías dependen del ajuste vigente."
    )
    static let chatParticipantPeriod = ContextualHelpTopic(
        "Periodo del participante",
        explanation: "Primera y última aparición dentro de los filtros, ritmo por día activo, plataformas utilizadas, enlaces y mensajes escritos principalmente en mayúsculas."
    )
    static let chatMessagesPerActiveDay = ContextualHelpTopic(
        "Mensajes por día activo",
        explanation: "Media de mensajes del participante dividida entre los días distintos en los que escribió al menos uno. Los días sin actividad no se incluyen."
    )
    static let chatLinks = ContextualHelpTopic(
        "Enlaces",
        explanation: "Mensajes en los que se detectó al menos una dirección web. Se muestra cantidad y porcentaje sobre los mensajes del participante."
    )
    static let chatUppercase = ContextualHelpTopic(
        "Mensajes en mayúsculas",
        explanation: "Mensajes con suficiente texto alfabético escrito predominantemente en mayúsculas. Se excluyen textos demasiado cortos para evitar falsos positivos."
    )
    static let chatPlatformBreakdown = ContextualHelpTopic(
        "Desglose por plataforma",
        explanation: "Distribuye los mensajes del participante entre WhatsApp e Instagram según la fuente de importación."
    )
    static let chatContentTypes = ContextualHelpTopic(
        "Tipos de contenido",
        explanation: "Clasifica los mensajes como texto, imagen, vídeo, audio, sticker, documento, enlace, llamada, sistema u otros tipos reconocidos."
    )
    static let chatMonthlyEvolution = ContextualHelpTopic(
        "Evolución mensual",
        explanation: "Cuenta los mensajes del participante por mes natural dentro de los filtros activos."
    )
    static let chatLongestMessage = ContextualHelpTopic(
        "Mensaje más largo",
        explanation: "Mensaje de texto con más caracteres entre los incluidos para este participante. Solo se muestra una vista limitada para evitar ocupar toda la pantalla."
    )
    static let chatWordsOverview = ContextualHelpTopic(
        "Palabras y emojis",
        explanation: "Analiza frecuencias de palabras, parejas consecutivas, emojis y tipos de contenido sobre los mensajes incluidos por los filtros."
    )
    static let chatWordFrequency = ContextualHelpTopic(
        "Palabras frecuentes",
        explanation: "Lista las palabras con más apariciones. La normalización agrupa variantes de mayúsculas y puede excluir palabras vacías."
    )
    static let chatBigrams = ContextualHelpTopic(
        "Frases de dos palabras",
        explanation: "Cuenta parejas de palabras consecutivas dentro del mismo mensaje. No une el final de un mensaje con el inicio del siguiente."
    )
    static let chatEmojiFrequency = ContextualHelpTopic(
        "Emojis frecuentes",
        explanation: "Ordena los emojis por número total de apariciones. Un mensaje puede sumar varias apariciones del mismo emoji."
    )
    static let chatParticipantFrequency = ContextualHelpTopic(
        "Frecuencias por participante",
        explanation: "Muestra una selección de las palabras y emojis más frecuentes de cada participante dentro de los filtros activos."
    )
    static let chatSearchOverview = ContextualHelpTopic(
        "Búsqueda avanzada",
        explanation: "Busca dentro de los mensajes incluidos por los filtros. La consulta y los resultados no se guardan en el historial ni en los registros."
    )
    static let chatSearchMode = ContextualHelpTopic(
        "Modo de búsqueda",
        explanation: "Define cómo se interpreta la consulta: texto literal, todas las palabras, alguna palabra u otros modos disponibles."
    )
    static let chatIgnoreCase = ContextualHelpTopic(
        "Ignorar mayúsculas",
        explanation: "Considera equivalentes las letras mayúsculas y minúsculas durante la búsqueda."
    )
    static let chatWholeWords = ContextualHelpTopic(
        "Palabras completas",
        explanation: "Evita que una consulta coincida dentro de otra palabra más larga. Por ejemplo, «pan» no coincidirá con «pantalla»."
    )
    static let chatIgnoreDiacritics = ContextualHelpTopic(
        "Ignorar tildes",
        explanation: "Trata como equivalentes letras con y sin tilde o diacrítico, como «si» y «sí»."
    )
    static let chatSearchContext = ContextualHelpTopic(
        "Contexto",
        explanation: "Número de mensajes anteriores y posteriores que se muestran alrededor de cada coincidencia. No cambia el número de resultados."
    )
    static let chatSearchPageSize = ContextualHelpTopic(
        "Resultados por página",
        explanation: "Cantidad máxima de coincidencias mostradas en cada página. Solo afecta a la presentación."
    )
    static let chatSearchCounts = ContextualHelpTopic(
        "Mensajes y apariciones",
        explanation: "Mensajes indica cuántos mensajes contienen la consulta. Apariciones cuenta cuántas veces aparece en total, por lo que un mensaje puede sumar varias."
    )
    static let chatSearchParticipantCounts = ContextualHelpTopic(
        "Resultados por participante",
        explanation: "Número de mensajes coincidentes atribuidos a cada participante, no número total de repeticiones del término."
    )
    static let chatSearchPlatformCounts = ContextualHelpTopic(
        "Resultados por plataforma",
        explanation: "Número de mensajes coincidentes procedentes de WhatsApp o Instagram."
    )
    static let chatConversationsOverview = ContextualHelpTopic(
        "Conversaciones",
        explanation: "Agrupa mensajes por pausas temporales. Estas agrupaciones no detectan temas y pueden contener varios asuntos distintos."
    )
    static let chatConversationCount = ContextualHelpTopic(
        "Número de conversaciones",
        explanation: "Cantidad de grupos temporales obtenidos con el umbral de pausa y la estrategia de filtros seleccionados."
    )
    static let chatConversationDuration = ContextualHelpTopic(
        "Duración de conversación",
        explanation: "Tiempo entre el primer y el último mensaje de cada grupo temporal. La media y la mediana se calculan sobre todos los grupos incluidos."
    )
    static let chatConversationMessages = ContextualHelpTopic(
        "Mensajes por conversación",
        explanation: "Promedio de mensajes contenidos en cada grupo temporal."
    )
    static let chatUnansweredConversations = ContextualHelpTopic(
        "Conversaciones sin respuesta",
        explanation: "Grupos temporales en los que solo aparece un participante. No demuestra que la otra persona leyera o ignorara los mensajes."
    )
    static let chatUsualConversationStart = ContextualHelpTopic(
        "Inicio habitual",
        explanation: "Hora y día de la semana en los que comienza el mayor número de conversaciones temporales."
    )
    static let chatLargestConversation = ContextualHelpTopic(
        "Conversación con más mensajes",
        explanation: "Mayor cantidad de mensajes encontrada dentro de un único grupo temporal."
    )
    static let chatLongestConversation = ContextualHelpTopic(
        "Conversación de mayor duración",
        explanation: "Mayor intervalo entre primer y último mensaje dentro de un único grupo temporal."
    )
    static let chatInitiatedConversations = ContextualHelpTopic(
        "Conversaciones iniciadas",
        explanation: "Grupos temporales cuyo primer mensaje personal se atribuye al participante."
    )
    static let chatFinishedConversations = ContextualHelpTopic(
        "Conversaciones finalizadas",
        explanation: "Grupos temporales cuyo último mensaje personal se atribuye al participante."
    )
    static let chatConversationParticipantDuration = ContextualHelpTopic(
        "Duración media por iniciador",
        explanation: "Duración media de las conversaciones temporales iniciadas por ese participante."
    )
    static let chatConversationParticipantMessages = ContextualHelpTopic(
        "Mensajes medios por iniciador",
        explanation: "Promedio de mensajes de las conversaciones temporales iniciadas por ese participante."
    )
    static let chatTopConversationsByMessages = ContextualHelpTopic(
        "Conversaciones con más mensajes",
        explanation: "Lista los diez grupos temporales con mayor cantidad de mensajes, ordenados de mayor a menor."
    )
    static let chatTopConversationsByDuration = ContextualHelpTopic(
        "Conversaciones de mayor duración",
        explanation: "Lista los diez grupos temporales con mayor intervalo entre su primer y último mensaje."
    )
    static let chatResponsesOverview = ContextualHelpTopic(
        "Tiempos de respuesta",
        explanation: "Estima el tiempo entre el final del turno de una persona y el siguiente mensaje de otra. No identifica respuestas directas ni comprueba lecturas."
    )
    static let chatResponseCount = ContextualHelpTopic(
        "Respuestas estimadas",
        explanation: "Número de cambios de turno entre participantes que cumplen la ventana máxima configurada."
    )
    static let chatResponseAverage = ContextualHelpTopic(
        "Tiempo medio de respuesta",
        explanation: "Suma de los tiempos estimados dividida entre el número de respuestas. Puede verse afectada por algunos intervalos muy largos."
    )
    static let chatResponseMedian = ContextualHelpTopic(
        "Mediana de respuesta",
        explanation: "Tiempo central al ordenar todas las respuestas estimadas. Suele ser menos sensible que la media a intervalos excepcionalmente largos."
    )
    static let chatResponseExtremes = ContextualHelpTopic(
        "Respuesta más rápida y más lenta",
        explanation: "Menor y mayor intervalo estimado que cumplen la ventana configurada. Los extremos pueden no representar el comportamiento habitual."
    )
    static let chatResponsePercentiles = ContextualHelpTopic(
        "Percentiles de respuesta",
        explanation: "El percentil 25 deja por debajo al 25 % de respuestas y el percentil 75 al 75 %. Juntos describen la zona central de los tiempos."
    )
    static let chatResponseThresholdCounts = ContextualHelpTopic(
        "Respuestas bajo un umbral",
        explanation: "Cantidad de respuestas estimadas inferiores a 5 minutos, 1 hora o 24 horas. Las columnas son acumulativas."
    )
    static let chatResponseDistribution = ContextualHelpTopic(
        "Distribución de respuestas",
        explanation: "Agrupa los tiempos estimados en intervalos excluyentes, desde menos de un minuto hasta 24 horas o más."
    )
    static let chatComparisonOverview = ContextualHelpTopic(
        "Comparación",
        explanation: "Coloca lado a lado los indicadores de dos participantes usando los mismos filtros, ajustes de multimedia, conversaciones, respuestas y fusiones."
    )
    static let chatFusionsOverview = ContextualHelpTopic(
        "Fusión de identidades",
        explanation: "Permite tratar varios nombres como una misma persona durante este análisis. Recalcula estadísticas sin modificar los archivos originales."
    )
    static let chatFusionParticipants = ContextualHelpTopic(
        "Participantes que se fusionarán",
        explanation: "Selecciona dos o más nombres que pertenecen a la misma persona. La fusión solo existe en la sesión temporal."
    )
    static let chatFusionName = ContextualHelpTopic(
        "Nombre común",
        explanation: "Nombre que se mostrará para todas las identidades seleccionadas después de fusionarlas. Los nombres originales se conservan internamente."
    )
    static let chatActiveFusions = ContextualHelpTopic(
        "Fusiones activas",
        explanation: "Muestra cada nombre común y las identidades originales que agrupa en la sesión actual."
    )
    static let chatUndoFusions = ContextualHelpTopic(
        "Deshacer fusiones",
        explanation: "Deshacer restaura el estado anterior. Restablecer todas elimina todas las fusiones de la sesión y vuelve a calcular los resultados."
    )
}
