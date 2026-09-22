# Resultados de pruebas — ZEUVE 0.11.2

Fecha: 22 de agosto de 2026.

## TikTok real

- Caso: `https://www.tiktok.com/@user72728929191/video/7661387983458700566`.
- El análisis con gallery-dl 1.32.9 incluido terminó correctamente sin cookies ni sesión.
- La descarga con la URL estable, `--range 1` y las mismas opciones de ZEUVE terminó correctamente.
- FFprobe confirmó MP4 con vídeo H.264 576×1024, audio AAC, duración 15 segundos y tamaño 2.111.156 bytes.
- Se reprodujo HTTP 403 al reutilizar directamente la primera URL firmada, confirmando la necesidad de conservar los fallbacks del motor.

## Regresiones automatizadas

- `swift test --filter UniversalSocialDownloaderTests`: 26 pruebas superadas, 0 fallos.
- `Scripts/run_tests.sh`: suites Swift, Swift Testing y Python superadas, 0 fallos.
- Las pruebas cubren clasificación `/video/` y `/photo/`, enrutado TikTok, protocolo actual y heredado, opciones compatibles, selección por rango y política obligatoria de motores sociales.

## Validación de proyecto y paquete

- `Scripts/verify_project.sh`: superado, con 175 pruebas XCTest, 45 pruebas Swift Testing, 48 pruebas Python, compilación Swift Release y compilación Xcode Debug.
- `Scripts/build_macos.sh Release`: superado desde producto limpio para macOS ARM64.
- Los seis motores obligatorios superan presencia, hash, arquitectura y diagnóstico antes del empaquetado.
- yt-dlp y Deno conservan sus firmas oficiales; FFmpeg, FFprobe, gallery-dl e instaloader-zeuve quedan firmados dentro de la aplicación.
- gallery-dl e instaloader-zeuve se ejecutan correctamente después de la firma con su autorización PyInstaller limitada.
- `codesign --verify --deep --strict` acepta `ZEUVE.app` Release.
