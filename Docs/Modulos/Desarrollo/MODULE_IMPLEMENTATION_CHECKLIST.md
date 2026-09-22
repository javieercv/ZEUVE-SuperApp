# Lista de comprobación para módulos de ZEUVE

Marca cada punto antes de considerar terminada una entrega.

## Análisis y aprobación

- [ ] Se ha utilizado la carpeta activa y sus archivos reales como fuente de verdad.
- [ ] Se han leído `SUPERAPP_PROJECT_RULES.md` y `PROJECT_DECISIONS.md`.
- [ ] Se ha completado el brief del módulo.
- [ ] Se ha presentado un plan basado en archivos reales.
- [ ] Se han explicado tecnología, dependencias, Internet, permisos y riesgos.
- [ ] El usuario ha aprobado expresamente el plan.

## Arquitectura

- [ ] El módulo se integra en ZEUVE y no crea una aplicación paralela.
- [ ] Existe un target propio en `Package.swift`.
- [ ] La lógica de negocio está separada de SwiftUI/AppKit.
- [ ] Se reutilizan `ZEUVECore`, `ZEUVEOperations` y `ZEUVEStorage` cuando corresponde.
- [ ] No existe un coordinador global duplicado.
- [ ] Las tareas pesadas no bloquean `@MainActor`.
- [ ] La tecnología elegida está justificada.
- [ ] Los procesos auxiliares están aislados y controlados cuando corresponde.

## Manifiesto

- [ ] `Resources/manifest.json` existe.
- [ ] `schemaVersion` es compatible.
- [ ] El identificador es único y estable.
- [ ] La versión del módulo usa `MAJOR.MINOR.PATCH`; la versión de la aplicación ZEUVE usa `MAJOR.MINOR.PATCH.REVISION`.
- [ ] `minimumZEUVEVersion` es correcta.
- [ ] `moduleAPI` es compatible.
- [ ] Se declara la tecnología real.
- [ ] Se declara el modo de ejecución real.
- [ ] Solo se solicitan permisos necesarios.
- [ ] Solo se declaran capacidades completamente implementadas.
- [ ] `ModuleManifest.validate()` pasa.

## Integración

- [ ] El producto del módulo está enlazado en el proyecto Xcode.
- [ ] El proyecto Xcode se ha regenerado.
- [ ] La coherencia SwiftPM/generador Xcode/`.pbxproj` pasa.
- [ ] El módulo oficial tiene un único descriptor en `BuiltInModuleCatalog` con ID, aliases aprobados, orden, Ajustes, comando/atajo e historial cuando corresponda.
- [ ] El manifiesto se registra en `ModuleRegistry` a través del catálogo, sin otra lista manual en `AppModel`.
- [ ] La vista principal está integrada en `BuiltInModuleViewRouter`; Ajustes usa `BuiltInModuleSettingsRouter` solo si hay configuración persistente.
- [ ] La navegación, Inicio, Ajustes y comandos solo ofrecen el módulo si su manifiesto se registra correctamente.
- [ ] Los aliases de historial legacy se declaran en el descriptor y no mediante ramas específicas en `GlobalHistoryViewModel`.
- [ ] Toda la interfaz está en español.
- [ ] El diseño es coherente con el resto de ZEUVE.
- [ ] Existen modo simple y avanzado cuando aportan valor.
- [ ] El selector tradicional y arrastrar/soltar se complementan cuando procede.
- [ ] Los ajustes persistentes del módulo están integrados en el apartado general Ajustes.
- [ ] La herramienta no contiene ruedas, botones ni ventanas independientes de configuración.
- [ ] Los valores predeterminados están separados de las opciones de la operación actual.
- [ ] Presets, diagnósticos y preferencias persistentes se administran desde la sección de Ajustes del módulo.

## Operaciones y archivos

- [ ] Las acciones masivas tienen vista previa.
- [ ] Existe confirmación antes de modificar archivos.
- [ ] Los originales se protegen según las reglas del módulo.
- [ ] Los conflictos tienen una opción segura por defecto.
- [ ] Los temporales se crean en ubicaciones apropiadas.
- [ ] Los resultados se validan antes de publicarse.
- [ ] Un código de salida correcto no se acepta sin resultados reales, no vacíos y válidos.
- [ ] Las entradas compuestas conservan todos los resultados esperados, su orden y su tipo.
- [ ] Un fallback limpia sus parciales y no mezcla salidas de intentos distintos.
- [ ] La operación no afecta rutas fuera de la selección del usuario.
- [ ] El progreso es real o indeterminado honesto.
- [ ] La cancelación es segura.
- [ ] La cancelación limpia incompletos y temporales.
- [ ] El resumen final informa correctos, omitidos, fallidos y cancelados.
- [ ] Se ofrece deshacer solo cuando es realmente seguro.

