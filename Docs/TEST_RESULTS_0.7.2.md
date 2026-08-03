# Resultados de pruebas — ZEUVE 0.7.2

Fecha: 7 de julio de 2026.

## Entorno utilizado

- Linux x86_64.
- Swift 6.2.1.
- Sin ejecución nativa de Xcode, AppKit, SwiftUI, ImageIO, PDFKit ni VideoToolbox.

## Cobertura de la corrección

La regresión comprueba que `prepare_engines_macos.sh` contiene `make install-lib-static` y que no contiene ni `make install-lib-static install-headers` ni una llamada independiente a `make install-headers`. `verify_project.sh` repite el control para impedir que el objetivo incompatible reaparezca.

## Validación requerida en macOS

Debe repetirse la preparación en el Mac Apple Silicon. El registro aportado confirma que la biblioteca, las cabeceras y `x264.pc` ya se instalaban antes del error; 0.7.2 elimina exclusivamente el objetivo posterior inexistente. La preparación completa no se considerará superada hasta que finalicen `prepare_engines_macos.sh` y `verify_engines_macos.sh`.

## Resultados

- `swift test --jobs 1`: 138 pruebas Swift, 0 fallos.
- Conversor universal: 37 pruebas Swift, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -v`: 21 pruebas, 0 fallos.
- Nueva regresión de instalación de x264: superada.
- Sintaxis Bash de los scripts modificados: superada.

Las comprobaciones nativas de firma, apertura y conversiones reales siguen reservadas al Mac objetivo.

## Compilación Release y verificación integral

`verify_project.sh` superó las pruebas y comenzó `swift build -c release --jobs 1`, pero la compilación no terminó dentro del límite del entorno mientras compilaba `OrganizerModule`; no emitió un error de código antes de la interrupción. Las comprobaciones estáticas se ejecutaron además sin las dos órdenes de compilación y alcanzaron correctamente la validación de documentación y la política de motores, aunque la ejecución completa volvió a quedar limitada por tiempo. No se presenta la compilación Release como superada.
