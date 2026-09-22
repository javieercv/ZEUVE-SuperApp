# Entrega — ZEUVE 0.14.0.0

Fecha: 8 de septiembre de 2026.

## Versiones

- ZEUVE: `0.14.0.0`.
- Build: `50`.
- Inspector multimedia: `0.2.0`.

## Alcance

La entrega mejora UX del espectrograma, añade previsualización local de audio, nombres seguros de canales, estructura técnica ampliada, copia local, drag & drop de pistas y búsqueda de metadatos. Mantiene intactos los límites de edición y el DSP optimizado de 0.13.2.0.

El reproductor es una herramienta auxiliar de inspección: FFmpeg decodifica el stream exacto a PCM por streaming y AVAudioEngine/AVAudioPlayerNode realiza la salida local. No incorpora timeline, cortes, efectos, mezcla creativa ni exportación.

## Privacidad y dependencias

No añade red, telemetría, APIs, motores ni dependencias externas. El reproductor usa FFmpeg/FFprobe ya empaquetados y AVFoundation del sistema. No modifica originales, no publica durante reproducción, no genera historial de previsualización y no persiste PCM.

## Validación portable

- Tests: **402**, 0 fallos; 1 omitido por requisito de macOS Apple Silicon.
- XCTest: 215.
- Swift Testing: 104.
- Python: 83.
- Release SwiftPM portable: **PASS**, exit code 0.
- `./Scripts/verify_project.sh`: **PASS**, exit code 0.
- Verificadores portables por dominio: **PASS**.
- `ZEUVEApp`: 68 fuentes Swift parseadas.
- SwiftPM/Xcode: 10 productos coherentes.

## Validación macOS

`./Scripts/build_macos.sh Release` se ejecutó en este entorno y terminó con el bloqueo previsto (`Esta compilación requiere macOS Apple Silicon con Xcode.`). La compilación nativa queda pendiente de ejecutar en un Mac Apple Silicon con Xcode sobre esta entrega. Es obligatoria porque el nuevo reproductor compila su implementación AVFoundation únicamente en macOS y porque la prueba audible no puede sustituirse en Linux.

Antes de declarar validada la aplicación empaquetada deben ejecutarse `./Scripts/build_macos.sh Release` y las pruebas manuales descritas en `Docs/TEST_RESULTS_0.14.0.0.md`.
