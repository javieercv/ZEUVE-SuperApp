# Compilación y entrega — ZEUVE 0.21.0.0

## Estado de versión

- ZEUVE: `0.21.0.0` (`VERSION`).
- Versión visible de desarrollo y marketing: `0.21.0.0`.
- `MARKETING_VERSION`/`CFBundleShortVersionString` internos Apple: `0.21.0`.
- Revisión bundle: `0`.
- Build: `79`.
- Plataforma objetivo: macOS 14+ Apple Silicon.
- Swift 6, SwiftUI/AppKit, Hardened Runtime, sin App Sandbox en esta fase.

Versiones de módulos: Organizador 0.1.5, Descargador 0.7.8, Analizador de chats 0.1.6, Conversor 0.3.2, Comparador 0.1.0, Inspector 0.7.5 y Limpiador 0.1.4.

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

## Empaquetado de utilidades residentes

`ZEUVEQuickUtilities` está integrado en SwiftPM y en el generador Xcode con sus tests. Usa frameworks del sistema AppKit, CoreGraphics, ApplicationServices, Carbon/HIToolbox, ServiceManagement y Core Audio. La app continúa con Hardened Runtime y sin App Sandbox. No se añade una app independiente, driver, KEXT, helper privilegiado ni extensión de Finder.

`Resources/ZEUVE-Info.plist` conserva la revisión expandida y declara la explicación de captura de audio y los Servicios de creación/texto. La firma efectiva debe incluir Hardened Runtime y `com.apple.security.device.audio-input`, sin App Sandbox. `build_macos.sh` comprueba estos valores extraídos de la firma final; no habilitan TCC por sí solos. El generador conserva `--options runtime` también con firma ad hoc, que no sustituye una identidad Developer ID ni notarización. La verificación nativa usa `build/VerificationDerivedData` para preservar compilaciones abiertas desde DerivedData del usuario. Los Servicios deben registrarse y verificarse en aplicaciones host reales después de instalar/abrir la app. El inicio de sesión necesita comprobar el estado efectivo de `SMAppService`, nunca basta guardar una preferencia.

La versión de desarrollo y marketing que se muestra al usuario es siempre `0.21.0.0`; el triple interno Apple no representa otra entrega. Las validaciones y limitaciones se registran en [TEST_RESULTS_0.21.0.0](../Historico/Pruebas/TEST_RESULTS_0.21.0.0.md).
