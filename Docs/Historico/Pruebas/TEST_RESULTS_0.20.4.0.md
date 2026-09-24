# Resultados de pruebas — ZEUVE 0.20.4.0

## Criterio de evidencia

**H** = evidencia histórica de 0.20.3.0; **M** = prueba del motor/SQLite repetida en 0.20.4.0; **UI** = observación directa en la app compilada 0.20.4.0. Una prueba M no valida la pantalla. «No comprobado» identifica exactamente lo que falta; no equivale a fallo reproducido.

## Recorrido de 38 puntos

| # | Punto | Estado | Evidencia breve |
|---:|---|---|---|
| 1 | Apertura inicial | Comprobado y correcto | UI: abre Limpiador y muestra «Aún no hay análisis». |
| 2 | Explicación de lo analizado | Comprobado y correcto | UI: texto de inventario de apps, residuos, cachés, logs y regenerables. |
| 3 | Resumen tras análisis | No comprobado en UI actual | H: resumen y cobertura de análisis intermedio; M: metadata completa. CUA falla al leer resultados. |
| 4 | Navegación por cinco áreas | Comprobado y correcto | UI: Resumen, Aplicaciones, Residuos, Limpieza y Espacio visibles; se abrieron las áreas sin resultados. |
| 5 | Búsqueda de aplicaciones | Comprobado y correcto | UI actual: filtro previo «ZEUVE Cleaner QA 02040» muestra una única `.app` de QA con nombre, versión, ruta y tamaño correctos. |
| 6 | Búsqueda de residuos | No comprobado | No se pudo operar una lista poblada tras el análisis. |
| 7 | Segundo análisis y duplicados | Corregido y verificado | UI actual: dos análisis filtrados dan una fila de la app QA; M: raíz de instaladores solapada produce un candidato. No se cotejó toda la lista masiva. |
| 8 | Qué marca selección segura | Comprobado y correcto | UI actual: `.app`, caché y log QA marcados; 3 elementos/665 bytes. Desmarcar app desmarca y bloquea asociados; seleccionar seguros recupera solo app, caché y log. |
| 9 | Preferencias, configuraciones, bases de datos y datos personales sin marcar | Comprobado parcialmente | UI actual: preferencia y Application Support QA desmarcados y rotulados como persistentes/riesgo alto. M cubre datos persistentes; no se creó una base de datos personal de QA en la UI. |
| 10 | Número y tamaño tras selección manual | Comprobado y correcto | UI actual: preferencia 3→4 y 665→900 bytes; Application Support 3→4 y 665→714 bytes; desmarcar revierte ambos. |
| 11 | Elementos compartidos bloqueados | Comprobado en motor; UI no comprobada | H/M: App Group compartido tiene riesgo alto y `canSelect == false`. |
| 12 | Explicación de elementos no seleccionables | Comprobado parcialmente | UI actual: al desmarcar la app, cada asociado dice «Selecciona primero la aplicación» y se deshabilita. Explicación visual de App Group compartido no comprobada. |
| 13 | Confirmación previa a limpiar | Comprobado y correcto | UI actual: hoja con dos rutas QA, 616 bytes, riesgo, consecuencia, modo Papelera y aviso de revalidación. |
| 14 | Cancelar confirmación sin cambios | Comprobado y correcto | UI actual: Cancelar cerró hoja; se verificó que app, caché, log, preferencia y soporte QA seguían en sus rutas. |
| 15 | Mover a Papelera y ver destino en Finder | Comprobado y correcto | UI actual: dos fixtures seleccionados movidos; Finder mostró app y log en Papelera, con rutas reales confirmadas en SQLite. |
| 16 | Deshacer y recuperar ruta y contenido | Comprobado y correcto | UI actual: «2 elementos restaurados»; rutas originales y SHA-256 de app/log iguales a los registrados, ambos ausentes de Papelera. H/M lo cubrían a nivel motor. |
| 17 | Varias muestras y resultados eliminados/omitidos/fallidos | Comprobado parcialmente | UI actual: dos eliminados, cero omitidos/fallidos y detalle por elemento. M: omisiones y fallo de registro simulados; no se provocó fallo real en UI. |
| 18 | Archivo modificado tras analizar | Comprobado y correcto en motor | H/M: fingerprint distinto produce omisión y conserva archivo. |
| 19 | Nuevo análisis tras limpiar | Comprobado y correcto | UI actual: análisis automático posterior, plan con 0 seleccionados y botón Deshacer disponible; tras reinicio se hizo otro análisis. |
| 20 | Aviso de permanente y uso solo de fixtures | Comprobado parcialmente | UI anterior: aviso en Ajustes; M actual: elimina únicamente fixture seleccionado y no ofrece Undo. Hoja UI no comprobada. |
| 21 | Asociación clara frente a dudosa | Corregido y verificado | UI actual: caché/log/preferencia QA explican Bundle ID exacto; Application Support indica coincidencia de nombre; prefijo `Extra` ausente del plan. M cubre los tres casos. |
| 22 | Mostrar aplicación en Finder | Comprobado y correcto | UI actual: Finder abrió `~/Applications` con la `.app` QA seleccionada. |
| 23 | Arrastrar una `.app` | No comprobado | Intento anterior no llegó a la app; sin validación positiva. |
| 24 | Aplicación abierta | No comprobado en UI | Guarda de proceso revisada en código; no se cerró ninguna app real. |
| 25 | Desinstalador oficial | No comprobado | No apareció un caso seguro de QA con desinstalador oficial. |
| 26 | Disco externo | No comprobado | Hay volúmenes montados, pero no se manipularon apps ni datos reales en ellos. |
| 27 | «Conservar» tras reanalizar y reiniciar | Corregido y verificado | UI actual: desmarca caché (3→2, 665→616 bytes), bloquea su casilla; aparece en Ajustes tras reiniciar y en un nuevo plan tras reanalizar. Se revocó al terminar. |
| 28 | Activar/desactivar cachés y logs | Comprobado y correcto en UI anterior | UI 0.20.3.0: toggles operados y restituidos; sin cambio de esta función en 0.20.4.0. |
| 29 | Activar/desactivar Xcode e instaladores | Comprobado y correcto en UI anterior | UI 0.20.3.0: toggles operados y restituidos; M: Xcode no incluye Archives. |
| 30 | Variar antigüedad de instaladores | Comprobado y correcto en UI anterior | UI 0.20.3.0: 90→91→90 días; M: instalador antiguo nunca autoseleccionado. |
| 31 | Añadir/retirar ubicación de prueba | Comprobado y correcto en UI anterior | UI 0.20.3.0: bookmark de carpeta QA añadido y retirado. |
| 32 | Espacio: tamaños y jerarquía | Comprobado y correcto | UI actual: carpeta QA de 1 KB, hijo de 1 KB y nombre con ñ visibles. |
| 33 | Espacio: tamaño mínimo | Corregido y verificado en UI | UI actual: 100 MB muestra «Sin resultados de espacio» y explica el filtro; vuelto a 0 MB. |
| 34 | Enlace simbólico | Comprobado y correcto | UI actual: enlace de 75 bytes, destino de 1 KB; M: no sigue destino. |
| 35 | Restaurar preferencias y borrar inventario | Comprobado parcialmente | UI 0.20.3.0: diálogos revisados y cancelados; M: borrar inventario conserva «Conservar». No se ejecutó reset global. |
| 36 | Cancelación a mitad y cobertura sin Acceso total al disco | Comprobado parcialmente | H: cancelación visual y cobertura parcial por Spotlight; M: cancelación/ausencia de evidencia. FDA no se retiró al usuario. |
| 37 | Rutas largas, nombres raros y muchos resultados | Comprobado parcialmente | UI actual: nombre con ñ y espacios y lista virtualizada de 100 candidatos tras limpiar. No se midió límite de ruta larga ni toda la lista masiva. |
| 38 | Otras partes de ZEUVE, teclado y VoiceOver | Comprobado parcialmente | UI actual: Inicio navegable mientras el Limpiador analiza; selector de carpeta operado con teclado. VoiceOver no comprobado. |

