# Informe de entrega — ZEUVE 0.2.2

## 1. Resumen breve

ZEUVE 0.2.2 aplica la opción C aprobada: el diagnóstico en ejecución deja de comparar el tamaño y SHA-256 de yt-dlp, Deno, FFmpeg y FFprobe. Así, la firma de macOS no provoca que los cuatro motores aparezcan erróneamente como no disponibles.

## 2. Estado

**Corrección completada en el código fuente y validada mediante pruebas automáticas.**

**Pendiente de validación final en macOS Apple Silicon:** compilación con Xcode, firma, apertura de la app y prueba real de análisis/descarga.

## 3. Pruebas realizadas

- 60 pruebas Swift superadas.
- 8 pruebas Python superadas.
- Compilación SwiftPM Debug superada.
- Prueba específica de regresión de tamaño/hash superada.
- Proyecto Xcode regenerado con versión 0.2.2 y build 8.
- Compilación SwiftPM Release superada.
- `Scripts/verify_project.sh` superado.
- Sintaxis de scripts, documentación modular y manifiestos validados.
- Original recibido conservado. SHA-256: `95e816d43fa50ed03de72ebabfe8262ec6e3e1a20c1b9dc2a88eabe4d53dfa50`.

`Scripts/verify_project.sh` finalizó correctamente en el entorno disponible. La parte específica de motores firmados y Xcode se omitió automáticamente porque el entorno no es macOS Apple Silicon.

## 4. Explicación detallada

### Diagnóstico en ejecución

Se ha eliminado de `EngineDiagnosticService` la comparación entre el ejecutable incluido y los campos `size` y `sha256` de `engines.json`. La causa es que `codesign` modifica los bytes y puede modificar el tamaño del ejecutable después de copiarlo dentro de la aplicación.

El diagnóstico sigue rechazando motores que:

- no existen;
- no tienen licencia o aviso asociado;
- no tienen permiso de ejecución;
- tienen una arquitectura incompatible;
- dependen de bibliotecas externas no incluidas;
- no pueden iniciarse;
- informan una versión diferente.

### Verificación previa al empaquetado

No se ha eliminado SHA-256 del proyecto. `engines.json`, `SHA256.swift` y `verify_engines_macos.sh` se conservan. El tamaño y hash siguen verificándose antes de firmar los ejecutables, durante la preparación y el empaquetado.

### Mensaje de diagnóstico

El estado correcto pasa a mostrarse como «Motor disponible y comprobado», evitando afirmar que se ha realizado una comparación de integridad en tiempo de ejecución.

## 5. Archivos modificados

- `Sources/ZEUVEEngines/EngineDiagnostics.swift`: retirada de la comparación runtime de tamaño y SHA-256.
- `Tests/ZEUVEEnginesTests/EngineRegistryTests.swift`: regresión adaptada a la política aprobada.
- `Scripts/verify_project.sh`: validación para impedir que vuelva la comparación incompatible con `codesign`.
- `Scripts/generate_xcode_project.py` y `ZEUVE.xcodeproj/project.pbxproj`: versión 0.2.2, build 8.
- `Sources/ZEUVEApp/SettingsView.swift`: versión visible actualizada.
- `Sources/YouTubeDownloaderModule/Resources/manifest.json`: versión del módulo actualizada.
- `Sources/YouTubeDownloaderModule/Errors/YouTubeDownloaderError.swift`: texto de versión actualizado.
- `Tests/YouTubeDownloaderModuleTests/YouTubeFilesStorageAndManifestTests.swift`: expectativa de versión actualizada.
- `VERSION`, `CHANGELOG.md`, `README.md`, `PROJECT_DECISIONS.md` y documentación activa: versión, política y pruebas actualizadas.
- `Docs/TEST_RESULTS_0.2.2.md` y `Docs/DELIVERY_0.2.2.md`: nuevos informes.

No se han eliminado funciones ni añadido dependencias.

## 6. Versión

- Versión anterior: 0.2.1, build 7.
- Versión nueva: **0.2.2, build 8**.
- Motivo: corrección de un error de diagnóstico y empaquetado sin cambio de arquitectura ni de API.

## 7. Limitaciones

- La aplicación firmada no se ha podido compilar ni abrir en este entorno.
- La prueba real de YouTube sigue pendiente de un Mac Apple Silicon con Xcode.
- Al aplicar la opción C, una sustitución de un ejecutable por otro compatible ya no se detecta mediante hash durante la ejecución. La protección se mantiene en la preparación previa al empaquetado y mediante la firma de código de macOS.

## 8. Entrega

La entrega se genera como un ZIP completo y limpio de ZEUVE 0.2.2, excluyendo compilaciones, cachés, datos locales de Xcode, temporales y registros.
