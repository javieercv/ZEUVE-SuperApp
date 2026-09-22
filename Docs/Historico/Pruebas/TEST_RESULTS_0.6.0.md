# Resultados de pruebas — ZEUVE 0.6.0

Fecha: 6 de julio de 2026.

## Entorno disponible

- Linux x86_64 para Swift Package Manager y pruebas lógicas.
- No se dispone de macOS, Xcode, ImageIO, PDFKit, VideoToolbox ni montaje de DMG en este entorno.

## Resultados completados

- 101 pruebas XCTest existentes: superadas, 0 fallos.
- 19 pruebas Swift Testing del Conversor universal: superadas, 0 fallos.
- 19 pruebas Python de estructura, políticas y documentación: superadas, 0 fallos.
- Total automatizado: 120 pruebas Swift y 19 pruebas Python, 139 en conjunto.
- Compilación SwiftPM Debug completa: superada.
- Compilación Release del target `UniversalConverterModule`: superada.
- Compilación SwiftPM Release completa de todos los targets: superada.
- Análisis sintáctico de todos los archivos Swift de `ZEUVEApp` y `UniversalConverterModule`: superado.
- Validaciones estructurales de `verify_project.sh`, excluyendo sus dos pasos Swift ya ejecutados por separado: superadas.
- Validación sintáctica de scripts shell, manifiestos y regeneración del proyecto Xcode: superada.
- ZIP cifrado sintético: contraseña ausente, incorrecta y correcta comprobadas; el contenido se extrajo únicamente con la contraseña correcta.
- Carpeta sintética de 600 archivos: inspección completa, sin límite arbitrario y con reutilización de caché.
- ZIP sintético con subcarpetas: estructura conservada y extracción únicamente de la entrada solicitada.
- Publicación: renombrado seguro y omisión comprobados sin modificar el archivo preexistente.
- Huellas: un cambio posterior del original invalida la vista previa.
- Preajustes: una imagen seleccionada para vídeo no se persiste y el fondo vuelve a una opción segura.

## Compilación Release completa

La compilación SwiftPM Release del paquete completo terminó correctamente, incluidos los targets existentes y `UniversalConverterModule`. Esta comprobación valida el código Swift y sus enlaces disponibles en Linux, pero no sustituye la compilación del objetivo macOS mediante Xcode ni la apertura de `ZEUVE.app`.

## Pendiente en Mac Apple Silicon

- Preparar y verificar LibreOffice 26.2.4 desde su DMG oficial.
- Compilar y abrir `ZEUVE.app` en Debug y Release mediante Xcode.
- Ejecutar conversiones reales con ImageIO, PDFKit y H.264 VideoToolbox.
- Probar LibreOffice integrado con DOCX, XLSX, PPTX y OpenDocument.
- Validar arrastrar y soltar, selectores, accesibilidad, progreso, cancelación y fluidez visual.
- Verificar firma, Hardened Runtime y paquete final de motores.

No se afirma que la aplicación macOS haya sido compilada o abierta en este entorno.
