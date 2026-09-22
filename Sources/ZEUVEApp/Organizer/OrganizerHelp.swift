extension ZEUVEHelpTopics {
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
    static let recentFolders = ContextualHelpTopic(
        "Carpetas recientes",
        explanation: "ZEUVE guarda localmente una lista corta de las últimas carpetas elegidas para facilitar su reutilización. Olvidarlas no elimina ni modifica ningún archivo."
    )
}
