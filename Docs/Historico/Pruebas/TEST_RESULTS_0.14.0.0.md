# Resultados de pruebas — ZEUVE 0.14.0.0

Fecha: 8 de septiembre de 2026.

## Cobertura nueva

La cobertura añadida incluye resolución de canales, ejes/cursor espectral, lectura aproximada de dB sin reanálisis, formatters técnicos, identidad/fingerprint de preview, construcción segura de argumentos FFmpeg de previsualización, límites del planner espectral heredado y regresiones de draft/reordenación.

## Suite Swift

La fase Swift de `./Scripts/run_tests.sh` completó correctamente sobre el árbol 0.14.0.0:

- XCTest: **215 tests**, 0 fallos, **1 omitido por requisito de macOS Apple Silicon**.
- Swift Testing: **104 tests**, 0 fallos.
- Total Swift contabilizado: **319 tests**, 0 fallos.

## Suite Python

`python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v` terminó con exit code 0:

- Python ScriptTests: **83 tests**, 0 fallos.

## Total portable

- **402 tests contabilizados**.
- **0 fallos**.
- **1 test omitido** por requerir macOS Apple Silicon.

El primer lanzamiento combinado de `run_tests.sh` fue cortado externamente por el límite temporal de este entorno después de que toda la fase Swift ya hubiese finalizado correctamente; la fase Python se ejecutó inmediatamente después de forma independiente sobre el mismo árbol y terminó con exit code 0.

## Build y verificadores portables

- `swift build -c release --jobs 4`: **PASS**, exit code 0 (`Build complete!`).
- `./Scripts/verify_project.sh`: **PASS**, exit code 0. Incluyó suite Swift, build Release portable, 83 tests Python, verificadores de dominio, validación documental, regeneración Xcode y coherencia SwiftPM/Xcode.
- Parseo sintáctico portable de `ZEUVEApp`: **68 archivos Swift**.
- Integración SwiftPM/Xcode: **10 productos** enlazados.
- `bash -n` de scripts críticos y `compileall` de Scripts/ScriptTests: **PASS**.
- `./Scripts/build_macos.sh Release`: ejecutado en este entorno y detenido correctamente con exit code 1 porque requiere macOS Apple Silicon con Xcode; no se contabiliza como build fallido del proyecto.

## Validación de plataforma pendiente

La ruta real `AVAudioEngine`/`AVAudioPlayerNode`, SwiftUI drag & drop y el build completo de `ZEUVE.app` requieren macOS Apple Silicon con Xcode. Este entorno Linux no puede validar sonido real, dispositivo de salida, seek audible, interacción SwiftUI/AppKit ni firma/Hardened Runtime.

En un Mac real deben comprobarse como mínimo:

- audio independiente;
- dos o más streams dentro de un contenedor multiaudio;
- play/pause, seek, ±15 s y volumen;
- reproducción de audio externo añadido al draft;
- clic en espectrograma → reproducción desde ese instante;
- playhead sincronizado;
- detener al cambiar/cerrar archivo;
- drag & drop de pistas y archivos externos;
- build Release ARM64 y verificadores empaquetados.
