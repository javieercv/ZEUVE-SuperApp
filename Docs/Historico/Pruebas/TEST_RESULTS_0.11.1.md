# Resultados de pruebas — ZEUVE 0.11.1

Fecha: 21 de agosto de 2026.

## Diagnóstico reproducido

- El enlace público `BM1evFP2fds` se analizó sin cookies ni sesión.
- La transferencia completa con la ruta anterior reprodujo HTTP 403; una prueba parcial de 10 KiB no era suficiente para detectarlo.
- La transferencia completa de audio MP3 y vídeo 360p terminó correctamente al usar el cliente público `web_embedded` sin sesión.
- La cadena definitiva `web_embedded,web_safari` terminó correctamente en la transferencia completa de audio y conserva un respaldo HLS.

## Regresiones automatizadas

- `swift test --filter YouTubeDownloaderModuleTests --jobs 1`: 72 pruebas superadas, 0 fallos.
- Las nuevas pruebas comprueban la cadena anónima en análisis y descarga, que no afecta a otras plataformas, que no se impone con una sesión expresa y que HTTP 403 o PO token no solicitan automáticamente un navegador.

## Validación de entrega

- `Scripts/run_tests.sh`: 173 pruebas XCTest, 45 pruebas Swift Testing y 48 pruebas Python superadas, sin fallos.
- `Scripts/verify_project.sh`: superado, incluida la compilación Swift Release y la compilación Xcode de validación.
- `Scripts/build_macos.sh Release`: superado desde producto limpio para macOS ARM64.
- Los motores empaquetados superan firma, versión y ejecución; Deno evalúa JavaScript con su JIT y `codesign --verify --deep --strict` acepta la aplicación completa.
- Descarga real predeterminada con los motores del paquete: vídeo 4K completo de 289.519.390 bytes, duración 228,754 s, pista AV1 y audio Opus, sin cookies ni sesión.
- Descarga real final tras la compilación limpia: MP4 completo de 11.351.043 bytes, duración 228,856 s, H.264 480×360 y AAC, sin cookies ni sesión.
- Los archivos de prueba se crearon únicamente bajo `/private/tmp` y se eliminaron al terminar.

El controlador de interfaz llegó a abrir la aplicación Release y mostrar su inicio, pero perdió la conexión al seleccionar el módulo. Por ello no se presenta esa interacción como prueba de descarga visual. La transferencia final se ejecutó directamente con yt-dlp, Deno y FFmpeg del paquete Release y con los mismos argumentos anónimos generados por el Descargador.
