# Resultados de pruebas — ZEUVE 0.18.0.0

Fecha: 21 de septiembre de 2026.  
Entorno: Linux x86_64 con Swift 6.2.1.

## PASS

- Pruebas Python de `Tests/ScriptTests`: **102/102**, 0 fallos.
- Inspector multimedia: **99/99 Swift Testing**, 0 fallos.
- Suite Swift global: **154/154 Swift Testing**, 0 fallos.
- Suites XCTest portables: **215 tests**, 0 fallos y **1 omitido** intencionadamente porque el diagnóstico ejecutable de yt-dlp requiere macOS Apple Silicon.
- `Scripts/verify/multimedia_inspector.py`: PASS.
- `Scripts/verify/project_structure.py`: PASS.
- `Scripts/verify/app_integration.py`: PASS.
- `Scripts/verify/engines.py`: PASS.
- `Scripts/verify/performance.py`: PASS.
- `Scripts/verify/converter.py`: PASS.
- `Scripts/verify/downloader.py`: PASS.
- `Scripts/verify/chat_analyzer.py`: PASS.
- `Scripts/verify/instagram_followers.py`: PASS.
- `Scripts/verify/manifests.py`: PASS.
- `Scripts/verify/documentation.py`: PASS.
- `Scripts/validate_module_docs.py`: PASS.
- `Scripts/verify/app_sources.py`: PASS; **73** fuentes Swift de ZEUVEApp parseadas.
- `Scripts/verify/xcode_integration.py`: PASS; **10** productos SwiftPM/Xcode coherentes.
- Validación sintáctica de scripts shell y `compileall` de Scripts/Tests: PASS.
- Proyecto Xcode regenerado correctamente para marketing `0.18.0`, build `63` y 73 fuentes Swift de ZEUVEApp.
- Build Xcode local en macOS tras la corrección de `MultimediaBatchViewModel`: PASS.

## Cobertura nueva

- normalización de límites configurables del lote;
- presets incluidos con UUID estables;
- persistencia de presets sin rutas, carpetas ni archivos;
- nombres de salida y estimación conservadora de espacio;
- secciones configurables de informes;
- historial agregado sin identidad privada;
- cola estrictamente secuencial;
- prohibición de seleccionar silenciosamente audio multitrack;
- ausencia de waveform/preview en batch;
- gestión centralizada y versionada de presets;
- superficie amplia de preferencias personalizables;
- renderizado perezoso de colas grandes;
- reintento de fallidos conservando la configuración del lote.

## Validaciones que no finalizaron en este entorno

`./Scripts/run_tests.sh` y `./Scripts/verify_project.sh` se lanzaron, pero sus ejecuciones combinadas excedieron el límite temporal del entorno remoto antes de devolver su estado final. Sus componentes relevantes se ejecutaron por separado y constan arriba como PASS.

`swift build -c release --jobs 1` se inició y alcanzó la compilación de módulos de producción sin registrar errores, pero no terminó dentro del límite de 300 segundos del entorno remoto; por tanto, no se marca como PASS.

`./Scripts/build_macos.sh Release` no puede ejecutarse aquí: el propio script exige macOS Apple Silicon con Xcode.

## Validación manual requerida en macOS

1. Selección múltiple y drag & drop de varios archivos.
2. Los cuatro presets incluidos.
3. Lote con archivos sin audio, una pista y varias pistas.
4. Continuación tras un archivo corrupto o incompatible.
5. Cancelación durante señal, sonoridad, espectrograma y exportación.
6. Reintento de fallidos conservando configuración.
7. Conflictos de nombres en informes/PNG sin sobrescritura.
8. Crear, editar, duplicar, eliminar y restaurar presets desde Ajustes.
9. Persistencia de preferencias/presets tras reiniciar ZEUVE.
10. Regresión del modo individual: reproducción, A/B, waveform, espectrograma, análisis, edición estructural y Undo/Redo.
11. Build Release, apertura real de la app, Hardened Runtime y motores ARM64.
