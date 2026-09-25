# Informe de implementación — ZEUVE 0.20.5.0

ZEUVE 0.20.5.0 realiza un saneamiento técnico acotado del Inspector multimedia 0.7.3 y el Limpiador 0.1.3. No incorpora funciones nuevas, dependencias, red, motores, permisos, migraciones ni cambios de UI.

## Inspector multimedia

- `MultimediaBatchPreflightService.prepare` pasa a `async throws` y propaga `OperationCoordinatorError.busy`.
- La operación permanece registrada durante todo el preflight y `finish` se espera antes de devolver resultados o errores.
- La cancelación de la tarea cancela el FFprobe activo; la cancelación global se observa mediante los snapshots existentes del coordinador y produce `CancellationError`.
- Los errores ordinarios de un archivo siguen generando su elemento `.incompatible`; el resultado normal sin reglas continúa siendo `.noChanges`.
- El almacén de reglas elimina un `nil` coalescing redundante sin cambiar datos.
- Los tests de comportamiento actual usan `FFmpegMediaEditCommandBuilder`; `FFmpegTrackEditCommandBuilder` permanece como adaptador deprecated con una regresión de compatibilidad.

## Limpiador

- `CleanerUndoOutput` separa el resumen real de archivos de un posible warning del historial. Un fallo de `updateUndoState` no revierte ni invalida archivos ya restaurados.
- Inventario, Undo y decisiones «Conservar» decodifican todas las filas de forma estricta. Una fila inválida devuelve un error controlado en vez de desaparecer mediante `compactMap`/`try?`.
- El análisis y el ViewModel dejan de sustituir fallos reales de persistencia por colecciones vacías; sin un repositorio fiable no se construye ni ejecuta un plan menos protegido.
- La rama no macOS de Spotlight devuelve `.cancelled` antes de `.unavailable` cuando la tarea ya estaba cancelada. La rama macOS no cambia.

## Compatibilidad preservada

No cambian esquema SQLite, migraciones, tablas, claves, blobs válidos, IDs, raw values, `Codable`, historial correcto, manifests salvo versión, defaults, presets, favoritos, bookmarks, rutas, permisos, navegación, atajos, orden de módulos, originales, publicación segura, red, motores ni argumentos de procesos.
