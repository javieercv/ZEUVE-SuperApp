# Lista de comprobación para módulos de ZEUVE

Marca cada punto antes de considerar terminada una entrega.

## Análisis y aprobación

- [ ] Se ha utilizado el ZIP más reciente como fuente de verdad.
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
- [ ] Las versiones usan `MAJOR.MINOR.PATCH`.
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
- [ ] El manifiesto se registra en `ModuleRegistry`.
- [ ] La navegación solo aparece si el módulo funciona.
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
- [ ] Se ha comprobado la integridad de los originales.
- [ ] Se ha probado un lote grande cuando es viable.
- [ ] Se han probado progreso, historial y presets relacionados.
- [ ] `swift test` pasa.
- [ ] `./Scripts/verify_project.sh` pasa.
- [ ] Xcode compila en macOS Apple Silicon.
- [ ] La app compilada se ha abierto o se declara claramente que no se pudo abrir.
- [ ] Se han hecho pruebas manuales de interfaz afectada.

## Documentación y entrega

- [ ] Se han actualizado `VERSION`, ajustes, Xcode y manifiestos afectados.
- [ ] Se ha actualizado `CHANGELOG.md`.
- [ ] Se ha actualizado README y documentación técnica.
- [ ] Existe informe de pruebas.
- [ ] Existe informe de entrega.
- [ ] El ZIP contiene el proyecto completo.
- [ ] El ZIP no contiene `.build`, `build`, `dist`, `.swiftpm`, `.DS_Store`, `__MACOSX`, `xcuserdata`, logs o datos privados.
- [ ] El informe final distingue implementado, probado, compilado, abierto y no comprobado.
