# API de módulos de ZEUVE 1.0

Estado: contrato base implementado.  
Versión de esquema de manifiesto: `1`.  
Versión de protocolo: `1.0`.

## 1. Alcance actual

ZEUVE 0.7.0 registra módulos oficiales incorporados mediante `ModuleRegistry`. El Organizador, el Descargador de YouTube, el Analizador de chats y el Conversor universal son módulos oficiales reales.

El contrato también define mensajes para procesos aislados, pero la instalación e importación de módulos externos todavía no está implementada. No debe presentarse esa función como disponible.

## 2. `ModuleManifest`

El manifiesto describe el módulo sin depender del lenguaje en que esté desarrollado.

| Campo | Tipo | Obligatorio | Regla |
|---|---|---:|---|
| `schemaVersion` | entero | sí | Actualmente `1`. |
| `identifier` | cadena | sí | Único y estable; formato tipo `com.zeuve.organizer`. |
| `name` | cadena | sí | Nombre visible no vacío. |
| `summary` | cadena | sí | Descripción breve visible. |
| `version` | cadena | sí | SemVer `MAJOR.MINOR.PATCH`. |
| `minimumZEUVEVersion` | cadena | sí | SemVer de la primera versión compatible. |
| `moduleAPI` | cadena | sí | Actualmente `1.0`. |
| `technology` | enum | sí | Tecnología principal o combinada. |
| `executionMode` | enum | sí | `builtIn` o `isolatedProcess`. |
| `permissions` | array | sí | Solo permisos necesarios. |
| `capabilities` | array | sí | Solo capacidades implementadas. |
| `presentation` | objeto | sí | Icono, categoría y orden. |

La validación actual comprueba:

- esquema igual a `1`;
- identificador válido;
- nombre no vacío;
- versiones semánticas;
- API igual a `1.0`;
- ausencia de identificadores duplicados en el registro.

### Identificador

Expresión admitida:

```text
^[a-zA-Z0-9]+([.-][a-zA-Z0-9]+)+$
```

Recomendación:

```text
com.zeuve.<nombre-estable>
```

No cambies el identificador al renombrar el nombre visible del módulo, porque se utilizará para historial, ajustes, permisos y compatibilidad.

## 3. Tecnologías

Valores de `ModuleTechnology`:

| Valor | Uso previsto |
|---|---|
| `swift` | Módulo implementado principalmente en Swift. |
| `python` | Motor principal Python empaquetado. |
| `rust` | Motor principal Rust. |
| `executable` | Herramienta autónoma no descrita por otro valor. |
| `web` | Contenido web aprobado como parte esencial. |
| `mixed` | Varias tecnologías con responsabilidad relevante. |

Este campo describe; no concede permisos ni decide por sí solo el aislamiento.

## 4. Modos de ejecución

### `builtIn`

Módulo oficial integrado en el proyecto y enlazado a la app. Es el único modo funcional para módulos completos en ZEUVE 0.7.0.

### `isolatedProcess`

Contrato reservado para módulos o motores que se ejecutarán en un proceso separado. La infraestructura de importación de módulos externos todavía está pendiente.

No debe cargarse código externo arbitrario dentro del proceso principal.

## 5. Permisos

Valores de `ModulePermission`:

| Valor | Significado |
|---|---|
| `readUserSelectedFiles` | Leer archivos o carpetas elegidos explícitamente. |
| `writeUserSelectedFolder` | Escribir en una carpeta elegida. |
| `persistentFolderAccess` | Recordar acceso a una carpeta entre sesiones. |
| `networkAccess` | Realizar conexiones de red. |
| `executeBundledTools` | Ejecutar herramientas incluidas con la app. |
| `webContent` | Mostrar o procesar contenido web. |
| `browserCookies` | Acceder a cookies de navegador con autorización. |
| `clipboard` | Leer o escribir el portapapeles. |
| `openExternalApplications` | Abrir navegador, Finder u otras aplicaciones. |

Declarar un permiso no lo concede automáticamente. El núcleo y la interfaz deben aplicar la autorización real. Los futuros módulos importables deberán mostrar estos permisos antes de instalarse.

## 6. Capacidades

Valores de `ModuleCapability`:

| Valor | Compromiso funcional |
|---|---|
| `preview` | Ofrece vista previa antes de ejecutar. |
| `progress` | Publica progreso real o indeterminado. |
| `cancellation` | Permite cancelar de forma segura. |
| `history` | Guarda historial local. |
| `presets` | Permite crear, cargar, editar y borrar presets. |
| `favorites` | Permite guardar configuraciones favoritas. |
| `undo` | Puede revertir operaciones de forma segura. |
| `dragAndDrop` | Admite arrastrar y soltar. |
| `diagnostics` | Ofrece diagnóstico adicional al usuario. |

No declares una capacidad que solo esté parcialmente implementada.

## 7. Presentación

`ModulePresentation` contiene:

- `systemImage`: nombre de SF Symbol;
- `category`: categoría visible en español;
- `order`: prioridad de orden ascendente.

Si dos módulos tienen el mismo orden, `ModuleRegistry.all()` los ordena por nombre.

## 8. Ejemplo de manifiesto