## Persistencia y privacidad

- [ ] Las claves de ajustes usan el prefijo del módulo.
- [ ] Historial y presets son locales.
- [ ] No se almacena contenido personal innecesario.
- [ ] Los registros son locales y comprensibles.
- [ ] No existe telemetría ni analítica.
- [ ] Las funciones locales funcionan offline.
- [ ] El uso de Internet está aprobado y documentado.
- [ ] Los permisos online o sensibles están declarados.
- [ ] Las rutas públicas razonables se agotan antes de utilizar credenciales o sesiones.
- [ ] Los errores ambiguos no se clasifican automáticamente como contenido privado.

## Errores y calidad

- [ ] Los errores visibles explican el problema y la acción recomendada.
- [ ] Las trazas técnicas no se muestran como único mensaje.
- [ ] Un archivo fallido no detiene todo el lote cuando sea seguro continuar.
- [ ] No existen botones falsos, `TODO`, datos ficticios ni rutas incompletas.
- [ ] No se han modificado partes no relacionadas.
- [ ] No se han ocultado advertencias del compilador sin resolver su causa.

## Pruebas

- [ ] Existen pruebas automáticas específicas.
- [ ] Se han probado entradas normales y límites.
- [ ] Se han probado formatos incompatibles o dañados.
- [ ] Se ha probado falta de permisos.
- [ ] Se han probado conflictos.
- [ ] Se ha probado cancelación y limpieza.
- [ ] Se han probado resultados vacíos, incompletos y fallbacks de motores cuando corresponda.
- [ ] Se ha comprobado número, orden, tipo y formato de las salidas múltiples.
- [ ] Se han probado lotes heterogéneos cuando la política automática depende de cada elemento.
- [ ] Se ha comprobado la integridad de los originales.
- [ ] Se ha probado un lote grande cuando es viable.
- [ ] Se han probado progreso, historial y presets relacionados.
- [ ] `swift test` pasa.
- [ ] `./Scripts/verify_project.sh` pasa.
- [ ] `Scripts/verify_app_macos.sh` se ha ejecutado en macOS Apple Silicon o su omisión se declara expresamente.
- [ ] Xcode compila en macOS Apple Silicon.
- [ ] La app compilada se ha abierto o se declara claramente que no se pudo abrir.
- [ ] Se han hecho pruebas manuales de interfaz afectada.

## Documentación y entrega

- [ ] Se han actualizado `VERSION`, ajustes, Xcode y manifiestos afectados.
- [ ] Se ha actualizado `CHANGELOG.md`.
- [ ] Se ha actualizado README y documentación técnica.
- [ ] Existe informe de pruebas.
- [ ] Existe informe de entrega.
- [ ] Se ha actualizado la única carpeta activa sin crear copias versionadas innecesarias.
- [ ] Si se solicitó un ZIP, contiene el proyecto completo.
- [ ] Si se solicitó un ZIP, no contiene `.build`, `build`, `dist`, `.swiftpm`, `DerivedData`, cachés, `.DS_Store`, `._*`, `__MACOSX`, `xcuserdata`, logs o datos privados.
- [ ] El informe final distingue implementado, probado, compilado, abierto y no comprobado.

## Checklist adicional para mantenimiento local

- [ ] `scanLocalStorage` y `removeLocalItems` se declaran solo si el comportamiento real los necesita.
- [ ] El análisis y la eliminación están separados por un plan visible y revisable.
- [ ] Los scans recursivos no siguen symlinks.
- [ ] Datos persistentes/compartidos no se autoseleccionan.
- [ ] La ejecución revalida justo antes de modificar.
- [ ] Los tests usan raíces/providers temporales y no inspeccionan el Mac real.
- [ ] Si existe Undo, no sobrescribe rutas ocupadas y verifica la identidad del objeto restaurado.
