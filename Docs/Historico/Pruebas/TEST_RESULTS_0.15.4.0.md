# Resultados de pruebas — ZEUVE 0.15.4.0

Fecha: 19 de septiembre de 2026.

## Entorno disponible

Linux x86_64 con Swift 6.2.1. Permite validar SwiftPM, lógica portable y verificadores de código/documentación, pero no ejecutar la UI SwiftUI/AppKit ni AVFoundation reales de macOS.

## Inspector multimedia

Comando final ejecutado:

```bash
swift test --jobs 8 --filter MultimediaInspectorModuleTests
```

Resultado: **67 tests Swift Testing, 0 fallos**.

También se ejecutó:

```bash
swift build --jobs 8 --target MultimediaInspectorModuleTests
```

Resultado: **PASS**. El target portable del Inspector y sus tests compilan.

Durante la primera ejecución después del incremento de versión apareció un único fallo esperado: el test del manifiesto seguía esperando `0.3.3`. Se actualizó a `0.3.4` y la repetición final terminó con 67/67 tests correctos.

## Tests Python

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado: **83 tests, 0 fallos**.

## Verificadores

Pasaron en ejecución directa los verificadores de integración de aplicación, estructura/versionado, motores, documentación, rendimiento, Conversor universal, Descargador universal, Analizador de chats, Comparador de seguidores, Inspector multimedia y manifiestos.

Además:

- `Scripts/verify/app_sources.py`: **70 fuentes Swift** de ZEUVEApp parseadas correctamente.
- `Scripts/validate_module_docs.py`: documentación de módulos y ejemplos JSON válida.
- `Scripts/generate_xcode_project.py`: proyecto Xcode regenerado desde su fuente canónica.
- `Scripts/verify/xcode_integration.py`: **10 productos** SwiftPM/Xcode coherentes.
- Validación `bash -n` de los scripts principales: PASS.

## Orquestador global

`./Scripts/verify_project.sh` se intentó. Ejecutó una parte amplia de la suite global, pero superó el límite de tiempo disponible antes de completar también el build Release y el resto de pasos. No se registra para este comando un PASS ni un FAIL global.

## Build macOS

`./Scripts/build_macos.sh Release` devuelve en este entorno:

> Esta compilación requiere macOS Apple Silicon con Xcode.

Queda pendiente en un Mac Apple Silicon verificar la build Release nativa y los cuatro casos manuales críticos:

1. Espectrograma → reproducir → pausar desde Espectrograma.
2. Espectrograma → reproducir → pausar desde Pistas.
3. Pistas → reproducir → pausar desde Pistas.
4. Pistas → reproducir → pausar desde Espectrograma.

También debe comprobarse la reanudación desde ambas pestañas y desde la barra inferior.
