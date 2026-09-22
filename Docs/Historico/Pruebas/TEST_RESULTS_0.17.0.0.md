# Resultados de pruebas — ZEUVE 0.17.0.0

Fecha: 21 de septiembre de 2026.
Entorno: pruebas portables documentadas en Linux x86_64 con Swift 6.2.1; validación adicional de compilación desde Xcode en macOS.

## PASS completados

- `BuildProject` desde Xcode: PASS tras restaurar el estado publicado de extracción de attachments del Inspector multimedia.
- `swift build --target MultimediaInspectorModule --jobs 2`: PASS.
- `swift build --target MultimediaInspectorModuleTests --jobs 2`: PASS.
- `swift test --skip-build --filter MultimediaInspectorModuleTests`: **93/93 Swift Testing**, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: **95/95**, 0 fallos.
- `python3 Scripts/verify/multimedia_inspector.py`: PASS.
- `python3 Scripts/verify/project_structure.py`: PASS.
- `python3 Scripts/verify/xcode_integration.py`: PASS; 10 productos SwiftPM/Xcode coherentes.
- `python3 Scripts/validate_module_docs.py`: PASS.
- `python3 Scripts/verify/documentation.py`: PASS.
- Proyecto Xcode regenerado para build 62 / marketing 0.17.0.

## Cobertura nueva relevante

- Carga de capítulos/attachments/metadata en el draft y participación en Undo/Redo.
- Rechazo de capítulos duplicados o fuera de duración.
- Escapado seguro del FFmetadata de capítulos.
- `Preservar metadatos` independiente de capítulos.
- Command builder con capítulos, attachments y metadata en una única planificación.
- Validación de filename/MIME/fingerprint de attachments externos.
- Propuesta MKV para attachments sin permitir transcode audiovisual.
- Regresiones del análisis avanzado, A/B, waveform, espectrograma y preview continúan en la suite del Inspector.

## Ejecuciones que no finalizaron en este entorno

- `./Scripts/run_tests.sh`: inició y ejecutó las suites sin registrar fallos en la salida observada, pero la ejecución completa alcanzó el límite temporal del entorno antes de devolver estado final.
- La suite Swift global mediante `swift test --skip-build` también alcanzó el límite temporal remoto antes de finalizar; no se registró un fallo antes del corte.
- `./Scripts/build_macos.sh Release` requiere macOS Apple Silicon con Xcode y debe ejecutarse en el entorno objetivo.

## Validación manual recomendada en macOS

1. Abrir un MKV con vídeo, varios audios, subtítulos, capítulos y al menos un attachment real.
2. Editar/añadir/eliminar capítulos y comprobar waveform + `⌘Z`/`⇧⌘Z`.
3. Añadir/eliminar/renombrar un attachment y extraer uno existente.
4. Editar título/artista/comentario y título/idioma de streams.
5. Generar el archivo y volver a abrirlo en el Inspector para verificar que coincide con el plan.
6. Repetir Play/Pausa, seek y A/B para confirmar ausencia de regresiones en el reproductor.
7. Ejecutar `./Scripts/build_macos.sh Release` y la validación real de la app en macOS Apple Silicon.
