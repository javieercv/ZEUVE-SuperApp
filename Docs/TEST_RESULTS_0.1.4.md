# Resultados de pruebas — ZEUVE 0.1.4

Fecha: 1 de julio de 2026.

## Entorno utilizado

- Sistema disponible: Linux x86_64.
- Swift: 6.2.1.
- No disponible: macOS, Xcode, SwiftUI/AppKit enlazados, firma ni apertura de `ZEUVE.app`.

## Resultado general

- Pruebas automáticas: **30 superadas**.
- Fallos: **0**.
- Errores inesperados: **0**.
- Compilación Debug de paquetes Swift: superada.
- Compilación Release de paquetes Swift: superada.
- Validación ampliada `Scripts/verify_project.sh`: superada.
- Validación de documentación y ejemplos JSON: superada.
- Compilación completa de la app con Xcode: no realizada en este entorno.
- Apertura de la app compilada: no realizada en este entorno.

## Pruebas automáticas ejecutadas

### `OrganizerExecutionTests` — 8

- Exportación CSV con filas incluidas y excluidas.
- Cancelación después del primer movimiento con reversión.
- Cancelación antes de mover.
- Aparición de un destino después de la vista previa.
- Ejecución selectiva y deshacer.
- Cambio del origen después de la vista previa.
- Conservación de carpetas con contenido ajeno.
- Deshacer que omite un destino modificado.

### `OrganizerManifestTests` — 1

- Manifiesto incluido válido.

### `OrganizerPlannerTests` — 13

- Conflicto configurado para omitir.
- Renombrado seguro sin sobrescritura.
- Regla personalizada y carpeta de 1.201 archivos.
- Clasificación detallada.
- Extensiones equivalentes.
- Ocultos y temporales omitidos.
- Inclusión opcional de ocultos.
- Subcarpetas, carpetas gestionadas y paquetes de macOS.
- Desactivación de agrupación relacionada.
- Mismo nombre base entre categorías.
- Mismo nombre base dentro de una categoría.
- Clasificación simple.
- Enlaces simbólicos nunca seguidos.

### `ModuleManifestTests` — 4

- Rechazo de identificador duplicado.
- Escritura de registro JSONL local.
- Codificación y decodificación del protocolo.
- Registro y orden de manifiestos válidos.

### `StorageTests` — 2

- Alta, consulta y actualización del historial.
- Persistencia de ajustes entre repositorios.

### `OperationCoordinatorTests` — 2

- Exclusión de operaciones simultáneas.
- Seguimiento de progreso y cancelación.

## Validaciones adicionales

`Scripts/verify_project.sh` comprobó:

- patrón de inicialización seguro de `AppModel` basado en `initialState`;
- importaciones necesarias de `ZEUVECore`;
- todas las llamadas a `LocalLogger.write` con descarte explícito del resultado;
- ausencia de `pkgConfig` y proveedores Homebrew para SQLite;
- presencia del `module.modulemap` y enlace `sqlite3`;
- presencia de la documentación modular obligatoria;
- validez JSON y campos requeridos de manifiestos;
- análisis sintáctico de los nueve archivos de la interfaz;
- regeneración del proyecto Xcode;
- versión 0.1.4 y build 5.

`Scripts/validate_module_docs.py` comprobó:

- documentos humanos y para chats;
- manifiesto de ejemplo;
- tecnologías, permisos y capacidades admitidos;
- petición de ejemplo;
- correlación de `requestID`;
- secuencia creciente y única de eventos;
- instrucciones esenciales para chats.

`swift package describe` se ejecutó sin mostrar las advertencias anteriores de `pkg-config` o Homebrew.

## Advertencias corregidas

Se corrigieron las cinco advertencias visibles en Xcode:

```text
Result of 'try?' is unused
```

Las seis llamadas actuales a `LocalLogger.write` del Organizador utilizan descarte explícito:

```swift
_ = try? await logger?.write(...)
```

Se eliminó del target `CSQLite` la configuración que provocaba:

```text
failed to retrieve search paths with pkg-config
maybe pkg-config is not installed
you may be able to install sqlite3 using your system-package
```

La biblioteca continúa enlazada mediante `module.modulemap` y `link "sqlite3"`.

## Pruebas pendientes en macOS

Deben comprobarse en un Mac Apple Silicon con Xcode:

- resolución del grafo sin advertencias de SQLite;
- compilación completa de `ZEUVE.app`;
- ausencia de las advertencias `try?` en Xcode;
- apertura de la aplicación;
- navegación, temas y vistas;
- selector de carpetas;
- arrastrar y soltar;
- progreso y cancelación desde la interfaz;
- historial y deshacer desde la interfaz;
- apertura de Finder;
- firma, sandbox y notarización cuando se aprueben.
