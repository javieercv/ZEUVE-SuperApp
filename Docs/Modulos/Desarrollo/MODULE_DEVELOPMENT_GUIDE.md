# Guía de desarrollo de módulos de ZEUVE

Versión de la guía: 1.2
Compatible con ZEUVE: 0.20.4.0
API de módulos actual: 1.0

## 1. Objetivo

Esta guía explica cómo añadir un módulo oficial a ZEUVE sin romper el núcleo, la interfaz común ni las reglas de seguridad del proyecto. Está dirigida a desarrolladores humanos. Para encargar un módulo a otro chat, utiliza además `MODULE_CHAT_INSTRUCTIONS.md` y completa `MODULE_BRIEF_TEMPLATE.md`.

La arquitectura ya está preparada para que, en el futuro, el usuario pueda importar módulos. Esa importación todavía no existe. En la versión actual, los módulos oficiales se integran en el proyecto y se ejecutan como componentes incorporados (`builtIn`). Los módulos externos futuros deberán ejecutarse aislados (`isolatedProcess`) y comunicarse mediante la API JSON.

## 2. Principios obligatorios

Todo módulo debe:

- integrarse en el proyecto actual, no crear otra aplicación;
- mantener Swift como núcleo de ZEUVE, sin prohibir Python, Rust u otras tecnologías cuando sean la mejor solución concreta;
- separar interfaz, lógica de negocio, persistencia y motores externos;
- utilizar servicios comunes de ZEUVE cuando existan;
- pedir solo los permisos que realmente necesita;
- proteger los originales y evitar sobrescrituras silenciosas;
- ofrecer vista previa antes de acciones masivas;
- mantener la interfaz respondiendo durante procesos largos;
- informar progreso real o progreso indeterminado honesto;
- admitir cancelación segura cuando sea técnicamente posible;
- guardar ajustes, historial y registros localmente;
- permanecer offline salvo que su propia función necesite Internet;
- estar en español en toda la interfaz visible;
- incluir pruebas, documentación y actualización del `CHANGELOG.md`;
- mantenerse integrado en la única carpeta activa de ZEUVE y empaquetarse solo cuando el usuario solicite expresamente un ZIP.

Las reglas permanentes de `SUPERAPP_PROJECT_RULES.md` prevalecen sobre esta guía.

## 3. Capas del proyecto

```text
ZEUVEApp
  SwiftUI/AppKit, navegación y ViewModels
        ↓
ZEUVECore · ZEUVEOperations · ZEUVEStorage
  contratos, operaciones, ajustes, historial y registros
        ↓
<Nombre>Module
  modelos, validación y lógica de negocio sin SwiftUI
        ↓
Foundation / APIs nativas / motores auxiliares aprobados
```

### `ZEUVECore`

Contiene contratos compartidos y estables:

- `ModuleManifest`;
- permisos, capacidades, tecnología y modo de ejecución;
- `ModuleRequest` y `ModuleEvent`;
- modelos de operación y progreso;
- `FileFingerprint`;
- `AppPaths`;
- `LocalLogger`.

Un módulo no debe copiar estos tipos ni crear variantes incompatibles.

### `ZEUVEOperations`

`OperationCoordinator` permite una sola operación pesada a la vez. Todo módulo pesado debe usar la instancia compartida de `AppModel`, no crear su propio coordinador global.

### `ZEUVEStorage`

Proporciona:

- `SettingsRepository` para opciones locales;
- `HistoryRepository` para historial estructurado;
- SQLite y migraciones.

Las claves de ajustes deben llevar el prefijo del módulo, por ejemplo:

```text
chatAnalyzer.options
chatAnalyzer.lastFolder
converter.selectedPreset
```

### `<Nombre>Module`

Debe contener lógica independiente de SwiftUI y AppKit siempre que sea razonable. Esto permite probarla sin abrir la aplicación y reutilizarla en una futura ejecución aislada.

### `ZEUVEApp`

Contiene la integración visual:

- ViewModel del módulo;
- vistas SwiftUI;
- selectores o integraciones AppKit;
- navegación y registro del módulo.

