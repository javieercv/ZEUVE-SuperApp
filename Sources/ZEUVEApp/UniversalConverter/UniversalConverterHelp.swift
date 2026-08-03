import Foundation

extension ZEUVEHelpTopics {
    static let converterInputs = ContextualHelpTopic(
        "Entradas del Conversor",
        explanation: "Puedes añadir archivos, carpetas o un ZIP. Las carpetas se recorren progresivamente y los ZIP se inspeccionan sin extraer contenido pesado hasta que empieza la conversión. Los originales se abren solo para lectura."
    )
    static let converterOperation = ContextualHelpTopic(
        "Tipo de conversión",
        explanation: "Selecciona una única receta para toda la cola. Extraer fotogramas guarda todos los fotogramas decodificados. Crear vídeo desde audio genera una pantalla negra o utiliza la imagen que elijas."
    )
    static let converterQuality = ContextualHelpTopic(
        "Calidad",
        explanation: "Calidad alta prioriza conservar información. Equilibrada reduce moderadamente el tamaño y Tamaño reducido utiliza más compresión.",
        recommendation: "Usa Calidad alta cuando no tengas una necesidad concreta de ahorrar espacio."
    )
    static let converterFrames = ContextualHelpTopic(
        "Fotogramas sin pérdida adicional",
        explanation: "PNG y TIFF no introducen una pérdida nueva después de decodificar el vídeo. No pueden recuperar información que el códec original ya eliminó. El CSV opcional conserva el tiempo y la duración de cada fotograma."
    )
    static let converterRemux = ContextualHelpTopic(
        "Copia rápida sin recodificar",
        explanation: "Conserva las pistas originales y solo cambia el contenedor cuando son compatibles. Es muy rápido, pero no reduce el tamaño, no cambia la calidad y puede generar un archivo prácticamente idéntico.",
        recommendation: "Déjala desactivada cuando quieras una conversión real. Actívala solo si buscas cambiar de contenedor sin recomprimir."
    )
    static let converterPDFDPI = ContextualHelpTopic(
        "Resolución de PDF",
        explanation: "Controla la resolución al convertir páginas PDF en imágenes. Un valor mayor genera imágenes más detalladas, pero aumenta mucho el tamaño y el uso de memoria.",
        recommendation: "300 ppp ofrece buena calidad para impresión general."
    )
    static let converterConflict = ContextualHelpTopic(
        "Conflictos de nombres",
        explanation: "Renombrar automáticamente conserva el archivo existente. Omitir no crea el nuevo resultado. Reemplazar solo se ejecuta después de una confirmación expresa.",
        recommendation: "Renombrar automáticamente es la opción más segura."
    )
    static let converterZIPPassword = ContextualHelpTopic(
        "Contraseña del archivo",
        explanation: "La contraseña se conserva únicamente en memoria durante esta selección y no se guarda en Ajustes, historial, favoritas, preajustes ni registros. Se utiliza para ZIP cifrados y PDF protegidos cuando el motor local puede abrirlos."
    )
    static let converterPresets = ContextualHelpTopic(
        "Preajustes de conversión",
        explanation: "Un preajuste guarda la operación, el formato y las opciones de calidad para reutilizarlos. Las imágenes elegidas para crear vídeo y las contraseñas de ZIP nunca se guardan dentro de un preajuste."
    )
    static let converterCoverArt = ContextualHelpTopic(
        "Portada integrada",
        explanation: "Cuando el archivo de audio contiene una portada integrada, ZEUVE intenta conservarla al convertir a MP3, M4A o FLAC. La imagen se copia sin volver a comprimir cuando el contenedor de salida la admite.",
        recommendation: "Mantén esta opción activada salvo que quieras un archivo de audio sin portada."
    )

}

