# Resultados de pruebas — ZEUVE 0.11.4

## Prueba real de Instagram público

El enlace `https://www.instagram.com/reels/DcWzMFPuXtg/` se ejecutó con el yt-dlp 2026.08.19 incluido, sin `--cookies`, sin `--cookies-from-browser` y sin cabecera Cookie. La descarga terminó correctamente y FFprobe confirmó un MP4 reproducible de 2.243.435 bytes, 33,233 segundos, vídeo VP9 de 576 × 1024 y audio AAC.

## Regresiones automáticas

`UniversalSocialDownloaderTests` supera 31 pruebas y 0 fallos. La cobertura nueva confirma el orden `yt-dlp` → `gallery-dl`, que un elemento público no recibe sesión, que un elemento privado sí puede recibirla y que una redirección a login ambigua no se clasifica por sí sola como contenido privado.

## Validación integral

- `Scripts/run_tests.sh`: 180 pruebas XCTest, 45 pruebas Swift Testing y 49 regresiones Python; 274 pruebas en total, 0 fallos.
- `Scripts/verify_engines_macos.sh Resources/Engines`: correcto para todos los motores obligatorios, incluido el árbol completo de yt-dlp 2026.08.19.
- `Scripts/verify_project.sh`: correcto; incluye compilación Swift de producción, controles estructurales, documentación, privacidad y compilación Xcode Debug en este Mac Apple Silicon.
- `Scripts/build_macos.sh Release`: `BUILD SUCCEEDED`; el paquete `ZEUVE.app` 0.11.4 (40), su firma profunda y los motores empaquetados superan la verificación.

Xcode solo informa de la nota esperada de que las fases de firma y verificación de motores se ejecutan en cada compilación y del aviso informativo de que no hay símbolos de App Intents que extraer. No se generó ningún ZIP.
