# Ejemplos de implementación modular

## 1. El Organizador como referencia real

El Organizador y el Descargador universal son módulos oficiales integrados y muestran dos patrones distintos de separación de responsabilidades. No debe copiarse literalmente para todos los módulos.

### Estructura

```text
Sources/OrganizerModule/
├── ExtensionRules.swift
├── OrganizerModels.swift
├── OrganizerPlanner.swift
├── OrganizerExecutor.swift
├── OrganizerHistoryService.swift
├── OrganizerCSVExporter.swift
├── OrganizerModuleDefinition.swift
└── Resources/manifest.json

Sources/ZEUVEApp/Organizer/
├── OrganizerViewModel.swift
├── OrganizerView.swift
├── OrganizerPlanView.swift
└── OrganizerHistoryView.swift
```

### Qué reutilizar conceptualmente

- manifiesto validado;
- lógica fuera de SwiftUI;
- vista previa separada de la ejecución;
- uso del coordinador compartido;
- trabajo pesado fuera del actor principal;
- progreso mediante `AsyncStream`;
- persistencia encapsulada en un servicio;
- logs locales;
- cancelación y resumen final;
- pruebas del motor sin necesidad de abrir la app.

### Qué no copiar ciegamente

- reglas de extensiones;
- modelos de movimiento;
- lógica de deshacer específica;
- claves `organizer.*`;
- permisos o capacidades del Organizador;
- interfaz de tablas si otro módulo necesita un flujo diferente.

Cada módulo debe pedir solo lo necesario y diseñar sus propios modelos.

## 2. Ejemplo de módulo Swift incorporado

Un analizador local de archivos puede utilizar:

```text
ZEUVEApp → AnalysisViewModel → AnalysisModule → Foundation
```

Flujo:

1. el usuario selecciona archivos;
2. el ViewModel valida la selección;
3. comienza la operación en `OperationCoordinator`;
4. `Task.detached` ejecuta el analizador;
5. el motor publica progreso;
6. el ViewModel actualiza la interfaz;
7. se guarda un resumen en historial;
8. se finaliza la operación.

No necesita `networkAccess` ni `executeBundledTools`.

## 3. Ejemplo con motor externo

Un conversor multimedia puede usar:

```text
ZEUVEApp → ConverterModule → ProcessRunner → FFmpeg
```

El módulo Swift conserva la responsabilidad sobre:

- validación de entrada;
- opciones y presets;
- rutas y temporales;
- comandos permitidos;
- progreso;
- cancelación;
- validación del resultado;
- conflictos y publicación final;
- historial y mensajes.

FFmpeg solo realiza la conversión. El manifiesto declararía `executeBundledTools`; no declararía red si no la usa.

## 4. Ejemplo con Python aislado

Un módulo puede usar Python cuando una librería concreta lo justifique:

```text
ZEUVEApp → contrato local → ejecutable Python empaquetado
```

Requisitos:

- el usuario no instala Python;
- el proceso no recibe acceso global al sistema;
- las rutas proceden de selecciones autorizadas;
- stdout se reserva al protocolo JSON;
- stderr y `LocalLogger` guardan diagnóstico;
- la cancelación termina procesos descendientes;
- el manifiesto indica `technology: python` o `mixed` y `executionMode: isolatedProcess` cuando el sistema externo esté disponible.

No debe crearse un servidor Flask o localhost salvo autorización específica.

## 5. Secuencia JSON futura

Petición conceptual:

```json
{
  "protocolVersion": "1.0",
  "requestID": "A792E259-EE51-4535-BE0B-F3F57527F1F1",
  "moduleID": "com.zeuve.example",
  "action": "analyze",
  "payload": {
    "inputPath": "/ruta/autorizada/entrada"
  }
}
```

`JSONValue` se codifica como JSON normal: cadenas, números, booleanos, objetos, arrays o `null`. Debe utilizarse `JSONEncoder`/`JSONDecoder` para evitar incompatibilidades.

Eventos conceptuales:

```text
accepted → progress* → warning/log* → result
accepted → progress* → failure
accepted → progress* → cancelled
```

El sistema de importación y ejecución externa aún no está implementado. Estos contratos deben preservarse para la evolución futura, no simularse como función disponible.