La lógica pesada no debe ejecutarse en `@MainActor`.

## 4. Elección de tecnología

No se impone un único lenguaje a todos los módulos.

### Swift

Es la opción predeterminada para:

- interfaz;
- acceso a macOS y Finder;
- organización y validación de archivos;
- persistencia y coordinación;
- procesamiento que las APIs nativas cubran bien.

### Python

Puede utilizarse cuando su ecosistema aporte una ventaja clara, por ejemplo:

- `yt-dlp`;
- librerías de análisis especializadas;
- procesamiento que sería costoso o frágil reimplementar.

No debe obligar al usuario final a instalar Python. Debe empaquetarse como ejecutable o entorno aislado aprobado.

### Rust, C o C++

Solo cuando exista una necesidad demostrada:

- algoritmo CPU-intensivo;
- biblioteca ya disponible;
- tratamiento binario de alto rendimiento;
- aislamiento de memoria o rendimiento medido.

### Motores externos

FFmpeg, Pandoc, Deno u otros motores aprobados pueden emplearse con autorización. Calibre, Ghostscript y LibreOffice están retirados y no deben reintroducirse sin una nueva aprobación de alcance. Deben incluirse dentro de la aplicación cuando sea viable y ejecutarse sin shell, con argumentos separados y validados.

Antes de añadir una dependencia importante debe documentarse tamaño, compatibilidad ARM64, funcionamiento offline, permisos, empaquetado y comportamiento cuando no esté disponible.

## 5. Estructura de un módulo oficial

Ejemplo para un módulo llamado `ChatAnalyzer`:

```text
Sources/
├── ChatAnalyzerModule/
│   ├── ChatAnalyzerModuleDefinition.swift
│   ├── ChatAnalyzerModels.swift
│   ├── ChatAnalyzerService.swift
│   ├── ChatAnalyzerErrors.swift
│   └── Resources/
│       └── manifest.json
└── ZEUVEApp/
    └── ChatAnalyzer/
        ├── ChatAnalyzerViewModel.swift
        ├── ChatAnalyzerView.swift
        └── ...

Tests/
└── ChatAnalyzerModuleTests/
    └── ...
```

La carpeta del módulo no debe importar SwiftUI. Las vistas sí pueden importar el producto del módulo y los servicios comunes necesarios.

Cuando una vista, modelo, analizador o servicio crezca, debe dividirse por **responsabilidad real**, no por un objetivo de número de líneas. Son fronteras válidas, por ejemplo, secciones visuales independientes, familias de modelos con API estable o helpers técnicos autónomos. No debe repartirse un ViewModel en extensiones/archivos si ello obliga a ampliar estado `private`, dispersa la propiedad de tareas o cancelación o crea coordinadores sin responsabilidad propia. Un archivo grande puede mantenerse unido cuando representa un ciclo de vida cohesionado.

## 6. Crear el manifiesto

Cada módulo incorpora `Resources/manifest.json`. Ejemplo:

```json
{
  "schemaVersion": 1,
  "identifier": "com.zeuve.chat-analyzer",
  "name": "Analizador de chats",
  "summary": "Analiza conversaciones exportadas de forma local.",
  "version": "0.2.0",
  "minimumZEUVEVersion": "0.2.0",
  "moduleAPI": "1.0",
  "technology": "swift",
  "executionMode": "builtIn",
  "permissions": ["readUserSelectedFiles"],
  "capabilities": ["progress", "cancellation", "history", "dragAndDrop"],
  "presentation": {
    "systemImage": "bubble.left.and.bubble.right",
    "category": "Análisis",
    "order": 20
  }
}
```

Reglas:

- el identificador debe ser único y estable;
- las versiones de los módulos usan `MAJOR.MINOR.PATCH`; la aplicación ZEUVE usa `MAJOR.MINOR.PATCH.REVISION` desde 0.13.1.0;
- `moduleAPI` es `1.0` mientras no se apruebe otra versión;
- `minimumZEUVEVersion` debe reflejar la primera versión compatible real;
- se declaran únicamente permisos y capacidades implementados;
- el icono debe ser un símbolo SF Symbols válido mientras no exista recurso propio;
- el manifiesto debe validarse mediante `ModuleManifest.validate()`.
- los módulos built-in deben reutilizar `ModuleManifestLoader` para decodificar y validar `manifest.json`, conservando el error específico del módulo cuando el recurso falta.

