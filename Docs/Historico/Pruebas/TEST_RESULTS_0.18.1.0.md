# Resultados de pruebas — ZEUVE 0.18.1.0

Fecha: 21 de septiembre de 2026.  
Entorno: Linux x86_64 con Swift 6.2.1.

## PASS

- Inspector multimedia: **99/99 Swift Testing**, 0 fallos.
- Suite Swift global observada durante la ejecución de la suite: **154/154 Swift Testing**, 0 fallos.
- Suites XCTest portables: **215 tests**, 0 fallos y **1 omitido** intencionadamente porque el diagnóstico ejecutable de yt-dlp requiere macOS Apple Silicon.
- Pruebas Python de `Tests/ScriptTests`: **107/107**, 0 fallos.
- Regresiones específicas de ayuda contextual: **5/5**, 0 fallos.
- `swift build --target MultimediaInspectorModule --jobs 1`: PASS.
- `Scripts/verify/app_integration.py`: PASS.
- `Scripts/verify/project_structure.py`: PASS.
- `Scripts/verify/engines.py`: PASS.
- `Scripts/verify/documentation.py`: PASS.
- `Scripts/verify/performance.py`: PASS.
- `Scripts/verify/converter.py`: PASS.
- `Scripts/verify/downloader.py`: PASS.
- `Scripts/verify/chat_analyzer.py`: PASS.
- `Scripts/verify/instagram_followers.py`: PASS.
- `Scripts/verify/multimedia_inspector.py`: PASS.
- `Scripts/verify/manifests.py`: PASS.
- `Scripts/validate_module_docs.py`: PASS.
- `Scripts/verify/app_sources.py`: PASS; **73** fuentes Swift de ZEUVEApp parseadas.
- `Scripts/generate_xcode_project.py`: proyecto Xcode regenerado para marketing `0.18.1`, build `64` y 73 fuentes Swift de ZEUVEApp.
- `Scripts/verify/xcode_integration.py`: PASS; **10** productos SwiftPM/Xcode coherentes.
- Sintaxis Bash de los scripts de build/verificación y `compileall` de scripts/tests: PASS.

## Cobertura de 0.18.1.0

- ayuda general obligatoria en Resumen, Pistas, Espectrograma, Metadatos y Lote;
- ayuda contextual en todos los bloques técnicos aprobados de Ajustes → Inspector multimedia;
- cobertura específica de LUFS/LRA/True Peak/Sample Peak/Short-term;
- sincronización técnica y análisis parcial;
- silencios y Posible clipping;
- FFT, ventana, rango dinámico, Nyquist, escala y canales;
- capítulos, attachments/MIME y metadatos;
- comparación A/B, flags de pista e informes;
- configuración y estados del modo lote;
- prohibición de iconos `info.circle` paralelos dentro del Inspector;
- reutilización obligatoria de `ContextualHelpButton` y componentes `Help*` compartidos.

## Validaciones que no finalizaron en este entorno

`./Scripts/run_tests.sh` se inició y completó las suites Swift antes de entrar de nuevo en las pruebas de scripts, pero la ejecución combinada superó el límite temporal remoto antes de devolver su código final. Las suites Swift y Python relevantes se ejecutaron por separado y constan arriba como PASS.

`./Scripts/verify_project.sh` se inició, pero permaneció dentro de la compilación SwiftPM Release hasta superar el límite temporal remoto. Una ejecución separada de `swift build -c release --jobs 1` también superó el límite después de avanzar por módulos de producción sin registrar errores. Por ello, la build Release completa no se declara como PASS.

`./Scripts/build_macos.sh Release` y la ejecución real de `ZEUVE.app` requieren macOS Apple Silicon con Xcode.

## Validación manual requerida en macOS

1. Recorrer Ajustes → Inspector multimedia y comprobar los iconos de información de todas las opciones técnicas.
2. Abrir ayuda general en Resumen, Pistas, Espectrograma, Metadatos y Lote.
3. Comprobar ayuda específica de LUFS/LRA/peaks, sincronización, señal, FFT/Nyquist, capítulos, attachments, metadatos, A/B e informes.
4. Verificar navegación por teclado y lectura de VoiceOver del botón/popup compartido.
5. Revisar modo claro y oscuro y ventanas estrechas para descartar solapes o saltos de layout.
6. Abrir/cerrar ayudas durante reproducción y análisis y confirmar que no cambia Play/Pausa, pista, progreso ni resultados.
7. Repetir una regresión rápida del modo individual y lote para confirmar que no se ha alterado ninguna operación multimedia.
8. Ejecutar build Release/Xcode y validación de motores ARM64.
