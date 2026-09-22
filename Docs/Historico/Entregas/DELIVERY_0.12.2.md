# Entrega — ZEUVE 0.12.2

## Estado

La carpeta activa `ZEUVE_Swift` contiene ZEUVE 0.12.2, build 44, y Descargador universal 0.7.2. El saneamiento interno y la corrección final del arnés de integración de YouTube están completados.

A petición expresa del usuario, esta entrega incluye además un ZIP limpio y completo de la carpeta activa, generado con `Scripts/package_release.py` después de la validación disponible.

## Cambio entregado

El Descargador universal utiliza `UniversalDownloaderModule` como target canónico y una organización interna coherente con su función actual. Los coordinadores y servicios compartidos dejan de presentarse como componentes de YouTube, mientras que la lógica realmente específica de YouTube, Instagram, TikTok o de motores concretos conserva nombres y ubicación propios.

Se separan modelos, análisis, descarga, motores, plataformas, publicación, archivos, almacenamiento, validación y descubrimiento. ViewModel, vista y Ajustes se dividen solo en responsabilidades identificables, sin alterar la interfaz ni crear un segundo sistema de configuración.

También se corrige `Scripts/run_youtube_integration_tests_macos.sh`: la caché de yt-dlp utiliza el workspace temporal `TEMP` que posee el propio script, eliminando el uso de la variable inexistente `WORK`. El nombre del script se conserva porque las pruebas siguen siendo específicas de YouTube/yt-dlp.

## Compatibilidad y comportamiento

Se preservan los identificadores y claves legacy, el formato histórico `videoID`, los valores codificados, el historial anterior y la ruta temporal histórica necesaria. No se cambian motores, algoritmos, argumentos, formatos, fallbacks, red, sesiones, privacidad, publicación, historial, presets, cancelación, `OperationCoordinator`, protección de archivos ni reglas de acceso.

No se añaden dependencias.

## Validación disponible

- Descargador universal: 97/97 pruebas correctas.
- Suite Swift completa: 198 XCTest, 0 fallos y 1 omisión explícita por plataforma; 45/45 Swift Testing correctas.
- Regresiones Python: 54/54 correctas.
- `UniversalDownloaderModule` compila correctamente en Release.
- El paquete Swift completo compila correctamente en Release.
- Las comprobaciones estructurales, documentación, manifiestos, scripts, parseo Swift y regeneración de Xcode son correctas.

La validación definitiva de una aplicación macOS distribuible queda pendiente de ejecutarse en Mac Apple Silicon: Xcode Debug/Release ARM64, firma, Hardened Runtime, apertura real, diagnóstico/ejecución de motores y pruebas online autorizadas.

## Empaquetado

El ZIP final se genera limpio: no incluye `.build`, `build`, `DerivedData`, `.swiftpm`, `xcuserdata`, `__pycache__`, `.DS_Store`, `__MACOSX`, logs ni artefactos temporales. Incluye código fuente completo, recursos, módulos, pruebas, documentación, scripts, configuración, changelog y versión.
