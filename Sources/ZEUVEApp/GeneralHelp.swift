extension ZEUVEHelpTopics {
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
}
