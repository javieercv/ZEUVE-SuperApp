# Resultados de pruebas — ZEUVE 0.7.3

Fecha: 16 de julio de 2026.
Entorno utilizado: Linux x86_64 con Swift 6. La plataforma objetivo del producto continúa siendo macOS 14 o posterior sobre Apple Silicon ARM64.

## Pruebas ejecutadas

- `swift test --jobs 1`: completado. Se ejecutaron 101 pruebas XCTest sin fallos.
- Suite Swift Testing del Conversor: 37 pruebas completadas sin fallos.
- Se comprobó el rechazo de DOC, DOCX, XLS, XLSX, PPT, PPTX, ODT, ODS, ODP y RTF como entradas del Conversor.
- Se comprobó que un DOCX no se acepta por error como ZIP genérico, tanto como archivo directo como cuando aparece dentro de otro ZIP.
- Se comprobó que CSV continúa registrado como formato de datos y que una operación CSV a CSV utiliza copia segura.
- Se comprobaron los formatos restantes de Pandoc: TXT, Markdown, HTML y EPUB.
- `swift build -c release --target UniversalConverterModule --jobs 1`: completado correctamente.
- `swift build -c release --jobs 1`: compilación Release completa del paquete finalizada correctamente.
- `bash -n Scripts/*.sh`: scripts Bash sintácticamente válidos.
- `python3 -m py_compile Scripts/*.py`: scripts Python sintácticamente válidos.
- Validación JSON de manifiestos y recursos: completada.
- 21 pruebas Python de políticas y scripts: completadas sin fallos.
- Comprobaciones estáticas de `Scripts/verify_project.sh`: completadas; no quedan rutas activas de LibreOffice y la documentación modular se validó.
- Regeneración del proyecto Xcode con `Scripts/generate_xcode_project.py`: completada con versión 0.7.3 y build 24.

## Protección de originales

El ZIP original `ZEUVE_Swift_0.7.2.zip` no se modificó. El desarrollo se realizó en una carpeta de trabajo independiente. Las pruebas del Conversor utilizaron archivos temporales sintéticos y verificaron las rutas seguras previstas; no se procesaron archivos personales del usuario.

## Pruebas no realizadas en este entorno

No se pudo abrir la aplicación ni validar manualmente SwiftUI/AppKit, firma, Hardened Runtime, empaquetado de una `.app`, ejecución de motores ARM64 o preparación completa de motores en macOS. Estas comprobaciones requieren un Mac compatible y deben realizarse antes de considerar validada la experiencia nativa final.
