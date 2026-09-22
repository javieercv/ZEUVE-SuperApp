# Entrega — ZEUVE 0.15.1.0

Fecha: 9 de septiembre de 2026.

## Versiones

- ZEUVE: `0.15.1.0`.
- Build: `52`.
- Inspector multimedia: `0.3.1`.

## Correcciones

- El botón **Escuchar** de una pista distinta sustituye el stream activo mediante una única operación serializada y sincroniza la selección de audio del Inspector.
- La posición temporal se conserva al cambiar de pista cuando es válida.
- Las peticiones antiguas de start/stop/seek no pueden publicar snapshots sobre una operación más reciente.
- El seek de la waveform es optimista: la posición visual cambia inmediatamente y no vuelve fugazmente al punto anterior.

## Privacidad y dependencias

Sin cambios: reproducción local, FFmpeg empaquetado con argumentos separados, AVFoundation del sistema, originales en solo lectura, sin red, telemetría ni dependencias nuevas.

## QA portable

- Tests: **415**, 0 fallos; 1 omitido por plataforma.
- XCTest: 215.
- Swift Testing: 117.
- Python: 83.
- Suite del Inspector: 62 tests.
- Verificadores portables por dominio: PASS al ejecutarlos de forma independiente.
- `ZEUVEApp`: 70 fuentes Swift parseadas.
- SwiftPM/Xcode: 10 productos coherentes.
- Debug SwiftPM: PASS.
- Release SwiftPM: no concluido por límite temporal del entorno; sin error observado antes del corte.

## Gate final en macOS

Debe ejecutarse el build real en Xcode/macOS y probar el cambio de pista con varias pistas reales y el seek de waveform. Esta entrega parte de la 0.15.0.0 corregida por Codex que el usuario confirmó que compilaba; no recupera código de versiones anteriores.