Los valores admitidos se documentan en `MODULE_API.md`.

## 7. Añadir el target a Swift Package Manager

En `Package.swift`:

1. añade un producto de biblioteca;
2. añade el target con sus dependencias mínimas;
3. procesa `Resources` si contiene manifiesto u otros recursos;
4. añade un `testTarget` específico.

Ejemplo:

```swift
.library(name: "ChatAnalyzerModule", targets: ["ChatAnalyzerModule"])
```

```swift
.target(
    name: "ChatAnalyzerModule",
    dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations"],
    path: "Sources/ChatAnalyzerModule",
    resources: [.process("Resources")]
)
```

No añadas dependencias por comodidad. Si el módulo no usa almacenamiento o coordinación, no debe depender de ellos.

Después actualiza `Scripts/generate_xcode_project.py` para que el producto se enlace al target de la aplicación y regenera `ZEUVE.xcodeproj`. `Scripts/verify/xcode_integration.py`, ejecutado por `verify_project.sh`, compara automáticamente los productos de biblioteca de `Package.swift`, la lista del generador y el `.pbxproj`; si se añade un producto a SwiftPM y se olvida enlazarlo en Xcode, la verificación debe fallar.

## 8. Definición y registro

Crea una definición similar a `OrganizerModuleDefinition` que cargue, decodifique y valide el manifiesto.

Para un módulo oficial `builtIn`, añade un descriptor a `Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift`. El descriptor referencia su función de carga de manifiesto y concentra el ID principal, aliases legacy aprobados, orden de navegación existente, presencia en Ajustes, comando/atajo y presenters de historial. `AppModel` recorre ese catálogo y registra los manifiestos en la instancia compartida de `ModuleRegistry`; no añadas otra lista manual de registros.

El registro debe fallar con un mensaje comprensible si:

- el manifiesto no existe;
- el JSON no es válido;
- el identificador no coincide con el descriptor;
- el identificador está duplicado;
- la versión de esquema o API no es compatible.

Un módulo que no se registra correctamente no aparece en Inicio, barra lateral, Ajustes ni comandos. No añadas un descriptor visible mientras la herramienta no tenga funcionalidad real y navegación disponible.

## 9. Integración visual

La interfaz debe usar componentes y patrones comunes de ZEUVE:

- navegación lateral;
- títulos, espaciado y tarjetas coherentes;
- modo claro, oscuro y del sistema;
- selector tradicional más arrastrar y soltar cuando sea útil;
- mensajes en español;
- controles deshabilitados de forma comprensible durante operaciones;
- confirmación antes de acciones masivas;
- resumen final.

La vista principal del módulo se añade al `BuiltInModuleViewRouter`, que inyecta únicamente el ViewModel concreto que necesita la herramienta. Si el módulo aporta configuración persistente, añade también su caso al `BuiltInModuleSettingsRouter` y declara esa capacidad de integración en el descriptor. No dupliques el módulo en `RootView`, `DashboardView`, `ZEUVEApp` o `GlobalHistoryViewModel`.

El ViewModel puede ser `@MainActor`, pero debe enviar las tareas pesadas a una tarea separada o proceso aislado. Solo las actualizaciones de estado visual deben permanecer en el actor principal.

## 10. Operaciones, progreso y cancelación

Flujo recomendado:

1. validar entradas sin modificar archivos;
2. solicitar inicio a `OperationCoordinator.begin`;
3. guardar el identificador de operación;
4. ejecutar la lógica pesada fuera del actor principal;
5. publicar `OperationProgress` real;
6. actualizar el coordinador compartido;
7. atender la cancelación;
8. limpiar temporales o revertir cambios incompletos;
9. persistir el historial como efecto secundario controlado;
10. garantizar la finalización del coordinador y mostrar el resumen.

