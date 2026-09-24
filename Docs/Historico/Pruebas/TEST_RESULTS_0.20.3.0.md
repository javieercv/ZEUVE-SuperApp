# Resultados de pruebas — ZEUVE 0.20.3.0

## Automatización

- `CleanerModuleTests`: 21/21 PASS en ejecuciones dirigidas, incluidas selección de desinstalación, cancelación previa y límite de una consulta activa de Spotlight, tamaño recursivo sin seguir symlinks, protección del historial ante descubrimiento incompleto y un ciclo real de Papelera y Deshacer con un archivo prescindible.
- `Scripts/verify_project.sh`: PASS en macOS Apple Silicon. La suite Swift completa y los 112 tests Python terminaron sin fallos; la compilación Xcode Debug finalizó con `BUILD SUCCEEDED`. Después de los últimos ajustes también pasaron la compilación Xcode, los 21 tests dirigidos y los verificadores de Limpiador y documentación.

## Recorrido manual

- Con una compilación Debug intermedia, Cancelar durante «Inventariando aplicaciones» devolvió la UI a «Analizar» en menos de un segundo; se pudo iniciar otro análisis.
- El análisis completo terminó y registró cobertura completa en el inventario local. La app de QA apareció con nombre, versión y ruta correctos; caché y log figuraron como regenerables y la preferencia como dato de riesgo alto.
- La automatización de la interfaz dejó de responder al intentar inspeccionar la vista de resultados; por ello no se pudo repetir la revisión visual final de la confirmación y el ciclo Papelera/Deshacer en esta compilación. El ciclo real de archivos sí pasó en la prueba automatizada de macOS.

Las pruebas de eliminación usan exclusivamente una `.app`, caché, log y preferencia creados para QA. No se realizan borrados sobre datos reales. Al terminar se retiraron los cuatro elementos de prueba y sus registros exactos del inventario local.
