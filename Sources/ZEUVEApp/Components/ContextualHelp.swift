import SwiftUI

struct ContextualHelpTopic: Sendable {
    let title: String
    let explanation: String
    let recommendation: String?

    init(_ title: String, explanation: String, recommendation: String? = nil) {
        self.title = title
        self.explanation = explanation
        self.recommendation = recommendation
    }
}

struct ContextualHelpButton: View {
    let topic: ContextualHelpTopic
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Más información sobre \(topic.title)")
        .accessibilityLabel("Información sobre \(topic.title)")
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                Label(topic.title, systemImage: "info.circle.fill")
                    .font(.headline)
                Text(topic.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                if let recommendation = topic.recommendation {
                    Divider()
                    Label(recommendation, systemImage: "lightbulb")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(width: 340, alignment: .leading)
        }
    }
}

struct HelpLabel: View {
    let text: String
    let topic: ContextualHelpTopic

    init(_ text: String, topic: ContextualHelpTopic) {
        self.text = text
        self.topic = topic
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
            ContextualHelpButton(topic: topic)
        }
    }
}

enum ZEUVEHelpTopics {
    static let interfaceMode = ContextualHelpTopic(
        "Modo simple y avanzado",
        explanation: "El modo simple muestra las decisiones habituales. El modo avanzado añade selección exacta de flujos, metadatos, subtítulos y ajustes de red.",
        recommendation: "Utiliza el modo simple salvo que necesites controlar una pista o un comportamiento técnico concreto."
    )
    static let downloadContent = ContextualHelpTopic(
        "Tipo de contenido",
        explanation: "Vídeo descarga imagen y audio. Solo audio conserva o convierte únicamente la pista de sonido."
    )
    static let maximumResolution = ContextualHelpTopic(
        "Resolución máxima",
        explanation: "Limita la altura del vídeo. ZEUVE escogerá la mejor calidad disponible que no supere el valor elegido. Algunos vídeos no ofrecen todas las resoluciones.",
        recommendation: "Mejor disponible prioriza la calidad; 1080p suele ofrecer un buen equilibrio entre calidad y tamaño."
    )
    static let videoFormat = ContextualHelpTopic(
        "Formato del vídeo",
        explanation: "Es el contenedor del archivo final. MP4 ofrece la mayor compatibilidad. MKV admite más combinaciones de pistas. WebM utiliza formatos web. Automático deja que ZEUVE elija una opción compatible.",
        recommendation: "MP4 es la opción predeterminada y la más compatible con reproductores y dispositivos."
    )
    static let dynamicRange = ContextualHelpTopic(
        "Rango dinámico",
        explanation: "SDR es compatible con la mayoría de pantallas. HDR puede mostrar más brillo y color, pero necesita contenido, pantalla y reproductor compatibles.",
        recommendation: "Mantén Automático salvo que quieras evitar HDR o priorizarlo expresamente."
    )
    static let audioFormat = ContextualHelpTopic(
        "Formato de audio",
        explanation: "MP3 es ampliamente compatible. M4A suele conservar buena calidad con menor tamaño. FLAC y WAV pueden ocupar mucho más. Opus es eficiente, pero tiene menor compatibilidad. Flujo original evita una conversión adicional.",
        recommendation: "MP3 es el valor predeterminado por compatibilidad."
    )
    static let mp3Bitrate = ContextualHelpTopic(
        "Calidad MP3",
        explanation: "Los kbps indican la cantidad de datos utilizada por segundo. Un valor mayor suele producir mejor calidad y un archivo más grande. Convertir a 320 kbps no recupera información que no exista en el audio de origen.",
        recommendation: "320 kbps prioriza la calidad; 192 kbps reduce el tamaño manteniendo una calidad adecuada para la mayoría de usos."
    )
    static let exactVideoStream = ContextualHelpTopic(
        "Flujo de vídeo exacto",
        explanation: "Permite escoger una pista técnica concreta de las disponibles en YouTube, identificada por resolución, códec, FPS y formato. Puede requerir unirla con una pista de audio separada.",
        recommendation: "La selección automática es la opción adecuada en la mayoría de casos."
    )
    static let exactAudioStream = ContextualHelpTopic(
        "Flujo de audio exacto",
        explanation: "Permite seleccionar una pista de audio concreta en lugar de dejar que ZEUVE escoja automáticamente la mejor. Puede ser útil para elegir idioma, códec o bitrate cuando YouTube ofrece varias pistas.",
        recommendation: "Mantén Selección automática salvo que necesites una pista concreta."
    )
    static let embedMetadata = ContextualHelpTopic(
        "Metadatos",
        explanation: "Añade al archivo final información como título, autor y otros datos compatibles. La disponibilidad depende del formato de salida."
    )
    static let thumbnails = ContextualHelpTopic(
        "Miniaturas",
        explanation: "Incrustar guarda la imagen de portada dentro del archivo cuando el formato lo permite. Guardar por separado crea además un archivo de imagen junto al resultado."
    )
    static let chapters = ContextualHelpTopic(
        "Capítulos",
        explanation: "Conserva las marcas de capítulos publicadas en el vídeo para que los reproductores compatibles permitan saltar entre secciones."
    )
    static let descriptionAndJSON = ContextualHelpTopic(
        "Información adicional",
        explanation: "La descripción se guarda como texto. El JSON informativo de ZEUVE contiene información sanitizada de la operación y evita guardar URLs temporales, firmas o datos de sesión de yt-dlp."
    )
    static let publicationDate = ContextualHelpTopic(
        "Fecha de publicación",
        explanation: "Intenta usar la fecha de publicación del vídeo como fecha del archivo final. No todos los formatos o sistemas permiten conservarla exactamente."
    )
    static let subtitles = ContextualHelpTopic(
        "Subtítulos",
        explanation: "Los subtítulos manuales los aporta el canal. Los automáticos los genera YouTube y pueden contener errores. Incrustar los añade al archivo cuando el contenedor lo permite; SRT crea un formato de texto ampliamente compatible."
    )
    static let proxy = ContextualHelpTopic(
        "Proxy",
        explanation: "Hace que las conexiones de esta operación pasen por el servidor indicado. Las credenciales solo se mantienen durante la operación y no se guardan.",
        recommendation: "Déjalo desactivado salvo que necesites usar un proxy configurado por ti."
    )
    static let retries = ContextualHelpTopic(
        "Reintentos",
        explanation: "Número de veces que ZEUVE volverá a intentar una petición que falle temporalmente. Un valor alto puede alargar mucho una descarga cuando el enlace no está disponible."
    )
    static let concurrentFragments = ContextualHelpTopic(
        "Fragmentos simultáneos",
        explanation: "Algunos vídeos se descargan por partes. Este valor controla cuántas partes se solicitan a la vez. Aumentarlo puede acelerar la descarga, pero también incrementa el uso de red y puede provocar limitaciones.",
        recommendation: "El valor predeterminado 4 ofrece un equilibrio razonable."
    )
    static let cookies = ContextualHelpTopic(
        "Cookies",
        explanation: "Un archivo cookies.txt puede permitir acceder a contenido que requiere una sesión iniciada. Puede contener datos privados y debe proceder de una fuente de confianza. ZEUVE no lo copia ni lo incluye en presets o historial."
    )
    static let filename = ContextualHelpTopic(
        "Nombre del archivo",
        explanation: "Define qué datos se usan para generar el nombre. Título crea el nombre más limpio. Añadir ID, fecha, canal o índice puede evitar ambigüedades en lotes grandes.",
        recommendation: "Título es la opción predeterminada."
    )
    static let fileConflicts = ContextualHelpTopic(
        "Conflictos de nombre",
        explanation: "Determina qué ocurre si ya existe un archivo con el mismo nombre. Renombrar crea una copia numerada, Omitir conserva el existente y Reemplazar exige confirmación expresa.",
        recommendation: "Renombrar automáticamente es la opción más segura."
    )
    static let playlistFolder = ContextualHelpTopic(
        "Carpeta de lista",
        explanation: "Agrupa los resultados de una lista de reproducción dentro de una carpeta propia para mantenerlos separados de otras descargas."
    )
    static let playlistNumbering = ContextualHelpTopic(
        "Numeración de listas",
        explanation: "Añade el índice de la lista al principio del nombre para conservar el orden original al ordenar los archivos alfabéticamente."
    )

