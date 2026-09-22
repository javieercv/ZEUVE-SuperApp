# Resultados de pruebas — ZEUVE 0.7.0

Fecha: 7 de julio de 2026.

## Entorno utilizado

- Linux x86_64.
- Swift 6.2.1.
- Sin Xcode, AppKit, SwiftUI ejecutable, ImageIO, PDFKit ni VideoToolbox.

## Pruebas superadas

- `swift test`: 138 pruebas Swift, 0 fallos.
- Conversor: 37 pruebas Swift, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests`: 19 pruebas, 0 fallos.
- compilación Debug de los targets ejercitados por `swift test`: superada.
- compilación Release del Conversor y del paquete completo: iniciada, sin diagnóstico de compilación, pero no finalizada dentro de los límites de 4 y 10 minutos del entorno.
- análisis sintáctico de vistas Swift: superado.
- validación JSON, sintaxis Bash/Python, documentación y controles estáticos del proyecto: superados.
- `Scripts/verify_project.sh`: la fase de pruebas superó; la fase Release quedó limitada por tiempo. Las comprobaciones posteriores se ejecutaron por separado y superaron.

## Casos nuevos del Conversor

- extensión que no coincide con PNG real;
- OOXML por estructura y OOXML dentro de ZIP;
- matriz que impide DOCX a XLSX;
- motor ausente y formatos ocultos;
- formatos distintos dentro de una categoría;
- categorías distintas rechazadas;
- salida coincidente con otro original del lote;
- límite de profundidad ZIP;
- migración de ajustes y preajustes 0.6.0;
- favoritas sin archivos privados;
- capacidades FFmpeg;
- limpieza de temporales abandonados;
- argumentos separados de Pandoc y Calibre;
- modo seguro y `GS_LIB` de Ghostscript;
- registro honesto de motores opcionales ausentes.

## Originales

Las pruebas de publicación confirman que un resultado no sustituye otro original del mismo lote y que el contenido original permanece intacto.

## No probado

- compilación Xcode Debug/Release;
- apertura de ZEUVE.app;
- firma, notarización o Gatekeeper;
- interfaz real, teclado, VoiceOver y drag and drop;
- motores opcionales preparados;
- conversión real con ImageIO, PDFKit, VideoToolbox, LibreOffice, Pandoc, Calibre y Ghostscript;
- desbloqueo de un PDF real protegido.

Estas pruebas no deben considerarse superadas hasta ejecutarlas en un Mac Apple Silicon.
