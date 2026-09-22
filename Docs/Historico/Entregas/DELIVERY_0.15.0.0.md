# Entrega — ZEUVE 0.15.0.0

Fecha: 8 de septiembre de 2026.

## Versiones

- ZEUVE: `0.15.0.0`.
- Build: `51`.
- Inspector multimedia: `0.3.0`.

## Alcance

La entrega añade sesión reutilizable, waveform bipolar integrada como scrubber, posición temporal compartida, comparación rápida entre pistas, navegación por capítulos, sonoridad bajo demanda, offsets técnicos, informes exportables y Ajustes centralizados.

Se conserva la política del Inspector: inspección local, edición estructural mediante draft/remux y ausencia de edición temporal o recodificación silenciosa.

## Privacidad y dependencias

No se añaden red, telemetría, APIs, motores ni dependencias externas. Waveform y sonoridad usan FFmpeg ya empaquetado; el reproductor usa AVFoundation del sistema. No se persiste PCM ni waveform, no se modifica el original durante inspección y los informes omiten ruta absoluta, fingerprint e IDs internos.

## QA portable

- Tests: **414**, 0 fallos; 1 omitido por plataforma.
- XCTest: 215.
- Swift Testing: 116.
- Python: 83.
- Verificadores portables por dominio: **PASS** al ejecutarlos de forma independiente.
- `ZEUVEApp`: 70 fuentes Swift parseadas.
- SwiftPM/Xcode: 10 productos coherentes.
- Regeneración de `ZEUVE.xcodeproj`: **PASS**.

El build Release SwiftPM no pudo completarse dentro del límite temporal del entorno Linux; no se observó error de compilación antes del corte y no se contabiliza como PASS. El build de aplicación macOS permanece necesariamente pendiente de un Mac Apple Silicon con Xcode.

## Validación final requerida en macOS

Ejecutar:

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
./Scripts/build_macos.sh Release
```

Después realizar prueba manual de reproducción, waveform, cambio de pista, capítulos, sonoridad, cambio/cierre de análisis, Ajustes e informes. Si Xcode detecta un problema específico de AVFoundation/SwiftUI/Swift 6, esa corrección debe realizarse sobre esta misma base sin recuperar versiones anteriores.