```json
{
  "schemaVersion": 1,
  "identifier": "com.zeuve.organizer",
  "name": "Organizador de archivos",
  "summary": "Clasifica, revisa y organiza archivos de forma segura.",
  "version": "0.2.0",
  "minimumZEUVEVersion": "0.1.0",
  "moduleAPI": "1.0",
  "technology": "swift",
  "executionMode": "builtIn",
  "permissions": [
    "readUserSelectedFiles",
    "writeUserSelectedFolder"
  ],
  "capabilities": [
    "preview",
    "progress",
    "cancellation",
    "history",
    "undo",
    "dragAndDrop"
  ],
  "presentation": {
    "systemImage": "folder.badge.gearshape",
    "category": "Archivos",
    "order": 10
  }
}
```

## 9. Registro de módulos

`ModuleRegistry` es un actor compartido.

Operaciones públicas:

- `register(_:)`: valida y rechaza duplicados;
- `replace(_:)`: valida y sustituye por identificador;
- `manifest(identifier:)`: consulta un módulo;
- `all()`: devuelve módulos ordenados.

Los módulos oficiales se registran durante el arranque de `AppModel`. No crees un registro independiente por módulo.

## 10. `ModuleRequest`

Petición para un proceso aislado futuro:

```swift
public struct ModuleRequest: Codable, Sendable, Equatable {
    let protocolVersion: String
    let requestID: UUID
    let moduleID: String
    let action: String
    let payload: [String: JSONValue]
}
```

Reglas:

- `protocolVersion`: actualmente `1.0`;
- `requestID`: correlaciona petición y eventos;
- `moduleID`: debe coincidir con el manifiesto;
- `action`: nombre estable definido por el módulo;
- `payload`: objeto JSON sin tipos Swift privados.

Ejemplo codificado:

```json
{
  "protocolVersion": "1.0",
  "requestID": "A792E259-EE51-4535-BE0B-F3F57527F1F1",
  "moduleID": "com.zeuve.example",
  "action": "analyze",
  "payload": {
    "inputPath": "/ruta/autorizada/entrada",
    "recursive": true,
    "limit": 100
  }
}
```

## 11. `JSONValue`

Tipos admitidos:

- cadena;
- número `Double`;
- booleano;
- objeto `[String: JSONValue]`;
- array `[JSONValue]`;
- `null`.

Se codifican como JSON normal. Utiliza `JSONEncoder` y `JSONDecoder`; no dependas del orden de claves.

## 12. `ModuleEvent`

```swift
public struct ModuleEvent: Codable, Sendable, Equatable {
    let protocolVersion: String
    let requestID: UUID
    let kind: ModuleEventKind
    let sequence: Int
    let payload: [String: JSONValue]
}
```

Tipos de evento:

| Evento | Uso |
|---|---|
| `accepted` | La petición ha sido aceptada. |
| `progress` | Progreso o fase actual. Puede repetirse. |
| `log` | Información de diagnóstico no terminal. |
| `warning` | Advertencia recuperable. |
| `result` | Final correcto. Terminal. |
| `failure` | Final con error. Terminal. |
| `cancelled` | Final cancelado. Terminal. |

Reglas recomendadas para procesos aislados:

1. conservar el mismo `requestID`;
2. comenzar `sequence` en `0` o `1` y aumentarlo estrictamente;
3. emitir como máximo un evento terminal;
4. no emitir eventos después del terminal;
5. reservar stdout al protocolo;
6. enviar diagnóstico técnico a stderr o registros locales;
7. validar versión, módulo, acción y payload antes de ejecutar.

Secuencias válidas:

```text
accepted → progress* → warning/log* → result
accepted → progress* → failure
accepted → progress* → cancelled
```

## 13. Operaciones compartidas

La API de mensajes no sustituye a `OperationCoordinator`. La app debe representar la operación externa mediante el coordinador compartido para respetar la regla de una operación pesada principal a la vez.

Los eventos `progress` se traducirán a `OperationProgress`:

- `completed`;
- `total` opcional;
- `phase`;
- `currentItem` opcional.

No se inventa un porcentaje cuando `total` es desconocido.

## 14. Compatibilidad

- Cambios aditivos compatibles pueden mantenerse dentro de API `1.0` si los decodificadores toleran campos desconocidos.
- Cambios incompatibles requieren una nueva versión de API.
- El núcleo puede mantener adaptadores para versiones antiguas aprobadas.
- Un módulo debe declarar la primera versión de ZEUVE que realmente soporta.
- La versión del módulo y la versión de la API son conceptos distintos.

## 15. Seguridad para módulos futuros

Antes de habilitar importación externa deberán existir, como mínimo:

- formato `.zeuvemodule` definido;
- validación de estructura y manifiesto;
- firma o nivel de confianza;
- permisos visibles;
- aislamiento de procesos;
- control de rutas autorizadas;
- límites de recursos;
- cancelación y terminación de descendientes;
- compatibilidad de versiones;
- tratamiento de módulos no verificados.

Esta lista describe la evolución prevista; no significa que esas funciones estén disponibles en ZEUVE 0.7.0.

## Integración de ajustes de módulos

Los módulos oficiales con configuración persistente deben aportar su contenido a la navegación central de Ajustes. La interfaz de la herramienta no debe crear un sistema paralelo de configuración. Los valores persistentes usan claves con el prefijo del módulo en `SettingsRepository`; las opciones de una operación concreta permanecen en el ViewModel de la herramienta y no deben sobrescribir esos valores predeterminados.

