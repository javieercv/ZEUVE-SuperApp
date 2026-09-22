# Informe de implementación — ZEUVE 0.12.3

Fecha: 2026-09-03  
Build: 45  
Descargador universal: 0.7.3

## Alcance

Esta entrega aplica exclusivamente el Plan A aprobado de correcciones prioritarias. No introduce una refactorización transversal, nuevos motores, dependencias, APIs, telemetría, cambios de Sandbox ni nuevas conexiones de red.

## Cambios realizados

- `AppModel.start()` queda protegido frente a ejecuciones repetidas y mantiene un único observador de `OperationCoordinator`.
- Los fallos iniciales se acumulan para no ocultar un error de almacenamiento cuando también falla el registro de un módulo.
- `GlobalHistoryViewModel` mantiene el estado SwiftUI en `MainActor`, pero consulta, decodifica, combina y ordena el historial mediante trabajo separado del actor principal. Se conservan cancelación, filtro vigente, límite de 500 y unión del identificador universal con el histórico de YouTube.
- Los fallos al persistir el tema y los ajustes principales del Organizador se comunican al usuario en vez de descartarse con `try?`.
- La versión/build visible y el token HTTP propio de ZEUVE se obtienen mediante `ZEUVEProductInfo`, evitando literales obsoletos en servicios de red.
- Descargador universal, Analizador de chats y Comparador de seguidores usan errores explícitos de manifiesto cuando `manifest.json` no está disponible.
- Se elimina el caso muerto `activeOrUpcomingLive` y su mensaje de versión antigua.

## Descargador universal

Todos los perfiles incorporados de fábrica, incluido YouTube, quedan en `Original`, mejor calidad disponible y contenedor automático. Esto evita recodificación por defecto; la unión o remultiplexado de flujos originales sigue permitida cuando el origen entrega audio y vídeo separados.

El esquema de `UniversalDownloadProfiles` sube a 2. Al leer un esquema anterior, solo se sustituye el perfil de YouTube si coincide exactamente con la antigua configuración de fábrica MP3 320 kb/s. Resoluciones, formatos, audio u otras elecciones personalizadas se conservan.

El fallback de navegador automatizado se retira de Ajustes y del routing efectivo. La clave `useOptionalBrowserFallback` se sigue leyendo por compatibilidad y se normaliza a `false`. El marcador de motor `playwright-browser` no se elimina para no forzar una migración de recursos, pero ZEUVE 0.12.3 no lo ejecuta ni afirma que exista una ruta funcional.

## Limpieza del proyecto

`Scripts/clean_project.py` se incorpora a la documentación y validación como herramienta manual. Su modo predeterminado es simulación; `--apply` elimina únicamente artefactos regenerables dentro de la raíz validada y excluye `Resources/Engines`. Los logs solo se incluyen con `--include-logs`.

## Protección y compatibilidad

No cambian los identificadores persistentes legacy, el esquema SQLite, las cookies/sesiones, el Llavero, la política de archivos originales, `OperationCoordinator`, los argumentos de los motores existentes ni la publicación segura. No se crea un ZIP nuevo como parte de esta implementación.

## Actualización — restablecimiento global de ajustes (2026-09-07)

Se añade en Ajustes > General la acción confirmada «Restaurar todos los ajustes predeterminados». La coordinación se realiza desde `AppModel` y no mediante un borrado global de SQLite.

El restablecimiento devuelve el tema a Sistema y restaura los valores persistentes del Organizador, Descargador universal, Analizador de chats y Conversor universal. El Descargador conserva presets y perfiles personalizados por dominio, pero restablece los perfiles incorporados, elimina del Llavero la sesión de Instagram recordada y olvida el bookmark de salida actual y legacy. El Conversor conserva preajustes y favoritas y olvida únicamente su carpeta de salida recordada. Las carpetas recientes del Organizador, el historial, los motores/overrides y los archivos del usuario permanecen intactos.

