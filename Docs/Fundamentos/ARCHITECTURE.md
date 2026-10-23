# Arquitectura de ZEUVE 0.21.0.0

Este documento describe la arquitectura vigente. La evolución por versiones se conserva en `CHANGELOG.md` y `Docs/Historico/`.

## Principios

- App nativa para macOS 14+ Apple Silicon, Swift 6.
- SwiftUI para la mayor parte de la interfaz y AppKit donde aporta integración nativa.
- Módulos funcionales separados de la composición de UI.
- Servicios compartidos para almacenamiento, operaciones, motores y contratos.
- Privacidad local por defecto; red solo en funcionalidades que la declaran.
- Originales protegidos, publicación segura y ejecución de procesos sin shell interpolado.

## Capas

### `ZEUVEApp`

Compone ventanas, navegación, Dashboard, Historial, Ajustes, ViewModels y vistas específicas. Puede usar SwiftUI/AppKit y enlaza los módulos built-in con la infraestructura compartida.

### `ZEUVECore`

Contiene contratos y utilidades transversales: manifests/permisos, rutas, fingerprints, logging local, modelos de operaciones, navegación personalizable y tipos compartidos. No debe contener UI de módulo.

### `ZEUVEStorage`

Persistencia SQLite y repositorios de Ajustes/Historial/migraciones. Los módulos no crean almacenes de preferencias paralelos cuando una preferencia pertenece a Ajustes centralizados.

### `ZEUVEOperations`

`OperationCoordinator` coordina operaciones pesadas. Una operación principal pesada se reserva y cancela de forma centralizada para evitar competencia no controlada. El propietario debe propagar una reserva ocupada, atender cancelación local/global y completar `finish` antes de devolver el control.

### `ZEUVEEngines`

Registro, diagnóstico, verificación, overrides manuales y ejecución segura de motores. `ExternalProcessRunner` usa executable + argumentos separados, gestiona procesos/grupos/cancelación y evita `/bin/sh`.

### Puentes de bajo nivel

`CZEUVEProcess`, `CSQLite` y `CLibArchive` aíslan APIs C/sistema necesarias para procesos, SQLite y archivos comprimidos.

## Servicios residentes de utilidades rápidas — registro retirado

> Retirado del código el 23/10/2026 por decisión del usuario. Este apartado conserva el diseño y los límites del intento, no describe funciones actuales ni QA pendiente. Véase el [registro de retirada](../Historico/Implementacion/QUICK_UTILITIES_RETIREMENT_20261023.md).

`ZEUVEQuickUtilities` es un target propio dependiente de Core/Storage/Operations; no pertenece al catálogo de módulos. `QuickUtilitiesCatalog` mantiene nueve IDs estables. `QuickUtilitiesCoordinator` separa solicitud persistida, transición y estado efectivo; serializa activaciones por utilidad y coordina parada/restablecimiento.

`ResidentRuntime` compone Storage, coordinadores y servicios ligeros desde el ciclo de aplicación. `AppModel` y los ViewModels de módulos se crean al abrir la interfaz principal, evitando su inicialización en un arranque residente sin ventana. Cerrar la ventana conserva el modelo cuando ya existe; no se presupone una reducción de memoria sin medición. Barra de menús y Ajustes funcionan sin crear ese modelo completo. La app conserva identidad y Dock normales.

Los bloques propios son Audio, Input, Windows y Productivity. Audio comparte `AudioRoutingCoordinator` con leases por propietario `mixer`/`callDiagnostic`, ganancias compatibles y liberación individual; el diagnóstico fuerza reproducción a ganancia 1 sin declarar protección eficaz. El callback calcula RMS agregado únicamente cuando la prueba lo solicita, con lectura atómica en RAM. Sus tareas de apertura/refresco y el consumidor de eventos nativos tienen propietario y parada con cancelación/espera; Input comparte un tap de sesión en run loop propio sin observar teclado; Windows comparte un backend AX con propiedad por utilidad; Productivity usa publicación segura y Servicios. Los callbacks de UI y registro Carbon se mantienen en MainActor, mientras mensajes AX, publicación y trabajo nativo costoso se aíslan de él.

`GlobalShortcutRegistry` registra combinaciones específicas mediante Carbon y libera registros/handler al detener. La validación cruza utilidades, navegación de ZEUVE y combinaciones públicas del sistema; no puede enumerar todos los atajos de aplicaciones externas. La persistencia sigue en `SettingsRepository`. Los servicios ligeros no reservan permanentemente `OperationCoordinator`.

Contrato, recursos, permisos y límites reales: [Utilidades rápidas](../Utilidades/QUICK_UTILITIES.md).

## Composición actual de la aplicación

