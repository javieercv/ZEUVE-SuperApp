# Resultados de pruebas — ZEUVE 0.1.3

Fecha: 1 de julio de 2026

## Motivo de esta versión

La compilación con Xcode en macOS detectó dos errores en `AppModel.init()`:

- `storage`, declarado como constante, podía recibir una asignación en el bloque `do` y otra en el bloque `catch` cuando una lectura posterior lanzaba un error.
- El bloque de recuperación consultaba `startupError` antes de que todas las propiedades almacenadas estuvieran inicializadas.

La corrección calcula primero todas las dependencias y estados iniciales mediante variables locales y asigna después las propiedades de `AppModel` una sola vez.

## Entorno disponible para la validación

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

Este entorno permite compilar y probar los paquetes Swift independientes de la interfaz. No dispone de Xcode, AppKit, SwiftUI para macOS ni del SDK de macOS.

## Pruebas automáticas

Comando principal:

```bash
./Scripts/verify_project.sh
```

Resultado:

- 30 pruebas ejecutadas.
- 30 pruebas superadas.
- 0 fallos.
- 0 errores inesperados.

Se volvieron a comprobar planificación, conflictos, selección parcial, cancelación y reversión, historial, SQLite, deshacer seguro, CSV, manifiestos, registros locales y coordinación de operaciones.

## Comprobaciones específicas de esta corrección

- Revisados todos los inicializadores de `Sources/ZEUVEApp`.
- Confirmado que `OrganizerViewModel` y `OrganizerCompletion` no contienen el mismo patrón de inicialización inseguro.
- Añadida una comprobación de regresión en `Scripts/verify_project.sh` que exige el uso de variables locales resueltas antes de asignar las propiedades de `AppModel`.
- Confirmado que ya no existe la asignación directa `storage = container` dentro del bloque `do`.
- Confirmado que el bloque de recuperación no utiliza `startupError` para construir el `OrganizerViewModel` no disponible.
- Compilado con Swift 6.2.1 un caso aislado equivalente, con concurrencia estricta, para verificar la semántica del nuevo patrón de inicialización.

## Compilaciones comprobadas

- Paquetes Swift en configuración Debug: correcta.
- Paquetes Swift en configuración Release: correcta.
- Análisis sintáctico de los nueve archivos SwiftUI/AppKit: correcto.
- Regeneración y validación estructural de `ZEUVE.xcodeproj`: correcta.
- Versión y números de compilación del proyecto: coherentes con 0.1.3 / build 4.

## Comprobación pendiente

No se ha podido compilar ni abrir `ZEUVE.app` en este entorno. La comprobación decisiva pendiente es ejecutar el proyecto con Xcode en un Mac Apple Silicon y confirmar que han desaparecido los diagnósticos de inicialización de `AppModel`.

El aviso de Swift Package Manager que sugiere instalar `sqlite3` mediante Homebrew no se ha modificado en esta corrección y no era la causa de los errores tratados.