La acción queda deshabilitada mientras exista actividad en cualquiera de los módulos coordinados. No altera silenciosamente una operación ya preparada: se restauran los valores predeterminados persistentes para operaciones futuras. Los errores de SQLite/Llavero se acumulan por área para que un fallo aislado no impida continuar con las demás restauraciones.

No se añaden dependencias, procesos externos, APIs ni conexiones de red.
## Actualización — saneamiento interno de mantenibilidad (2026-09-07)

Sin alterar comportamiento visible se centraliza la carga/validación de manifiestos en `ZEUVECore`, manteniendo la selección `Bundle.module`/`Bundle.main` y los errores `invalidManifest` propios de cada módulo. El Organizador pasa a exponer `OrganizerStorageKeys` y `AppModel` usa una constante de aplicación para el tema; todas las cadenas persistidas permanecen exactamente iguales, incluida `organizer.options` como compatibilidad legacy.

La ayuda contextual se reorganiza por dominio mediante extensiones de `ZEUVEHelpTopics`. Los 133 temas que residían en `ContextualHelp.swift` se conservaron sin cambios de contenido; el archivo común queda dedicado a los componentes de UI reutilizables. El proyecto Xcode se regeneró para incorporar los nuevos archivos.

Los logs generales de `UniversalDownloadService` se etiquetan ahora como `universal-downloader` y `universal-downloader-performance`, eliminando la categoría heredada `youtube` en un coordinador que también procesa Instagram, TikTok y páginas genéricas. No cambian mensajes, metadatos, privacidad, routing, motores ni archivos tratados.

No se añaden dependencias, conexiones de red, APIs, permisos, migraciones ni cambios de esquema.
## Actualización — infraestructura compartida y política de historial, Fase 2 (2026-09-07)

Se extraen a `ZEUVECore` el codec/resolución común de bookmarks de carpetas y el helper de acceso `security-scoped`. `DownloadOutputFolderBookmarkStore` y `ConverterOutputBookmarkStore` siguen siendo independientes y mantienen exactamente sus claves, migraciones, validadores y comportamiento de borrado; no existe migración de datos ni cambio de permisos.

`ZEUVEHistoryPersistence` formaliza la decisión aprobada de considerar el historial una persistencia secundaria. Organizador, Descargador universal, Conversor universal, Analizador de chats y Comparador de seguidores conservan un resultado principal correcto si solo falla su inserción en historial, muestran un aviso específico y registran únicamente el tipo técnico del error. En el Organizador, si no existe registro no se ofrece «Deshacer» para esa ejecución, sin revertir ni marcar como fallidos los movimientos ya terminados.

No se migra todavía la propiedad de `OperationCoordinator` entre capas. Se documenta la invariante para crecimiento modular: un solo propietario por operación, finalización garantizada en todos los caminos y preferencia por la capa de servicio en módulos nuevos cuando esta sea la propietaria real del trabajo pesado.

No se añaden dependencias, red, APIs, motores, cambios de esquema SQLite ni nuevas rutas de acceso a archivos.
## Actualización — integración central de módulos built-in, Fase 3 (2026-09-07)

Se añade `Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift` como fuente única de metadatos transversales para los cinco módulos oficiales. El catálogo conserva los IDs reales de cada target, el alias histórico `com.zeuve.youtube-downloader`, los órdenes visibles ya existentes, la presencia o ausencia de Ajustes, los títulos y atajos ⌘1–⌘5 y los presenters de historial. No introduce orden personalizable, ocultación de módulos ni atajos configurables.

`AppModel.start()` deja de registrar cinco manifiestos mediante llamadas independientes y recorre el catálogo. Tras el registro, la barra lateral, Inicio, Ajustes y el menú de comandos se construyen exclusivamente con módulos disponibles. Si una definición no puede cargar o registrar su manifiesto, el error se acumula en el aviso de arranque y no existe una ruta visible hacia esa herramienta.