    static let organizationLevel = ContextualHelpTopic(
        "Nivel de organización",
        explanation: "El nivel simple agrupa por categorías generales. Los niveles más detallados crean una estructura con más subcarpetas según el tipo y formato de cada archivo."
    )
    static let relatedFiles = ContextualHelpTopic(
        "Archivos relacionados",
        explanation: "Mantiene juntos archivos que comparten el mismo nombre base, por ejemplo una imagen, un subtítulo y un vídeo asociados."
    )
    static let recursiveFolders = ContextualHelpTopic(
        "Incluir subcarpetas",
        explanation: "Analiza también el contenido de las carpetas situadas dentro de la carpeta elegida. Los enlaces simbólicos y paquetes de macOS no se recorren."
    )
    static let hiddenFiles = ContextualHelpTopic(
        "Archivos ocultos",
        explanation: "Incluye elementos cuyo nombre comienza por punto o que macOS marca como ocultos. Pueden ser archivos de configuración que normalmente no conviene mover.",
        recommendation: "Déjalo desactivado salvo que sepas que esos elementos también deben organizarse."
    )
    static let organizerConflict = ContextualHelpTopic(
        "Conflictos del organizador",
        explanation: "Indica cómo se resolverá un destino ocupado. La vista previa mostrará el nombre final antes de mover ningún archivo y nunca se sobrescribirá silenciosamente."
    )
    static let groupSelection = ContextualHelpTopic(
        "Selección por categoría y formato",
        explanation: "Permite incluir o excluir grupos completos de la vista previa sin revisar cada archivo individualmente. Solo se ejecutarán los movimientos que permanezcan seleccionados."
    )

