# Resultados de pruebas — ZEUVE 0.20.7.0

05/10/2026 · macOS Apple Silicon/Xcode · marketing 0.20.7/build 73. Base remota: `17003a32f05e42134f244e5381fe5f0d872a248c`.

## Verificación completa

- `./Scripts/run_tests.sh`: Swift XCTest/Testing y 115 tests Python, sin fallos; integraciones opt-in ejecutadas por separado.
- `./Scripts/verify_project.sh`: pasa, incluyendo tests SwiftPM Debug, build SwiftPM Release, verificadores, documentación/manifests, parseo de los 80 archivos de app, coherencia Xcode y build Debug real.
- `swift test -c release --jobs 1`: suite completa sin fallos. La validación del Organizador también se ejecuta con optimización.
- `./Scripts/build_macos.sh Release`: pasa con verificación de motores empaquetados y firma ad hoc. La build final incorpora la protección de destinos del Organizador y avisos completos en revisión de lote.
- `git diff --check`: sin problemas. Nueve originales sintéticos conservan SHA-256.

Persisten los avisos previos de SwiftPM sobre capturas no Sendable de tipos Vision en el reconocimiento asíncrono; el bloque de reconocimiento no cambia en esta corrección. Xcode también avisa de que no hay metadata AppIntents que extraer. No impiden estas compilaciones; no se afirma que estén libres de warnings.

## Regresiones focalizadas

- Cabeceras AAC/ADTS reales (MPEG-2/4) frente a MP3 válido y trama MPEG reservada: detección correcta incluso con extensión engañosa.
- Métodos reales del ViewModel del Conversor, compilados en harness Swift 6: favorito/preset sobreviven a callbacks programáticos; edición real o destino incompatible invalidan la selección.
- Reglas del Organizador: normalización, destinos Simple/Detallado, rechazo de rutas/control, originales intactos; enlace simbólico aparecido tras preparar el plan no permite mover fuera de la carpeta elegida.
- OCR: fusión de frames retenidos, cierres por transparencia, duración/EOF, texto no reconocido revisable y exclusión de eventos SRT no finitos/invertidos/vacíos.
- Revisión: retirada efectiva de vídeo y cambio eng→spa; preflight conserva inspección original y plan, presenta antes/después sin producir salida.
- Escritor QuickTime: preservación de mdat y metadata previa, sustitución de covr, rechazo sin modificar el archivo ante workspace sin propiedad, átomos inválidos o moov no terminal.

## Integración local con motores reales

Fixtures sintéticos propios. FFmpeg/FFprobe del bundle preparado, Vision local, sin red.

- WAV → AAC y M4A; reimportación AAC → FLAC: tres salidas correctas, detección sin advertencia de MP3, códec real esperado, originales intactos y coordinador liberado.
- PGS de 12 s: exactamente tres eventos con inicio 0/4/8 y final 2/6/10; coordinador liberado. La antigua salida duplicada y los timestamps multiplicados por 1000 no se reproducen.
- MOV H.264/AAC: añadir JPEG → sustituir por PNG → conservar portada al editar título global → retirar. Cada original permanece byte a byte intacto; los paquetes SHA-256 de vídeo y audio coinciden en cada paso. Major/compatible brands permanecen `qt  `, las imágenes extraídas son idénticas y la portada retirada desaparece.
- Regresión de cinco escenarios existentes MP4/MKV: metadata/attachment, portada MKV conservada, portada MP4 añadida, sustituida y retirada.

Las evidencias externas se conservan en `QA-partials-20261005` y en las integraciones iniciales de `QA-fixes`, dentro de la carpeta de visualizaciones del chat. Las pruebas nativas son opt-in mediante `ZEUVE_QA_FIXTURES`, `ZEUVE_QA_ENGINES`, `ZEUVE_QA_OUTPUTS` y `ZEUVE_QA_PARTIAL_FIXTURES`/`ZEUVE_QA_FFMPEG`.

## Aceptación manual y límites

La sesión estuvo inicialmente bloqueada; tras recuperar ventanas y capturas se completaron los nueve recorridos desde UI en la copia interna Release. [Evidencia por ID](MANUAL_QA_0.20.7.0_20261005.md). La prueba de O-18 detectó un rechazo indebido de nombres válidos en Release, reproducido con XCTest optimizado y corregido antes de repetir el recorrido completo. Checklist: 599 OK, 1 fallo, 5 parciales y 34 pendientes de 639.

I-29/I-35 siguen requiriendo evidencia acústica; no se les atribuye un fallo de código nuevo ni se certifica audición mediante decodificación. D-15/D-60 y la cobertura remota de P-12 conservan la exclusión expresa del usuario. Las revisiones de lote no ejecutan ni publican archivos; se comprueba el detalle previo y su invalidación.

No certifica notarización, distribución, todo contenido posible ni acceso remoto.