`AppDestination` pasa a representar herramientas mediante `module(BuiltInModuleID)`. `BuiltInModuleViewRouter` contiene el único switch de vistas principales y entrega el ViewModel concreto a cada herramienta; `BuiltInModuleSettingsRouter` concentra el switch de contenidos persistentes de Ajustes. `ZEUVEApp` deja de inyectar globalmente los cinco ViewModels y `GlobalHistoryViewModel`. Los ViewModels siguen siendo propiedades tipadas de `AppModel`, sin reflexión, `Any` ni registro dinámico de objetos.

`GlobalHistoryViewModel` obtiene presenters y aliases desde el catálogo. El filtro del Descargador sigue reuniendo el historial actual y el antiguo identificador de YouTube, pero la lógica ya no contiene una condición específica de YouTube: combina de forma genérica todos los identificadores asociados al descriptor seleccionado.

Se conserva el orden previo de cada superficie. El Dashboard sigue respetando `manifest.presentation.order`; la barra lateral mantiene Organizador, Descargador, Analizador, Conversor e Instagram; Ajustes mantiene General y los cuatro módulos configurables; los comandos conservan ⌘1–⌘5 y el historial ⌘6. `Package.swift` y la lista de productos enlazados del generador Xcode permanecen explícitos porque son dependencias reales de compilación.

No se modifican módulos de negocio, motores, red, privacidad, SQLite, claves persistentes, bookmarks, formatos, archivos del usuario ni dependencias externas.


## Actualización — saneamiento por responsabilidades, Fase 4 (2026-09-07)

`ChatAnalyzerResultsView.swift` se reduce a la coordinación de resultados y las secciones visuales se distribuyen en `ZEUVEApp/ChatAnalyzer/Results`. `ChatAnalytics` mantiene el mismo namespace/API pública y reparte su implementación por dominios. Se conservaron algoritmos, filtros, snapshots, caches, invalidaciones, textos y composición visual.

El Conversor sustituye `UniversalConverterModels.swift` por archivos de modelos por responsabilidad, sin cambiar tipos públicos, claves `Codable`, migraciones ni formatos persistidos. El recolector de diagnóstico y monitor de progreso de FFmpeg pasan a `FFmpegProgressSupport.swift` manteniendo intacto el núcleo de ejecución.

El Descargador extrae su tarjeta de ajustes a `Views/UniversalDownloaderSettingsCard.swift`, sin opciones ni textos nuevos. Los ViewModels grandes de Descargador, Analizador y Conversor se revisaron y se mantuvieron unidos deliberadamente porque dividirlos habría ampliado estado privado y dispersado tareas/cancelación sin crear una frontera arquitectónica real.

Los tests estructurales y `verify_project.sh` se adaptan para comprobar las fuentes agregadas por responsabilidad y se añaden regresiones específicas de la nueva organización. No cambian manifiestos, IDs, almacenamiento, red, motores, privacidad, archivos del usuario ni versión/build.
## Actualización — Fase 5 de mantenibilidad (2026-09-07)

La quinta fase se limita a QA y herramientas de mantenimiento. No se modifica ningún archivo de `Sources/`, `Package.swift`, manifiesto, motor o esquema de persistencia. `Scripts/verify_project.sh` queda reducido a un orquestador estable y los 23 bloques Python existentes se trasladan íntegramente a verificadores por dominio bajo `Scripts/verify/`.

Se incorporan `app_sources.py` para el parseo automático de toda `ZEUVEApp`, `xcode_integration.py` para detectar diferencias entre SwiftPM, el generador Xcode y el `.pbxproj`, y `verify_app_macos.sh` para concentrar la comprobación real de motores + Xcode ARM64 en macOS. La comprobación de sintaxis Python pasa a abarcar todos los scripts/tests mediante `compileall`.

Se revisaron los archivos Swift de tests de mayor tamaño. No se fragmentaron los que comparten fixtures, helpers privados y un único contexto de prueba, porque hacerlo exigiría ampliar visibilidad o duplicar soporte únicamente por tamaño. La regla de mantenimiento queda documentada: dividir tests por responsabilidad real, no por número de líneas.

