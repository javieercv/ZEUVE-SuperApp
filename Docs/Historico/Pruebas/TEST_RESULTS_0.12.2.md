# Resultados de pruebas — ZEUVE 0.12.2

## Cobertura específica del saneamiento

La cobertura del Descargador universal comprueba el nuevo target y manifiesto, la nomenclatura universal, las claves actuales y legacy, la migración de defaults y modo avanzado, presets, historial, modelos, routing, construcción de comandos, parsers, perfiles, validación, publicación, cancelación y coordinación de operaciones. También se comprueba que `DownloadCatalogItem` siga codificando el identificador histórico como `videoID` aunque la API Swift vigente exponga `canonicalID`.

Las suites mantienen cobertura específica de YouTube, yt-dlp, Instagram, TikTok, gallery-dl, instaloader-zeuve, páginas genéricas y descarga HTTP directa.

La corrección final de `Scripts/run_youtube_integration_tests_macos.sh` añade dos regresiones Python: la caché debe usar el workspace temporal propio `TEMP` y el script debe conservar tanto el opt-in explícito como la restricción a macOS Apple Silicon.

## Resultados ejecutados en este entorno

- `swift test --filter UniversalDownloaderModuleTests --jobs 1`: 97 de 97 pruebas correctas.
- `swift test --jobs 1`: 198 XCTest ejecutadas, 197 correctas, 1 omitida expresamente por plataforma y 0 fallos; además, 45 de 45 pruebas Swift Testing correctas.
- La única prueba omitida es `EngineRegistryTests.testUniversalYTDLPArchitectureHeadersDoNotBlockDiagnostics`, que requiere ejecutar realmente el binario macOS de yt-dlp y ahora queda limitada de forma explícita a macOS Apple Silicon.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: 54 de 54 regresiones correctas.
- `swift build -c release --target UniversalDownloaderModule --jobs 1`: correcta.
- `swift build -c release --jobs 4`: correcta para el paquete Swift completo.
- Regeneración de `ZEUVE.xcodeproj` con `Scripts/generate_xcode_project.py`: correcta; el proyecto generado referencia `UniversalDownloaderModule`, las vistas separadas y ZEUVE 0.12.2 build 44.
- La parte estructural de `Scripts/verify_project.sh` —documentación, manifiestos, scripts, regresiones Python, parseo Swift, generación Xcode y políticas de seguridad— se ejecutó correctamente.
- `bash -n Scripts/run_youtube_integration_tests_macos.sh`: correcto.

El comando canónico `./Scripts/verify_project.sh` también se intentó de forma integral. En este entorno de ejecución la invocación única supera el límite temporal disponible mientras recompila el paquete Release después de la suite Swift. Sus componentes obligatorios se ejecutaron por separado y resultaron correctos, por lo que no se oculta ningún fallo conocido detrás de ese límite de tiempo.

## Limitaciones del entorno

El entorno disponible es Linux x86_64, no macOS Apple Silicon. Por ello no pueden declararse validadas aquí:

- compilación Xcode Debug/Release ARM64;
- firma y Hardened Runtime de la aplicación final;
- arranque real de la app macOS;
- diagnóstico y ejecución real de los motores macOS;
- pruebas online contra plataformas externas.

Estas comprobaciones deben ejecutarse en el Mac Apple Silicon previsto por `Docs/BUILDING.md` antes de considerar validada una distribución macOS firmada.

## Privacidad de las pruebas

El saneamiento y las pruebas ejecutadas no necesitaron tráfico de red. No se incorporaron URLs privadas, cookies, tokens, credenciales, cabeceras ni listas privadas a los informes.

Las pruebas online de YouTube continúan desactivadas por defecto y requieren tanto `ZEUVE_ENABLE_YOUTUBE_INTEGRATION_TESTS=1` como una `ZEUVE_YOUTUBE_TEST_URL` pública y autorizada. La descarga real requiere además `ZEUVE_YOUTUBE_ALLOW_DOWNLOAD=1`.
