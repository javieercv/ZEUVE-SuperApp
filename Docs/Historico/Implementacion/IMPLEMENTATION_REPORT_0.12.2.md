# Informe de implementación — ZEUVE 0.12.2

## Resultado

ZEUVE 0.12.2 completa el saneamiento interno del Descargador universal como refactor sin cambios funcionales. El target principal pasa de `YouTubeDownloaderModule` a `UniversalDownloaderModule`, la integración de aplicación utiliza `Sources/ZEUVEApp/UniversalDownloader` y los tests se agrupan bajo `UniversalDownloaderModuleTests`.

El cambio diferencia nombres y ubicación por responsabilidad real: coordinación universal, servicios comunes, lógica específica de plataforma y lógica específica de motor. No se crean targets adicionales ni jerarquías abstractas para plataformas o motores que no las necesitan.

## Organización interna

El módulo queda organizado por `Analysis`, `Download`, `Models`, `Engines`, `Platforms`, `Publishing`, `Files`, `Storage`, `Validation` y `Discovery`.

Los coordinadores globales adoptan nombres universales, entre ellos `UniversalDownloaderViewModel`, `UniversalDownloadAnalysisService` y `UniversalDownloadService`. Builders, parsers, formatos, caché y política de fragmentos que pertenecen realmente a yt-dlp utilizan nombres `YTDLP*`. La canonicalización de URLs de YouTube permanece como `YouTubeURLCanonicalizer`, y la sesión, el catálogo y el histórico de fotografías de perfil de Instagram conservan una identidad propia de esa plataforma.

El ViewModel delega la carga y migración de ajustes en `UniversalDownloaderSettingsStore`, la construcción inmutable de operaciones en `UniversalDownloadPlanBuilder` y la gestión de sesión de Instagram en un controlador específico de la aplicación. El servicio de análisis delega las ejecuciones concretas de yt-dlp, gallery-dl e Instagram en adaptadores internos, y el servicio de descarga extrae la validación de salida y la política de respaldo de TikTok sin cambiar su orden de ejecución.

La vista principal se separa de las vistas de catálogo y finalización. Las vistas del Descargador se separan físicamente de `SettingsView.swift`, pero la configuración continúa centralizada en `SettingsView` y `SettingsRepository`.

## Compatibilidad

Se conservan sin alterar el identificador histórico `com.zeuve.youtube-downloader`, las claves `youtube.defaultSettings`, `youtube.defaultAdvancedMode`, `youtubeDownloader.presets` y `youtubeDownloader.outputFolderBookmark`, y las claves universales ya vigentes. `UniversalDownloaderStorageKeys` distingue expresamente el espacio actual del namespace `Legacy`; las migraciones copian al espacio universal cuando procede y no eliminan las claves antiguas.

`DownloadCatalogItem` expone internamente `canonicalID`, pero conserva `videoID` como nombre codificado privado para mantener compatibilidad con datos históricos. También se mantienen la ruta temporal histórica `Temporary/YouTube`, valores crudos y `CodingKeys` persistidos, los identificadores históricos de historial, las categorías técnicas de diagnóstico y el prefijo técnico de error existente.

## Comportamiento, seguridad y dependencias

No cambian la selección ni el orden de motores, los argumentos enviados a los motores, los fallbacks, formatos, publicación, historial, presets, cancelación ni `OperationCoordinator`. No cambian Internet, APIs, cabeceras, cookies, sesiones, proxy, DRM, CAPTCHA, paywalls ni reglas de privacidad.

La protección de originales, los temporales seguros, la publicación sin sobrescritura silenciosa, la limpieza limitada a archivos propiedad de la operación y la ejecución de procesos con argumentos separados permanecen intactas.

No se añade ninguna dependencia externa ni interna. Los motores y versiones fijados siguen siendo los mismos que en la base 0.12.1; la documentación vigente de motores y empaquetado adopta nombres universales sin modificar el comportamiento de preparación o ejecución.

## Versiones

- ZEUVE: 0.12.2.
- Build interno: 44.
- Descargador universal: 0.7.2.

El proyecto Xcode se regeneró mediante `Scripts/generate_xcode_project.py`; no se editó manualmente `project.pbxproj`.

## Corrección adicional del script de integración de YouTube

Tras la autorización final para completar el saneamiento, `Scripts/run_youtube_integration_tests_macos.sh` corrige el uso de la variable inexistente `WORK` y utiliza el workspace temporal propio `TEMP` para la caché de yt-dlp. El script conserva su nombre porque sus pruebas siguen siendo realmente específicas de YouTube/yt-dlp. La corrección solo afecta al arnés opcional de integración online y no modifica el comportamiento del Descargador universal.

La regresión `testUniversalYTDLPArchitectureHeadersDoNotBlockDiagnostics` se limita ahora al entorno en el que su afirmación es válida —macOS Apple Silicon—; fuera de él se omite explícitamente en lugar de exigir `.ready` a un diagnóstico diseñado para devolver `.unsupportedPlatform`. Este ajuste afecta únicamente al arnés de pruebas.
