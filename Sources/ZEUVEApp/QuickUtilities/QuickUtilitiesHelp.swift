import ZEUVEQuickUtilities

enum QuickUtilitiesHelp {
    static let resident = ContextualHelpTopic("ZEUVE residente", explanation: "Cerrar una ventana conserva la aplicación y las utilidades activadas. Salir detiene los servicios, retira sus recursos y cierra ZEUVE. El inicio con macOS sólo se registra cuando lo activas y puede requerir aprobación del sistema.", recommendation: "Activa únicamente las utilidades que necesites; todas empiezan desactivadas.")
    static func topic(for id: QuickUtilityID) -> ContextualHelpTopic {
        let descriptor = QuickUtilitiesCatalog.descriptor(for: id)
        let explanation: String
        switch id {
        case .audioProtection: explanation = "La protección todavía necesita una prueba real de FaceTime con altavoces y AirPods. Un tap no demuestra que evite la atenuación. La utilidad permanecerá no disponible hasta validar una solución eficaz."
        case .audioMixer: explanation = "Cambiar el volumen de una fuente crea una ruta local que procesa su audio en memoria. No se graba ni se envía. Sólo se admiten salidas y fuentes compatibles; no selecciones conversaciones. Al cambiar dispositivo o procesos se recupera la reproducción original y debes seleccionar de nuevo."
        case .scroll: explanation = "Se invierten eventos discretos de rueda, conservando gestos y eventos continuos. No se identifica el ratón físico: otros ratones discretos también reciben la corrección. La dirección del trackpad sigue siendo la que tengas configurada en macOS."
        case .mouseButtons: explanation = "Las asignaciones se aplican por número de botón a ratones compatibles. No distinguen físicamente dos ratones con el mismo botón. Los botones principales y central están protegidos. Mission Control, Escritorio y navegación requieren que el destino tenga configurado el atajo elegido."
        case .windowSwitcher: explanation = "La lista usa Accesibilidad y muestra títulos sólo mientras está abierta. No se capturan miniaturas ni se guardan títulos. Confirmar activa una ventana compatible; Esc cancela. Spaces, pantalla completa y algunas aplicaciones pueden limitar las acciones."
        case .windowLayouts: explanation = "Los perfiles guardan geometría y aplicación. Las ventanas se asocian explícitamente durante la sesión; después de perder la identidad debes reasociarlas. La restauración automática sólo actúa sobre asociaciones verificadas y empieza desactivada."
        case .newFile: explanation = "La carpeta y el nombre se eligen explícitamente. La publicación conserva archivos existentes y rechaza enlaces simbólicos inseguros. Las plantillas contienen sólo el texto mostrado; no ejecutan programas. El Servicio de Finder necesita una carpeta seleccionada y estar activado en macOS."
        case .fileShelf: explanation = "Hasta 500 referencias se conservan en RAM, sin copiar ni mover archivos. Se vacían al detener o salir. Al arrastrarlas hacia otra aplicación, el destino decide copiar o mover; ZEUVE no ejecuta esa operación."
        case .selectedText: explanation = "Invoca una transformación desde Servicios sobre texto seleccionado en una aplicación compatible. Sólo se usa el pasteboard específico de esa solicitud. El formato enriquecido se rechaza para conservarlo. No se vigila el portapapeles general ni se fuerza acceso a campos protegidos."
        }
        return .init(descriptor.name, explanation: explanation)
    }
}