Cada operación debe tener **un único propietario** del ciclo `begin/update/requestCancellation/finish`. Para módulos nuevos se prefiere que ese propietario sea el servicio que ejecuta la operación pesada. Una orquestación en `ZEUVEApp` es válida cuando la propia capa App coordina varias responsabilidades, pero no debe existir un segundo propietario dentro del servicio. El propietario debe liberar siempre el coordinador en éxito, error y cancelación.

El historial no puede decidir retrospectivamente que una operación principal ya completada ha fallado. Usa `ZEUVEHistoryPersistence` o la política equivalente aprobada: si solo falla el guardado de historial, conserva el resultado, muestra «Aviso» y registra únicamente metadatos técnicos saneados. Si el historial era necesario para una acción posterior —por ejemplo «Deshacer»— esa acción se deshabilita para esa ejecución concreta.

`OperationProgress.total` debe ser `nil` cuando no exista un total fiable. No se simulan porcentajes.

La cancelación debe diferenciar:

- solicitud de cancelación;
- fase cancelable;
- fase no cancelable temporalmente;
- elementos completados;
- resultados conservados;
- temporales eliminados.

## 11. Protección de archivos

Para transformaciones y conversiones:

- abrir originales en lectura;
- escribir primero en una ubicación temporal;
- validar el resultado;
- publicar mediante movimiento atómico cuando sea posible;
- no reemplazar destinos sin confirmación;
- eliminar resultados incompletos al fallar o cancelar.

Para movimientos y renombrados:

- generar vista previa;
- registrar origen y destino;
- comprobar que el origen no cambió;
- gestionar conflictos;
- registrar cada movimiento completado;
- revertir en orden inverso si falla el lote;
- ofrecer deshacer únicamente cuando sea seguro.

Ninguna operación puede afectar archivos fuera de las ubicaciones seleccionadas por el usuario.

## 12. Persistencia

### Ajustes

Usa `SettingsRepository` para valores pequeños y codificables. Cada clave debe pertenecer al espacio de nombres del módulo.

Todos los ajustes persistentes del módulo deben registrarse dentro del apartado general Ajustes de ZEUVE. No crees ruedas, botones o ventanas independientes de configuración dentro de la herramienta. Separa siempre los valores predeterminados persistentes de las opciones de la operación actual. Cambiar un predeterminado no debe modificar silenciosamente una operación ya preparada o en curso.

Un módulo puede conservar selectores rápidos para aplicar presets o perfiles, pero su creación, edición, eliminación y restauración debe realizarse en Ajustes. Diagnósticos, carpetas recientes y preferencias avanzadas persistentes también pertenecen a la sección de Ajustes del módulo.

Un fallo al guardar una preferencia secundaria no debe destruir una operación válida, pero debe registrarse si afecta al diagnóstico.

### Historial

Usa `HistoryRepository` o un servicio del módulo que lo encapsule. El historial no debe guardar contenido personal completo si basta con metadatos operativos. Su persistencia es secundaria al resultado principal: un fallo exclusivo de historial se comunica como aviso y no convierte una operación ya completada en fallida.

### Presets y favoritas

Solo declares las capacidades `presets` o `favorites` cuando estén implementadas de extremo a extremo: interfaz, persistencia, edición y eliminación.

## 13. Registros y errores

Usa `LocalLogger` para detalles técnicos. Sus llamadas devuelven la URL del archivo escrito; si se ignora deliberadamente, usa:

```swift
_ = try? await logger?.write(...)
```

Los errores visibles deben explicar:

- qué ocurrió;
- qué archivo u operación se vio afectada;
- si el lote puede continuar;
- qué puede hacer el usuario.

No muestres trazas técnicas directamente en la interfaz.

## 14. Módulos con Internet

Un módulo online debe documentar y mostrar claramente:

- qué servidor utiliza;
- qué datos envía;
- qué recibe;
- qué almacena;
- qué ocurre sin conexión;
- si la conexión es opcional;
- riesgos de privacidad.

Debe declarar `networkAccess`. Cookies, contenido web, portapapeles o apertura externa requieren sus permisos específicos.

## 15. Procesos aislados y API JSON