extension ZEUVEHelpTopics {
    static let converterMetadata = ContextualHelpTopic(
        "Metadatos",
        explanation: "Los metadatos incluyen autor, fecha, ubicación, cámara, etiquetas, portada, capítulos y datos técnicos. Cada formato conserva solo los grupos compatibles y ZEUVE nunca copia contenido activo peligroso.",
        recommendation: "Conservar todos los compatibles es la opción predeterminada. Elige solo esenciales o eliminar cuando priorices privacidad."
    )
    static let converterBitrate = ContextualHelpTopic(
        "Bitrate",
        explanation: "Indica cuántos datos por segundo utiliza el audio o el vídeo. Un valor mayor suele aumentar calidad y tamaño, pero no recupera información perdida en el original."
    )
    static let converterCRF = ContextualHelpTopic(
        "CRF y calidad constante",
        explanation: "Controla la calidad visual durante la codificación. En escalas CRF, un número menor suele significar mayor calidad y archivos más grandes. El valor exacto depende del códec."
    )
    static let converterCodec = ContextualHelpTopic(
        "Códec",
        explanation: "Es el método que comprime y descomprime audio, vídeo o imágenes. El contenedor es el archivo que guarda las pistas; no todos los códecs son compatibles con todos los contenedores."
    )
    static let converterStreamCopy = ContextualHelpTopic(
        "Copia rápida sin recodificar",
        explanation: "Copia una pista compatible al archivo final sin volver a comprimirla. Es útil para cambiar de contenedor, pero no convierte el contenido, no reduce su tamaño y no permite aplicar filtros ni cambiar sus parámetros.",
        recommendation: "Déjala desactivada como valor predeterminado para que las conversiones de vídeo sean reales."
    )
    static let converterDPI = ContextualHelpTopic(
        "DPI o ppp",
        explanation: "Representa la densidad usada al rasterizar o preparar una imagen para impresión. Aumentarlo genera más píxeles y requiere más memoria; no añade detalle que no exista en la fuente."
    )
    static let converterBitDepth = ContextualHelpTopic(
        "Profundidad de bits",
        explanation: "Indica cuántos niveles puede representar cada muestra o canal. Más bits permiten gradaciones más suaves o mayor rango, pero aumentan tamaño y exigen formatos compatibles."
    )
    static let converterPixelFormat = ContextualHelpTopic(
        "Formato de píxel",
        explanation: "Define cómo se almacenan el color, el muestreo y la profundidad de cada píxel. Cambiarlo puede afectar compatibilidad, HDR, transparencia y fidelidad."
    )
    static let converterHDR = ContextualHelpTopic(
        "HDR y SDR",
        explanation: "HDR conserva un rango más amplio de brillo y color cuando la fuente, el códec y el reproductor lo admiten. Convertir a SDR puede requerir mapeo de tonos y cambiar el aspecto."
    )
    static let converterColorProfile = ContextualHelpTopic(
        "Perfil de color",
        explanation: "Describe cómo interpretar los colores del archivo. ZEUVE intenta conservarlo; si el destino no lo admite, debe convertirlo y avisar porque el aspecto puede variar."
    )
    static let converterGenerationLoss = ContextualHelpTopic(
        "Pérdida generacional",
        explanation: "Es la pérdida adicional que aparece al volver a comprimir un archivo con pérdida. La copia directa o los formatos sin pérdida la evitan cuando son compatibles."
    )
    static let converterParallelism = ContextualHelpTopic(
        "Paralelismo",
        explanation: "Permite procesar varios elementos del mismo lote a la vez. El modo automático limita las tareas pesadas según CPU, memoria y motor para mantener estable el Mac.",
        recommendation: "Utiliza Automático. Aumentar el valor manual puede empeorar el rendimiento o agotar memoria."
    )
    static let converterHardware = ContextualHelpTopic(
        "Aceleración por hardware",
        explanation: "VideoToolbox utiliza los codificadores del Mac. Puede acelerar la conversión, pero no se usa cuando eliminaría funciones necesarias o reduciría la fidelidad seleccionada. Siempre que exista se mantiene una alternativa por software."
    )
    static let converterZIPBomb = ContextualHelpTopic(
        "Protección frente a ZIP bombs",
        explanation: "Un ZIP malicioso puede declarar pocos bytes comprimidos y expandirse hasta ocupar enormes cantidades de disco o memoria. ZEUVE limita entradas, tamaños, profundidad y relación de compresión antes de extraer."
    )
    static let converterAtomicReplacement = ContextualHelpTopic(
        "Sobrescritura atómica",
        explanation: "La nueva conversión se valida primero en un temporal. Solo después sustituye el resultado anterior mediante una operación atómica. Si falla, el archivo anterior se conserva intacto."
    )
    static let converterOutputFolder = ContextualHelpTopic(
        "Carpeta de salida",
        explanation: "Puedes guardar directamente o crear una subcarpeta. La carpeta recordada utiliza un bookmark de seguridad; si deja de ser válido, ZEUVE solicita seleccionarla de nuevo."
    )
    static let converterZIPStructure = ContextualHelpTopic(
        "Estructura del ZIP",
        explanation: "Conservar mantiene las carpetas internas. Aplanar guarda todos los resultados juntos y resuelve de forma segura los nombres repetidos.",
        recommendation: "Conservar estructura evita perder el contexto original."
    )
    static let converterDiagnostics = ContextualHelpTopic(
        "Diagnóstico del Conversor",
        explanation: "Comprueba localmente motores, versiones, arquitectura, permisos, dependencias, códecs, formatos y autopruebas sintéticas. No envía datos ni utiliza archivos personales."
    )
}
