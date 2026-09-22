# Informe de implementación 0.10.4

## Resumen

ZEUVE 0.10.4 corrige la preparación del motor utilizado para resolver perfiles públicos de Instagram. El registro aportado mostraba que la aplicación reconocía correctamente las URLs de perfil, pero `instaloader-zeuve 4.15.2-zeuve.3` devolvía una resolución no concluyente y el fallback público tampoco obtenía el catálogo. La versión oficial Instaloader 4.15.3, publicada el 26 de julio de 2026, incluye una corrección específica para la resolución de perfiles.

No se ha cambiado la interfaz, el modelo de sesiones, el fallback a `gallery-dl`, el tratamiento de perfiles privados ni ninguna parte no relacionada del Descargador universal.

## Cambios realizados

### Actualización del motor

- `Scripts/prepare_social_engines_macos.sh` fija Instaloader 4.15.3 y genera `instaloader-zeuve 4.15.3-zeuve.1`.
- `Scripts/prepare_engines_macos.sh` utiliza la misma versión cuando se prepara el conjunto completo de motores.
- `Scripts/engine_helpers/instagram_catalog.py` informa la revisión nueva sin alterar el contrato JSON ni el flujo existente.
- `Scripts/check_social_engines.py` rechaza motores ausentes, incompletos o distintos de `4.15.3-zeuve.1`.
- `Scripts/refresh_social_engine_manifest.py` registra la versión, tamaño y SHA-256 del ejecutable nuevo después de generarlo.

### Protección frente al motor obsoleto

El ejecutable ARM64 `4.15.2-zeuve.3` se ha retirado de la copia fuente. La entrada de `Resources/Engines/engines.json` queda como marcador seguro de `4.15.3-zeuve.1`, con tamaño cero y SHA-256 vacío, hasta que el motor se genere realmente en macOS Apple Silicon.

Una compilación por Terminal o desde Xcode detectará el marcador y ejecutará la preparación social antes de copiar los recursos. Así se evita producir otra aplicación que incluya el motor defectuoso.

### Versionado

- ZEUVE: 0.10.3 → 0.10.4.
- Build interno: 34 → 35.
- Descargador universal: 0.6.3 → 0.6.4.
- Motor especializado: `4.15.2-zeuve.3` → `4.15.3-zeuve.1`.

## Archivos principales modificados

- `VERSION`
- `CHANGELOG.md`
- `README.md`
- `PROJECT_DECISIONS.md`
- `Scripts/prepare_social_engines_macos.sh`
- `Scripts/prepare_engines_macos.sh`
- `Scripts/check_social_engines.py`
- `Scripts/refresh_social_engine_manifest.py`
- `Scripts/engine_helpers/instagram_catalog.py`
- `Scripts/verify_project.sh`
- `Scripts/generate_xcode_project.py`
- `ZEUVE.xcodeproj/project.pbxproj`
- `Resources/Engines/engines.json`
- `Resources/Engines/licenses/instaloader/NOT_PROVIDED.txt`
- `Sources/YouTubeDownloaderModule/Resources/manifest.json`
- `Sources/YouTubeDownloaderModule/Discovery/UniversalPageDiscovery.swift`
- `Sources/ZEUVEApp/SettingsView.swift`
- `Tests/ScriptTests/test_social_engine_preparation_policy.py`
- `Tests/YouTubeDownloaderModuleTests/YouTubeFilesStorageAndManifestTests.swift`
- documentación de compilación, motores y Descargador universal.

## Archivos retirados

- `Resources/Engines/instaloader/instaloader-zeuve`, porque contenía la revisión ARM64 obsoleta 4.15.2.
- `Resources/Engines/licenses/instaloader/LICENSE`, que se volverá a copiar desde la distribución fijada al generar el ejecutable 4.15.3.

## Privacidad y dependencias

No se añaden servidores, proxies, APIs, telemetría, procesos en segundo plano ni dependencias para el usuario final. La preparación sigue utilizando Python, PyInstaller e Internet únicamente en el Mac de desarrollo para crear un ejecutable ARM64 autosuficiente que se incluye dentro de la aplicación.

## Limitación de validación

El entorno disponible es Linux x86_64. Se ha validado la lógica, el versionado, las políticas de preparación y la compilación Swift, pero no se ha podido generar, firmar ni ejecutar el binario macOS ARM64 `instaloader-zeuve 4.15.3-zeuve.1`. Tampoco se ha abierto la aplicación nativa ni se ha realizado una consulta real a Instagram desde un Mac Apple Silicon.