La importación externa todavía no está implementada. No inventes un cargador ni una tienda sin autorización.

Cuando un módulo necesite un proceso auxiliar, debe diseñarse pensando en el contrato:

```text
ZEUVE → ModuleRequest → proceso
ZEUVE ← ModuleEvent   ← proceso
```

Requisitos:

- mensajes JSON delimitados y versionados;
- `requestID` conservado en todos los eventos;
- `sequence` creciente;
- un único evento terminal: `result`, `failure` o `cancelled`;
- salida estándar reservada al protocolo;
- detalles técnicos en stderr o logs;
- sin aceptar rutas no autorizadas;
- cierre y limpieza de procesos descendientes.

La especificación está en `MODULE_API.md`.

## 16. Pruebas mínimas

Todo módulo debe probar:

- manifiesto válido;
- funcionamiento normal;
- entradas vacías o incompatibles;
- archivos dañados;
- falta de permisos;
- conflictos de nombres;
- cancelación;
- limpieza de temporales;
- preservación de originales;
- validación de que un proceso terminado correctamente ha producido resultados reales y válidos;
- número, orden y tipo de resultados cuando una entrada pueda generar varios archivos;
- fallbacks sin mezcla de resultados parciales entre intentos;
- rutas públicas antes de credenciales o sesiones cuando intervengan motores online;
- lotes grandes cuando sea viable;
- progreso;
- historial y presets relacionados;
- integración con `OperationCoordinator`;
- errores parciales sin detener el lote cuando sea seguro.

Además:

- ejecuta `swift test`;
- ejecuta `./Scripts/verify_project.sh`;
- compila la app con Xcode en macOS;
- prueba manualmente navegación, selectores, arrastrar y soltar, progreso y cancelación;
- no afirmes que la app se abrió si no se abrió realmente.

## 17. Versionado y entrega

- módulo o función importante: incrementa `MINOR`;
- corrección pequeña: incrementa `PATCH`;
- cambio incompatible: incrementa `MAJOR` cuando proceda.

Actualiza siempre:

- `VERSION`;
- versión visible en ajustes;
- `MARKETING_VERSION` y número de compilación;
- manifiestos afectados;
- `CHANGELOG.md`;
- README y documentación relacionada;
- informes de pruebas y entrega.

La entrega normal actualiza directamente la única carpeta activa del proyecto. No se crea un ZIP ni otra carpeta versionada salvo petición expresa del usuario. Cuando se solicite un ZIP, debe contener el proyecto completo y excluir `.build`, `build`, `dist`, `.swiftpm`, `DerivedData`, cachés, `.DS_Store`, `._*`, `__MACOSX`, `xcuserdata`, logs y datos privados.

## 18. Lista de integración rápida

1. Completar el brief del módulo.
2. Analizar la carpeta activa y los archivos reales más recientes.
3. Presentar plan y esperar aprobación.
4. Crear target y manifiesto.
5. Implementar lógica sin interfaz.
6. Añadir pruebas del módulo.
7. Crear ViewModel y vistas.
8. Añadir el descriptor al `BuiltInModuleCatalog` y su vista al router built-in.
9. Añadir el router de Ajustes solo si existen preferencias persistentes; declarar presenters/aliases de historial en el catálogo cuando corresponda.
10. Comprobar que la navegación solo aparece tras registrar correctamente el manifiesto.
11. Integrar operación, progreso, cancelación, logs e historial.
12. Regenerar Xcode.
13. Ejecutar pruebas y compilaciones.
14. Actualizar versión y documentación cuando corresponda al alcance aprobado.
15. Mantener limpia la carpeta activa y empaquetarla únicamente si el usuario solicita un ZIP.

## Módulos de mantenimiento local (0.20.0.0)

Un módulo aprobado que inspeccione ubicaciones no elegidas individualmente debe declarar `scanLocalStorage`. Si además puede retirar elementos, declara `removeLocalItems`. Estas capacidades no son intercambiables: el scan solo descubre y clasifica; la modificación exige plan visible, selección explícita y revalidación. Los tests deben inyectar raíces/providers temporales y no escanear o limpiar el Mac real.
