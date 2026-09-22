extension ZEUVEHelpTopics {
    static let interfaceMode = ContextualHelpTopic(
        "Modo simple y avanzado",
        explanation: "El modo simple muestra las decisiones habituales. El modo avanzado añade selección exacta de flujos, metadatos, subtítulos y ajustes de red.",
        recommendation: "Utiliza el modo simple salvo que necesites controlar una pista o un comportamiento técnico concreto."
    )
    static let pageOriginalDownload = ContextualHelpTopic(
        "Descarga original desde una página",
        explanation: "Los vídeos encontrados al analizar una página se descargan en la mejor calidad original disponible. ZEUVE no limita la resolución, no convierte el audio o el vídeo, no fuerza MP4, MKV o WebM y no aplica presets. Si el origen entrega vídeo y audio por separado, puede unirlos sin recodificar.",
        recommendation: "Utiliza las opciones de formato únicamente para enlaces directos de vídeos o colecciones."
    )
    static let pageDiscoveredFilename = ContextualHelpTopic(
        "Nombre de vídeos encontrados en páginas",
        explanation: "ZEUVE elimina identificadores técnicos del extractor y sufijos de numeración detectados en la página. Si varios vídeos comparten el mismo título, los numera consecutivamente desde (1), incluido el primero. Los conflictos con archivos existentes siguen la política segura elegida."
    )
    static let pageSourceMetadata = ContextualHelpTopic(
        "Procedencia en los metadatos",
        explanation: "Guarda dentro del contenedor multimedia la URL limpia de la página, su dominio y, cuando puede detectarse, el identificador de la página. Para hacerlo, FFmpeg reescribe el contenedor copiando los flujos sin recodificar. Si el formato no lo admite, el vídeo se conserva sin cambios y ZEUVE muestra una advertencia.",
        recommendation: "Permanece desactivado por defecto para que cada usuario decida si quiere conservar la procedencia."
    )
    static let pageSourceDownloadDate = ContextualHelpTopic(
        "Fecha de descarga",
        explanation: "Añade a los metadatos la fecha y hora en que ZEUVE procesó el archivo. Solo se usa cuando también está activado Guardar procedencia en los metadatos."
    )
    static let macOSWhereFrom = ContextualHelpTopic(
        "Atributo «De dónde» de macOS",
        explanation: "Añade al archivo el atributo nativo de macOS que contiene la URL limpia de la página de origen. No modifica los flujos multimedia. Este atributo puede perderse al copiar el archivo a algunos discos, servicios en la nube o sistemas de archivos.",
        recommendation: "Actívalo si quieres poder consultar la procedencia desde macOS sin incrustarla necesariamente dentro del vídeo."
    )
    static let downloadContent = ContextualHelpTopic(
        "Tipo de contenido",
        explanation: "Automático por plataforma aplica el perfil configurado para cada origen; de fábrica, todas las plataformas conservan el contenido original de máxima calidad disponible, incluido YouTube. Vídeo descarga imagen y audio. Solo audio conserva o convierte únicamente la pista de sonido."
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
        explanation: "Permite escoger una pista técnica concreta de las disponibles en el servicio de origen, identificada por resolución, códec, FPS y formato. Puede requerir unirla con una pista de audio separada.",
        recommendation: "La selección automática es la opción adecuada en la mayoría de casos."
    )
    static let exactAudioStream = ContextualHelpTopic(
        "Flujo de audio exacto",
        explanation: "Permite seleccionar una pista de audio concreta en lugar de dejar que ZEUVE escoja automáticamente la mejor. Puede ser útil para elegir idioma, códec o bitrate cuando el servicio ofrece varias pistas.",
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
        explanation: "Los subtítulos manuales los aporta el servicio. Los automáticos los genera la plataforma y pueden contener errores. Incrustar los añade al archivo cuando el contenedor lo permite; SRT crea un formato de texto ampliamente compatible."
    )
    static let insecureLocalNetwork = ContextualHelpTopic(
        "HTTP y red local",
        explanation: "Permite analizar direcciones HTTP sin cifrar, localhost y servidores de una red privada. Estas conexiones pueden exponer la URL o el contenido y deben utilizarse únicamente con páginas o equipos de confianza.",
        recommendation: "Mantén esta opción desactivada salvo que necesites descargar desde un servidor local o una página HTTP conocida."
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
    static let adaptivePageFragments = ContextualHelpTopic(
        "Aceleración automática de vídeos segmentados",
        explanation: "Los vídeos HLS y DASH se dividen en fragmentos. ZEUVE empieza solicitando hasta 16 a la vez para aprovechar la conexión y reduce automáticamente a 8, 4 o 1 si el servidor limita las peticiones. No cambia el formato ni la calidad del vídeo.",
        recommendation: "Mantén esta opción activada para obtener la mayor velocidad compatible con cada servidor."
    )
    static let concurrentFragments = ContextualHelpTopic(
        "Fragmentos simultáneos",
        explanation: "Algunos vídeos se descargan por partes. Este valor controla cuántas partes se solicitan a la vez cuando la aceleración automática está desactivada o para enlaces directos. Aumentarlo puede acelerar la descarga, pero también incrementar el uso de red y provocar limitaciones.",
        recommendation: "Usa la aceleración automática para vídeos encontrados en páginas; ajusta este valor manualmente solo cuando lo necesites."
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
    static let quickPreset = ContextualHelpTopic(
        "Aplicar preset",
        explanation: "Carga de una vez una configuración guardada en la operación actual. La creación, edición y eliminación de presets se realiza en Ajustes > Descargador universal.",
        recommendation: "Utiliza un preset cuando repitas con frecuencia la misma combinación de formato, calidad y opciones."
    )
}
