# Resultados de pruebas — ZEUVE 0.7.1

Fecha: 7 de julio de 2026.

## Entorno utilizado

- Linux x86_64.
- Swift 6.2.1.
- Sin Xcode, AppKit, SwiftUI ejecutable, ImageIO, PDFKit ni VideoToolbox.

## Pruebas superadas

- `swift test --jobs 1`: 138 pruebas Swift, 0 fallos.
- Conversor: 37 pruebas Swift, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -v`: 20 pruebas, 0 fallos.
- Nueva regresión de licencia de Calibre: superada.
- Sintaxis Bash de los scripts de preparación, verificación y proyecto: superada.
- Análisis sintáctico del único archivo Swift modificado: superado.
- Validación de documentación de módulos y ejemplos JSON: superada.
- Controles estáticos del Conversor ejecutados desde `verify_project.sh`: superados.
- La licencia fijada de Calibre se validó durante esa entrega histórica.

## Verificación integral

`Scripts/verify_project.sh` volvió a superar toda la fase de pruebas. La compilación SwiftPM Release se inició, pero volvió a exceder el límite de ejecución del entorno mientras compilaba `OrganizerModule`; no emitió un error de código antes de la interrupción. Las comprobaciones estáticas posteriores relevantes se ejecutaron por separado y superaron.

## Pendiente en macOS

Debe repetirse `Scripts/prepare_engines_macos.sh` en el Mac Apple Silicon. Esta entrega corrige el punto que devolvía HTTP 404, pero no afirma que la preparación completa de todos los motores haya terminado hasta ejecutar de nuevo el script y posteriormente `Scripts/verify_engines_macos.sh`.
