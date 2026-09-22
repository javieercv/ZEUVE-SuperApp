# Informe de implementación — ZEUVE 0.12.4

Fecha: 2026-09-07  
Build: 46

## Objetivo

La versión 0.12.4 robustece áreas detectadas durante una auditoría independiente posterior a las fases 1–5 de saneamiento. La intervención mantiene la UI, los módulos, motores, formatos, permisos, red aprobada y dependencias existentes, y corrige problemas concretos de concurrencia, cancelación, privacidad, persistencia temporal y escalabilidad.

## Descargador universal

- `UniversalDownloaderViewModel` separa `operationTask` e `instagramSessionImportTask`; la importación de sesión ya no puede pisar la tarea de una operación pesada.
- Análisis y descarga no comienzan durante una importación incompatible y la UI bloquea esas combinaciones.
- La descarga normal y el reemplazo confirmado convergen en un único ejecutor privado. Ambos publican el mismo progreso a `OperationCoordinator` y comparten finalización, cancelación y errores.
- `OperationCoordinator.finish()` se espera antes de limpiar `currentOperationID` y devolver la UI a `.ready`/`.idle`, eliminando la ventana que permitía un falso «operación en curso».
- La detección de posibles duplicados mantiene un índice incremental de firmas en lugar de recalcular todo el catálogo después de cada análisis.
- Se elimina el bloque de reemplazo confirmado que reasignaba la misma política sin efecto útil.

## Procesos externos

`ExternalProcessRunner.run()` usa cancelación estructurada: cancelar la `Task` Swift propietaria activa la terminación del grupo POSIX asociado. Se conserva el mecanismo aprobado de `posix_spawn`, argumentos separados, SIGTERM, espera limitada y SIGKILL como último recurso; no se introduce `/bin/sh`, `Process` ni un ejecutor alternativo.

## Analizador de chats

`TemporaryChatStore` pasa de copia secundaria a fuente principal de la sesión:

- WhatsApp entrega mensajes por lotes e Instagram procesa páginas incrementalmente.
- SQLite aplica deduplicación conservadora global durante la inserción y materializa una cronología estable.
- `ChatAnalysisResult` deja de requerir una colección completa de mensajes como contenido de sesión.
- `ChatStoreAnalytics` calcula núcleo, actividad, participantes, palabras, conversaciones, respuestas, comparación y búsqueda recorriendo el store por bloques.
- Las frecuencias y conversaciones que pueden crecer proporcionalmente utilizan almacenamiento SQLite auxiliar temporal.
- La búsqueda conserva sus opciones y paginación, pero mantiene solo la página/contexto necesarios en memoria.
- `ChatArchiveReader` comprueba cancelación entre entradas y bloques y rechaza rutas normalizadas duplicadas.
- `allMessages()` se conserva únicamente como API de compatibilidad controlada para pruebas/utilidades pequeñas; el flujo normal del ViewModel no la usa.

No se reduce el límite estructural aprobado de hasta 20 millones de mensajes para ocultar el problema de memoria. La validación extrema de rendimiento visual sigue requiriendo un Mac Apple Silicon.

## Privacidad, logs y arranque

- El Organizador deja de registrar rutas completas de carpetas del usuario.
- `LocalLogger` conserva solo JSONL propios, aplica 30 días de retención y un máximo global de 50 MiB y solicita permisos 0700/0600 cuando el sistema lo permite.
- La limpieza de logs ignora archivos que no coinciden con el patrón propiedad de ZEUVE.
- Si falla la creación del logger o del registro compartido de motores, ZEUVE arranca de forma degradada y acumula una advertencia segura en lugar de silenciar el problema con `try?`.

## Red y bookmarks

- La consulta manual de Wayback usa una `URLSession` efímera dedicada, sin caché ni almacenamiento persistente de cookies, con 30 s de timeout de petición y 120 s de recurso.
- Los stores de bookmarks del Descargador y Conversor ya no borran una preferencia ante cualquier error de resolución. Los stale resolubles se refrescan y los fallos no concluyentes conservan los datos para un intento posterior.
- El restablecimiento global sigue eliminando explícitamente los bookmarks aprobados y nunca borra las carpetas o archivos a los que apuntan.

## QA y documentación

Los verificadores de la Fase 5 se actualizan para proteger la arquitectura nueva en vez de exigir caches o snapshots que materializaban el chat completo. Se añaden regresiones para procesos externos, logs, bookmarks, ZIP y equivalencia de analíticas SQLite. Se actualizan `VERSION`, generador Xcode, coherencia de proyecto, documentación vigente, changelog y decisiones permanentes.

## Dependencias y comportamiento no modificado

No se añaden dependencias, motores, APIs, endpoints, telemetría, actualizaciones automáticas, permisos, App Sandbox ni CI. No cambian formatos, fallbacks aprobados, perfiles, presets, claves legacy, historial visible, política de archivos originales ni estructura de módulos.
