# Limpiador

## Estado

`CleanerModule` 0.1.1 forma parte de ZEUVE como módulo built-in, local y sin red. Su identificador estable es `com.zeuve.cleaner` y su categoría visible es **Sistema**. El módulo se incorporó en ZEUVE 0.20.0.0.

## Objetivo

El módulo concentra en un único pipeline el inventario de aplicaciones, la detección de residuos, la limpieza de datos regenerables, el análisis de desinstalación y la exploración de espacio. La prioridad es detectar residuos con evidencias revisables sin convertir la ausencia de una `.app` en una autorización de borrado.

Pipeline: **Inventario → descubrimiento → evidencias → asociación → guardas → riesgo → candidatos → plan → selección → revalidación → ejecución → verificación**.

## Interfaz

La pantalla principal tiene cinco áreas:

- **Resumen**: cobertura, aplicaciones, candidatos, tamaño analizado, selección segura potencial y ubicaciones sin acceso. La selección segura potencial es una estimación del espacio asignado a elementos regenerables elegibles; no ejecuta ni autoriza limpieza.
- **Aplicaciones**: inventario, búsqueda, ubicación, análisis de desinstalación y entrada por drag & drop de `.app`.
- **Residuos**: residuos probables, posibles, asociaciones inciertas, elementos conservados y aplicaciones no disponibles.
- **Limpieza**: muestra todos los candidatos del plan, también preferencias y datos persistentes sin marcar; permite selección segura, revisión individual, Papelera o borrado permanente y Undo cuando procede.
- **Espacio**: explorador jerárquico por tamaño sin seguir enlaces simbólicos.

## Inventario

En producción se inspeccionan `/Applications`, `~/Applications`, aplicaciones conocidas por `NSWorkspace`, resultados de Spotlight revalidados contra el filesystem y ubicaciones adicionales elegidas por el usuario. Los tests inyectan raíces propias y nunca necesitan escanear el Mac real.

El inventario y las mediciones largas atienden la cancelación. Spotlight se inicia en el hilo principal, tiene un límite de 30 segundos y puede terminar por cancelación, indisponibilidad o fin de búsqueda. Si no termina normalmente, el resto del análisis continúa con cobertura parcial y un aviso visible; los registros históricos no se convierten en aplicaciones desaparecidas por ese motivo. Lo mismo se aplica cuando una raíz de inventario no es accesible.

Mientras una aplicación existe se intenta conservar Bundle ID, nombre, versión/build, ruta, volumen, Signing Identifier, Team ID y App Groups. La firma se consulta mediante Security.framework en macOS; no se invoca `codesign`.

El historial de inventario se guarda localmente en SQLite por aplicación y raíz asociada. No se persiste un listado exhaustivo de todos los archivos internos.

## Asociación y riesgo

La confianza de asociación es `Alta`, `Media` o `Baja`; el estado de residuo y el riesgo de eliminación son dimensiones distintas. No se usan porcentajes de confianza.

Las evidencias fuertes incluyen Bundle ID, App Groups e identidad histórica observada. Las coincidencias de nombre son heurísticas y nunca bastan por sí solas para una selección automática.

Guardas relevantes: múltiples copias de la aplicación, proceso activo, volumen externo ausente, App Group compartido, decisión `Conservar`, datos persistentes, falta de permisos y cambios posteriores al análisis.

`Preferences`, `Application Support`, `Containers`, `Group Containers` y scripts/datos persistentes no se preseleccionan aunque la asociación sea alta.

## Limpieza regenerable

La selección automática segura se limita a categorías regenerables con asociación alta, riesgo bajo y sin guardas. Incluye cachés/logs compatibles y datos regenerables de Xcode. `Archives` de Xcode no se escanea como caché y no se autoselecciona.

Los instaladores `.dmg`, `.pkg` y `.xip` se detectan inicialmente en `~/Downloads` y ubicaciones adicionales, con umbral configurable de 90 días. La antigüedad es solo una heurística y nunca implica selección automática.

## Desinstalación

`Analizar desinstalación` no modifica archivos. La `.app` permanece disponible durante el análisis para conservar evidencia. Si está abierta se ofrece terminación normal mediante `NSWorkspace`; V1 no usa `kill -9`.

Si existe un desinstalador oficial relacionado se ofrece abrirlo. ZEUVE no introduce credenciales ni obtiene privilegios. Después puede reanalizarse el estado.

Antes de ejecutar se revalidan existencia, tipo, fingerprint y guardas. Si la aplicación no puede retirarse, los elementos asociados de esa misma operación de desinstalación se omiten por seguridad.

En un plan de desinstalación, «Seleccionar elementos seguros» conserva la selección explícita de la `.app` y solo añade asociados regenerables elegibles. Si se desmarca la aplicación, se desmarcan sus asociados y no pueden volver a seleccionarse hasta seleccionar la aplicación. Los datos persistentes siguen disponibles para revisión individual, siempre sin selección automática.

## Ejecución y Undo

El modo predeterminado es **Mover a Papelera** con la API nativa `FileManager.trashItem`. Se registra la ubicación original, la ubicación real devuelta por macOS y un `CleanerFileFingerprint` específico.

El Undo solo restaura cuando el objeto sigue verificable y la ruta original está libre. Nunca sobrescribe silenciosamente un objeto nuevo. El borrado permanente es opt-in, requiere confirmación en UI y no ofrece Undo.

La confirmación previa enumera las rutas seleccionadas, cantidad, tamaño y modo de eliminación. El resultado distingue eliminados, omitidos y fallidos con detalle por elemento. Tras ejecutar se actualiza el análisis y se deja la nueva selección vacía; «Deshacer» solo aparece si hubo al menos un movimiento recuperable a Papelera.

Las operaciones completas de análisis, limpieza, desinstalación, exploración pesada y restauración comparten `OperationCoordinator`.

## Persistencia

La migración SQLite 3 añade:

- `cleaner_app_inventory`
- `cleaner_associated_roots`
- `cleaner_user_decisions`
- `cleaner_scan_metadata`
- `cleaner_undo_items`

Las preferencias normales se guardan mediante `SettingsRepository`. Borrar el inventario histórico no borra decisiones `Conservar` ni elementos Undo todavía pendientes.

## Fuera de alcance V1

No hay helper privilegiado, `sudo`, shell, Homebrew cleaner, KEXT/System Extension removal, snapshots APFS, limpieza de Keychain, monitor residente, IA de borrado ni receipts PKG avanzados como requisito.