Tras la retirada del 23/10/2026, `ZEUVEApp` usa `WindowGroup` y `Settings` con un `AppModel` compartido que inicializa Storage, logger, registro y `OperationCoordinator`. Los atajos de navegación se resuelven desde ese modelo. Al salir se cancelan las operaciones y terminan los procesos externos propios. No existe runtime de microutilidades, barra de menús, registro de inicio con macOS ni proveedor de Servicios.

## Módulos built-in

| Módulo | Target | Versión | Ajustes |
| --- | --- | ---: | ---: |
| Organizador | `OrganizerModule` | 0.1.5 | orden 10 |
| Descargador universal | `UniversalDownloaderModule` | 0.7.8 | orden 20 |
| Analizador de chats | `ChatAnalyzerModule` | 0.1.6 | orden 30 |
| Conversor universal | `UniversalConverterModule` | 0.3.2 | orden 40 |
| Comparador de seguidores de Instagram | `InstagramFollowersModule` | 0.1.0 | sin sección propia |
| Inspector multimedia | `MultimediaInspectorModule` | 0.7.5 | orden 50 |
| Limpiador | `CleanerModule` | 0.1.4 | orden 60 |

Los manifests bajo `Sources/*Module/Resources/manifest.json` describen identidad, versión, versión mínima, permisos, capacidades y presentación. `BuiltInModuleCatalog` registra los siete módulos en la app.

## Navegación y personalización

`NavigationPreferences` persiste un **orden de módulos** compartido por Sidebar, tarjetas de Inicio y comandos. También permite personalizar o desactivar los atajos de módulos e Historial.

Defaults actuales: Organizador ⌘1, Descargador ⌘2, Analizador ⌘3, Conversor ⌘4, Comparador ⌘5, Inspector ⌘6, Limpiador ⌘7 e Historial ⌘8.

La validación rechaza duplicados, teclas de escritura sin modificador seguro y combinaciones reservadas fundamentales. No existe ocultación de módulos como preferencia de navegación en 0.21.0.0. El orden de secciones de Ajustes (`settingsOrder`) es independiente del orden de navegación.

## Ajustes

`SettingsView` presenta preferencias globales y secciones registradas por módulos. `SettingsRepository` es la vía persistente central. Restaurar valores por módulo o globalmente debe volver a defaults sin borrar archivos del usuario, historial o estados que expresamente deban conservarse.

## Historial

Las operaciones relevantes publican registros mediante la capa de Storage. El historial debe guardar metadata mínima y agregada; no debe convertirse en un archivo de URLs completas, rutas privadas, contenido OCR/chats, cookies, tokens o cabeceras.

Undo solo existe cuando el módulo puede verificarlo de forma segura. Organizador y Limpiador tienen semánticas diferentes y no deben compartir una falsa abstracción destructiva.

## Archivos y publicación

El patrón general para generar resultados es:

1. inspeccionar/validar entradas;
2. capturar fingerprint cuando proceda;
3. trabajar en un temporal propiedad de la operación;
4. revalidar entradas/plan;
5. validar el resultado;
6. resolver conflictos;
7. publicar de forma segura;
8. limpiar únicamente temporales verificablemente propios.

Organizador es una excepción deliberada porque su función consiste en mover originales tras preview/selección. Limpiador puede inspeccionar ubicaciones locales documentadas mediante `scanLocalStorage`, pero cualquier retirada exige `removeLocalItems`, plan visible, selección y revalidación.

## Motores

La instantánea actual de `Resources/Engines/engines.json` marca como obligatorios:

- yt-dlp 2026.08.19;
- Deno 2.9.0;
- FFmpeg 8.1.2;
- FFprobe 8.1.2;
- gallery-dl 1.32.9;
- instaloader-zeuve 4.15.3-zeuve.7.

Pandoc continúa soportado por el Conversor como motor opcional cuando la preparación lo incorpora. El helper Playwright no participa en el routing efectivo actual. Calibre, Ghostscript y LibreOffice están retirados.

## Dependencias entre módulos

Los targets de módulo dependen de las capas compartidas que necesitan, no de otros módulos funcionales. La reutilización transversal debe subir a una capa común aprobada; no se debe crear una cadena Organizador → Conversor → Descargador, etc.

## Extensibilidad

La API y manifests están diseñados para una arquitectura modular, pero 0.21.0.0 integra módulos built-in compilados con la app. No existe loader de plugins externos ni importación arbitraria de módulos de terceros.

## Fuentes de verdad

- Integración de módulos: manifests + `BuiltInModuleCatalog.swift`.
- Navegación: `NavigationPreferences.swift` + catálogo.
- Persistencia: `SettingsRepository`/Storage.
- Motores empaquetables: `Resources/Engines/engines.json` y scripts de preparación/verificación.
- Reglas permanentes: `SUPERAPP_PROJECT_RULES.md`.
- Alcance funcional actual: `FUNCTIONAL_SCOPE.md` y documentos de módulo.
