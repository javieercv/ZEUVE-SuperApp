# Informe de implementación — ZEUVE 0.20.0.0

## Alcance

ZEUVE 0.20.0.0 incorpora dos bloques: personalización global del orden/atajos de módulos y el nuevo Limpiador 0.1.0.

## Navegación y atajos

Se añade `NavigationPreferences` en Core y la preferencia global `navigation.preferences`. El catálogo built-in sigue siendo fuente de IDs y defaults. Sidebar, Inicio y comandos consumen el mismo orden efectivo. Los defaults son Organizador `⌘1`, Descargador `⌘2`, Analizador `⌘3`, Conversor `⌘4`, Comparador `⌘5`, Inspector `⌘6`, Limpiador `⌘7` e Historial `⌘8`.

Los atajos aceptan Command/Option/Control/Shift, pueden desactivarse y se editan mediante recorder AppKit nativo. La validación impide duplicados, teclas de escritura sin modificador seguro y comandos fundamentales como `⌘Q`, `⌘W`, `⌘Z`, `⌘X`, `⌘C`, `⌘V` y `⌘A`. Las preferencias persistidas se normalizan al cargar para sobrevivir a módulos nuevos, eliminados o duplicados.

## Limpiador

Se crea `CleanerModule` sin dependencia de ZEUVEEngines ni red. La UI se integra en `Sources/ZEUVEApp/Cleaner`, el target contiene inventario, discovery, asociación, reglas, desarrollo, planificación, ejecución y persistencia.

El inventario usa APIs nativas y Security.framework en macOS; la asociación separa evidencia, confianza, estado y riesgo. Los scans no siguen symlinks. Los datos persistentes y App Groups compartidos están protegidos. Xcode se limita a contenido regenerable de DerivedData y no incluye Archives. Instaladores antiguos nunca se autoseleccionan.

La ejecución revalida cada candidato, admite resultados parciales, usa Papelera por defecto y mantiene Undo verificable. El borrado permanente es opt-in. Un fallo al retirar la aplicación bloquea sus datos asociados en la misma desinstalación.

## Storage

La migración 3 añade las tablas específicas del Limpiador, incluido `cleaner_undo_items`. El reset global restaura preferencias y navegación, pero no borra inventario histórico, historial ni decisiones `Conservar`.

## Dependencias y privacidad

No se añaden dependencias externas, motores, APIs, Internet, telemetría, shell, `sudo` ni helper privilegiado.

## Corrección de build Xcode — 22 de septiembre de 2026

Se corrigen problemas de compilación detectados por Xcode/Swift 6 sin modificar el comportamiento visible del Limpiador ni la navegación:

- `CleanerSpotlightApplicationDiscovery` evita almacenar directamente el cierre de reanudación de `CheckedContinuation` y resume la continuación desde el observer de Spotlight.
- `CleanerUninstallAnalyzer` deja de declarar una conformidad `Sendable` innecesaria mientras conserva la inyección de `FileManager` para tests.
- `SystemCleanerFileMutator` mantiene el contrato `CleanerFileMutating: Sendable` mediante una conformidad `@unchecked Sendable`, sin cambiar la política de Papelera, borrado permanente o restauración.
- `ZEUVEApp.swift` importa explícitamente `ZEUVECore` para resolver `KeyboardShortcutDescriptor`.
- `CleanerView` corrige la sintaxis de comparación de `NSOpenPanel.runModal()` con `.OK`.
- Los tests del Limpiador inyectan un mutador de Papelera temporal para validar Undo/conflictos sin depender de la Papelera real de macOS.
- Los tests de bookmarks distinguen fallos ambientales de `ScopedBookmarksAgent`: el round-trip real se omite de forma explícita cuando el agente no responde, y el test de borrado de bookmark del Conversor usa un codec portable inyectado.

No se añaden red, dependencias, motores, permisos, rutas nuevas ni cambios de UX.