## Automatización y compilación

- `swift test --filter CleanerModuleTests`: 30/30 PASS tras las nuevas regresiones.
- `./Scripts/build_macos.sh Debug`: `BUILD SUCCEEDED` en Mac arm64; motores empaquetados y firma de la app verificados. El Debug usa firma ad hoc, por lo que Xcode indica Hardened Runtime desactivado para esta configuración.
- `./Scripts/build_macos.sh Release`: `BUILD SUCCEEDED` en Mac arm64; motores empaquetados y firma de la app verificados. No se creó ZIP ni se realizó notarización.
- `./Scripts/verify_project.sh`: PASS en macOS Apple Silicon. Suite Swift completa, 112 tests Python, verificadores documentales y Xcode Debug `BUILD SUCCEEDED`.

## Incidencia de automatización visual

En la vista **Resumen** tras un análisis general real, `cua_repl` devolvió `Sky Computer Use native pipe closed before response` al pedir el árbol de ZEUVE. Se repitió en 0.20.4.0. ZEUVE continuó como proceso activo; SQLite registró un análisis completo a las 19:34:40 UTC, sin ubicaciones inaccesibles. Finder siguió respondiendo al mismo controlador. Existen informes del mismo día de caída de `SkyComputerUseService` con `EXC_BREAKPOINT` en `Array.remove(at:)`, aunque no se pudo vincular inequívocamente uno de ellos a este intento. Filtrar la vista **Aplicaciones** antes del análisis permitió completar y observar la lista de la app QA, el plan de Limpieza y el ciclo Papelera/Deshacer. La evidencia señala el servicio de automatización como origen de la pérdida de conexión al leer Resumen, pero no prueba que esa pantalla funcione correctamente. Su revisión visual queda pendiente.

## Datos de QA

Carpeta creada y registrada: `/tmp/ZEUVE-Cleaner-QA-02040-20260924-2139`. Contenía un archivo de 1 KB con nombre especial y un symlink. Para el plan de desinstalación se crearon exclusivamente la app `~/Applications/ZEUVE Cleaner QA 02040.app`, la caché y el log `com.zeuve.qa.cleaner.02040`, una preferencia `.plist`, `~/Library/Application Support/ZEUVE Cleaner QA 02040` y una caché de control con sufijo `Extra`. Se registraron las rutas antes de crearlas, se confirmó que no existían y se compararon los SHA-256 de los dos objetos restaurados. Todas las rutas físicas QA fueron retiradas por nombre exacto; los registros de inventario, asociación, «Conservar», Undo e historial de la operación QA quedaron a cero. El mínimo de Espacio volvió a 0 MB. Las pruebas destructivas automatizadas usan directorios temporales únicos con `defer` de limpieza. No se eliminó ni desinstaló ningún archivo o app real del usuario.
