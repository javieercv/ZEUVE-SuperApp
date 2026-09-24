# Compilación y entrega — ZEUVE 0.20.4.0

## Estado de versión

- ZEUVE: `0.20.4.0` (`VERSION`).
- `MARKETING_VERSION`: `0.20.4`.
- Revisión bundle: `0`.
- Build: `70`.
- Plataforma objetivo: macOS 14+ Apple Silicon.
- Swift 6, SwiftUI/AppKit, Hardened Runtime, sin App Sandbox en esta fase.

Versiones de módulos: Organizador 0.1.4, Descargador 0.7.3, Analizador de chats 0.1.6, Conversor 0.3.0, Comparador 0.1.0, Inspector 0.7.2 y Limpiador 0.1.2.

## Requisitos

La validación completa requiere un Mac Apple Silicon con Xcode compatible. Python 3 se usa en scripts y verificadores. Algunos pasos de preparación/firma requieren artefactos locales aprobados, Internet o credenciales de firma según el entorno de desarrollo.

SwiftPM permite ejecutar una parte importante de los tests, pero una ejecución en Linux no equivale a validar Xcode, SwiftUI/AppKit, firmas o motores ARM64.

## Motores

La instantánea actual de `Resources/Engines/engines.json` contiene como requeridos yt-dlp, Deno, FFmpeg, FFprobe, gallery-dl e instaloader-zeuve. Pandoc es opcional y puede incorporarse durante la preparación aprobada del Conversor. Calibre, Ghostscript y LibreOffice están retirados.

Preparación/verificación en macOS ARM64:

```bash
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh
```

Los motores sociales se preparan con `Scripts/prepare_social_engines_macos.sh` cuando corresponde. La compilación normal no debe descargar o actualizar motores silenciosamente.

## Pruebas y verificación

Desde la raíz:

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
```

`run_tests.sh` ejecuta SwiftPM y los tests Python de `Tests/ScriptTests`.

`verify_project.sh` añade verificadores estructurales, manifests, documentación, políticas de motores, coherencia Xcode y validaciones adicionales; el cierre real de app sigue dependiendo de macOS Apple Silicon.

## Build de macOS

```bash
./Scripts/build_macos.sh Debug
./Scripts/build_macos.sh Release
```

El script exige macOS ARM64/Xcode, valida la preparación necesaria, genera/verifica el proyecto Xcode, construye la app, comprueba motores empaquetados y aplica la política de firma correspondiente. No debe sustituirse por comandos de shell ad hoc que eviten los verificadores.

## Firma de motores

- yt-dlp conserva su firma oficial cuando la distribución aprobada ya la incluye.
- Deno conserva su firma oficial y sus entitlements necesarios para JIT.
- FFmpeg, FFprobe, gallery-dl, instaloader-zeuve y Pandoc cuando está incluido se firman con la identidad de ZEUVE según los scripts aprobados.
- Los ejecutables sociales generados con PyInstaller usan los entitlements específicos previstos por el proyecto.
- `verify_packaged_engines_macos.sh` recorre el manifiesto de motores; no está limitado a un número fijo de cuatro firmas.

## Validación de la app

La validación final debe realizarse sobre la `.app` construida en macOS Apple Silicon y comprobar, según el flujo vigente:

- arquitectura y recursos;
- ejecutables/motores requeridos;
- firmas y Hardened Runtime;
- ausencia de dependencias inesperadas;
- lanzamiento y recorrido manual pertinente.

No afirmar que una app “compila y abre” si solo se ha ejecutado SwiftPM o verificadores portables.

## Empaquetado

`python3 Scripts/package_release.py` se usa solo cuando se solicita preparar una entrega empaquetada. Mantén actualizada la carpeta activa `ZEUVE_*`; no crees una carpeta versionada paralela ni un ZIP por defecto.

La limpieza del proyecto no debe borrar `Resources/Engines`, manifests, licencias ni recursos necesarios. Artefactos de `.build`, DerivedData, logs o resultados temporales sí deben distinguirse del código fuente.
