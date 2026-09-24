# Arquitectura de ZEUVE 0.20.3.0

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

`OperationCoordinator` coordina operaciones pesadas. Una operación principal pesada se reserva y cancela de forma centralizada para evitar competencia no controlada.

### `ZEUVEEngines`

Registro, diagnóstico, verificación, overrides manuales y ejecución segura de motores. `ExternalProcessRunner` usa executable + argumentos separados, gestiona procesos/grupos/cancelación y evita `/bin/sh`.

### Puentes de bajo nivel

`CZEUVEProcess`, `CSQLite` y `CLibArchive` aíslan APIs C/sistema necesarias para procesos, SQLite y archivos comprimidos.

## Módulos built-in

| Módulo | Target | Versión | Ajustes |
| --- | --- | ---: | ---: |
| Organizador | `OrganizerModule` | 0.1.4 | orden 10 |
| Descargador universal | `UniversalDownloaderModule` | 0.7.3 | orden 20 |
| Analizador de chats | `ChatAnalyzerModule` | 0.1.6 | orden 30 |
| Conversor universal | `UniversalConverterModule` | 0.3.0 | orden 40 |
| Comparador de seguidores de Instagram | `InstagramFollowersModule` | 0.1.0 | sin sección propia |
| Inspector multimedia | `MultimediaInspectorModule` | 0.7.2 | orden 50 |
| Limpiador | `CleanerModule` | 0.1.1 | orden 60 |

Los manifests bajo `Sources/*Module/Resources/manifest.json` describen identidad, versión, versión mínima, permisos, capacidades y presentación. `BuiltInModuleCatalog` registra los siete módulos en la app.

## Navegación y personalización

`NavigationPreferences` persiste un **orden de módulos** compartido por Sidebar, tarjetas de Inicio y comandos. También permite personalizar o desactivar los atajos de módulos e Historial.

Defaults actuales: Organizador ⌘1, Descargador ⌘2, Analizador ⌘3, Conversor ⌘4, Comparador ⌘5, Inspector ⌘6, Limpiador ⌘7 e Historial ⌘8.

La validación rechaza duplicados, teclas de escritura sin modificador seguro y combinaciones reservadas fundamentales. No existe ocultación de módulos como preferencia de navegación en 0.20.3.0. El orden de secciones de Ajustes (`settingsOrder`) es independiente del orden de navegación.

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
- instaloader-zeuve 4.15.3-zeuve.2.

Pandoc continúa soportado por el Conversor como motor opcional cuando la preparación lo incorpora. El helper Playwright no participa en el routing efectivo actual. Calibre, Ghostscript y LibreOffice están retirados.

## Dependencias entre módulos

Los targets de módulo dependen de las capas compartidas que necesitan, no de otros módulos funcionales. La reutilización transversal debe subir a una capa común aprobada; no se debe crear una cadena Organizador → Conversor → Descargador, etc.

## Extensibilidad

La API y manifests están diseñados para una arquitectura modular, pero 0.20.3.0 integra módulos built-in compilados con la app. No existe loader de plugins externos ni importación arbitraria de módulos de terceros.

## Fuentes de verdad

- Integración de módulos: manifests + `BuiltInModuleCatalog.swift`.
- Navegación: `NavigationPreferences.swift` + catálogo.
- Persistencia: `SettingsRepository`/Storage.
- Motores empaquetables: `Resources/Engines/engines.json` y scripts de preparación/verificación.
- Reglas permanentes: `SUPERAPP_PROJECT_RULES.md`.
- Alcance funcional actual: `FUNCTIONAL_SCOPE.md` y documentos de módulo.