    static let telemetry = ContextualHelpTopic(
        "Telemetría",
        explanation: "La aplicación no recopila estadísticas de uso, identificadores del dispositivo ni información sobre tus archivos."
    )
    static let automaticUpdates = ContextualHelpTopic(
        "Actualizaciones automáticas",
        explanation: "ZEUVE no consulta Internet para buscar ni instalar actualizaciones de forma automática."
    )
    static let localProcessing = ContextualHelpTopic(
        "Procesamiento local",
        explanation: "Las funciones que no necesitan Internet procesan los datos en el Mac. Los archivos no se envían a servicios externos."
    )
    static let networkUse = ContextualHelpTopic(
        "Uso de red",
        explanation: "La red solo se utiliza cuando una función lo necesita y el usuario inicia la acción, como analizar o descargar un enlace."
    )
    static let logs = ContextualHelpTopic(
        "Registros locales",
        explanation: "Los registros ayudan a diagnosticar errores y se guardan únicamente en el Mac. Pueden contener nombres y rutas de archivos, pero no se envían automáticamente."
    )
    static let moduleAPI = ContextualHelpTopic(
        "API de módulos",
        explanation: "Es la versión del contrato interno que utilizan los módulos oficiales para integrarse con el núcleo de ZEUVE. No es una conexión a un servicio de Internet."
    )
    static let appSandbox = ContextualHelpTopic(
        "App Sandbox",
        explanation: "Es una protección de macOS que limita el acceso de una aplicación a archivos y procesos. Permanece pendiente porque debe comprobarse que no impida ejecutar los motores incluidos ni acceder a carpetas elegidas por el usuario."
    )
    static let centralizedSettings = ContextualHelpTopic(
        "Ajustes centralizados",
        explanation: "Los valores permanentes de ZEUVE y de cada módulo se administran desde el apartado Ajustes. Las herramientas conservan únicamente las decisiones necesarias para la operación actual."
    )
    static let moduleDefaults = ContextualHelpTopic(
        "Valores predeterminados del módulo",
        explanation: "Son los valores con los que comenzarán las operaciones nuevas. Cambiarlos no modifica una operación que ya esté preparada o en curso."
    )
    static let quickPreset = ContextualHelpTopic(
        "Aplicar preset",
        explanation: "Carga de una vez una configuración guardada en la operación actual. La creación, edición y eliminación de presets se realiza en Ajustes > Descargador de YouTube.",
        recommendation: "Utiliza un preset cuando repitas con frecuencia la misma combinación de formato, calidad y opciones."
    )
    static let recentFolders = ContextualHelpTopic(
        "Carpetas recientes",
        explanation: "ZEUVE guarda localmente una lista corta de las últimas carpetas elegidas para facilitar su reutilización. Olvidarlas no elimina ni modifica ningún archivo."
    )

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

struct HelpPickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    let topic: ContextualHelpTopic
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        topic: ContextualHelpTopic,
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.topic = topic
        _selection = selection
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            HelpLabel(title, topic: topic)
            Spacer(minLength: 12)
            Picker("", selection: $selection, content: content)
                .labelsHidden()
                .frame(maxWidth: 360)
        }
    }
}

struct HelpToggleRow: View {
    let title: String
    let topic: ContextualHelpTopic
    @Binding var isOn: Bool

    init(_ title: String, topic: ContextualHelpTopic, isOn: Binding<Bool>) {
        self.title = title
        self.topic = topic
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 6) {
            Toggle(title, isOn: $isOn)
            ContextualHelpButton(topic: topic)
        }
    }
}

struct HelpStepperRow: View {
    let title: String
    let topic: ContextualHelpTopic
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(_ title: String, topic: ContextualHelpTopic, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.title = title
        self.topic = topic
        _value = value
        self.range = range
    }

    var body: some View {
        HStack(spacing: 6) {
            Stepper(title, value: $value, in: range)
            ContextualHelpButton(topic: topic)
        }
    }
}
