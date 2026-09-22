# Resultados de pruebas — ZEUVE 0.15.0.0

Fecha: 8 de septiembre de 2026.

## Cobertura nueva

La cobertura 0.15.0.0 añade regresiones para sesión reutilizable, waveform bipolar, mezcla antífasa, canal individual, densidad visual, duración desconocida/compactación temporal, persistencia de preferencias, parsing EBU R128, construcción segura de FFmpeg, offsets técnicos e informes sin datos privados.

## Suite automática completa

`./Scripts/run_tests.sh` terminó con exit code 0 sobre el árbol final:

- XCTest: **215 tests**, 0 fallos, **1 omitido** por requisito de macOS Apple Silicon.
- Swift Testing: **116 tests**, 0 fallos.
- Python ScriptTests: **83 tests**, 0 fallos.
- Total contabilizado: **414 tests**, **0 fallos**.

## Verificadores portables

Ejecutados correctamente de forma independiente sobre el mismo árbol:

- integración de aplicación;
- estructura del proyecto;
- motores;
- documentación/reglas;
- regresiones de rendimiento;
- Conversor universal;
- Descargador universal;
- Analizador de chats;
- Comparador de seguidores de Instagram;
- Inspector multimedia;
- sintaxis Bash de scripts críticos;
- `compileall` de Scripts/ScriptTests;
- validación de documentación de módulos;
- manifiestos;
- parseo de `ZEUVEApp`;
- regeneración Xcode;
- coherencia SwiftPM/Xcode.

Resultados estructurales:

- `ZEUVEApp`: **70 archivos Swift** parseados.
- SwiftPM/Xcode: **10 productos** coherentes.
- `verify_app_macos.sh`: omitido correctamente por no estar en macOS Apple Silicon con Xcode.

## Build Release portable

Se intentó `swift build -c release` en este entorno Linux. El compilador avanzó hasta `MultimediaInspectorModule`, pero el proceso superó repetidamente el límite temporal del entorno antes de emitir `Build complete!`; no apareció un error de compilación antes del corte. Por tanto, **no se marca el Release portable como PASS** en esta entrega.

Esto no sustituye el gate real del proyecto: `./Scripts/build_macos.sh Release` requiere macOS Apple Silicon con Xcode y en Linux se detiene correctamente con el mensaje de plataforma esperada.

## Validación macOS pendiente

Debe comprobarse en el Mac de referencia:

- build Debug/Release de `ZEUVE.app` con Swift 6;
- AVAudioEngine/AVAudioPlayerNode real;
- waveform como scrubber, clic/arrastre y VoiceOver;
- cambio de pista conservando tiempo;
- seek sincronizado waveform ↔ espectrograma;
- capítulos clicables;
- sonoridad EBU R128 con el FFmpeg empaquetado;
- cerrar análisis y analizar otro archivo sin reiniciar;
- persistencia/restauración de Ajustes;
- exportación TXT/Markdown/JSON;
- firma, Hardened Runtime y motores empaquetados.

No debe declararse validada la aplicación empaquetada hasta completar esos gates en macOS.
