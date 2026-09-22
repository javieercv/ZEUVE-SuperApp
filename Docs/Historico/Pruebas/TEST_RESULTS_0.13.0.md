# Resultados de pruebas — ZEUVE 0.13.0

Fecha: 7 de septiembre de 2026.

## Batería portable completa

Se ejecutó desde la raíz real del proyecto:

```bash
./Scripts/run_tests.sh
```

Resultado final: **correcto (exit 0)**.

- XCTest: 214 ejecutados, 0 fallos, 1 omitido. El omitido es el diagnóstico ejecutable de yt-dlp que requiere macOS Apple Silicon.
- Swift Testing: 81 tests, 0 fallos.
- Python / ScriptTests: 80 tests, 0 fallos.
- Total contabilizado: **375 tests**, 0 fallos, 1 omitido por plataforma.

La cobertura nueva incluye Inspector multimedia, `ZEUVEEngines/MediaInspection`, regresión del Conversor universal, política híbrida de remux, Undo/Redo, seguridad de publicación, fingerprints, revalidación de entradas, cancelación de procesos, streaming PCM incremental y señales sintéticas del espectrograma.

## Cobertura destacada de 0.13.0

`MultimediaInspectorModuleTests` ejecuta 26 tests de comportamiento y DSP. `MediaInspectionTests` ejecuta 8 tests de parser y servicio real con proceso sintético, caché, invalidación, fallo y cancelación. La suite del Conversor universal mantiene 47 tests de regresión sin cambios funcionales.

Las señales espectrales verificadas incluyen 440 Hz, 1 kHz y 10 kHz, varios sample rates, varios tamaños FFT, Hann/Hamming/Blackman–Harris, silencio, amplitud baja, estéreo, multicanal, bloque incompleto y Nyquist.

La compatibilidad cubre MKV, MP4, MOV y WebM, incluida la política conservadora para imágenes adjuntas al cambiar de contenedor. La previsualización del plan materializa también las pistas eliminadas para distinguir keep/add/remove/conversión auxiliar.

## Release portable

Se ejecutó:

```bash
swift build -c release --jobs 2
```

Resultado final: **correcto (exit 0)**. La compilación final terminó en 1 min 28 s aproximadamente en este contenedor Linux x86_64.

## Verificación integral del proyecto

Se ejecutó:

```bash
ZEUVE_SWIFT_JOBS=2 ./Scripts/verify_project.sh
```

Resultado final: **correcto (exit 0)**.

El orquestador volvió a ejecutar tests y Release portable y verificó integración de aplicación, estructura, engines, documentación/reglas, rendimiento, Conversor, Descargador, Analizador de chats, Comparador de seguidores, Inspector multimedia, scripts shell, tests Python, documentación modular, manifests, parseo sintáctico de las 63 fuentes Swift de `ZEUVEApp`, generación Xcode y coherencia SwiftPM/Xcode con 10 productos enlazados.

## Validación de plataforma macOS

Se ejecutó también el comando requerido:

```bash
./Scripts/build_macos.sh Release
```

Resultado en este entorno: **no ejecutable por plataforma (exit 1 esperado)**. El script informa: `Esta compilación requiere macOS Apple Silicon con Xcode.`

`verify_project.sh` ejecuta igualmente `Scripts/verify_app_macos.sh`, que registra la validación nativa como omitida porque este entorno es Linux x86_64.

Por ello no se afirma haber compilado ni firmado `ZEUVE.app`, ni haber validado SwiftUI/AppKit, Accelerate/vDSP ARM64 o los engines empaquetados dentro de la app. Esa comprobación debe hacerse en un Mac Apple Silicon con Xcode siguiendo `Docs/BUILDING.md` y la lista manual de `Docs/MULTIMEDIA_INSPECTOR.md`.
