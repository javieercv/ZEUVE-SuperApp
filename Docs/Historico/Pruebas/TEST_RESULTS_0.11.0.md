# Resultados de pruebas — ZEUVE 0.11.0

Fecha: 6 de agosto de 2026.

## Pruebas superadas

- `swift test --jobs 1`: superado después de retirar los residuos AppleDouble del ZIP fuente.
  - 166 pruebas XCTest superadas.
  - 45 pruebas adicionales de Swift Testing superadas.
  - Total observado: 211 pruebas Swift sin fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: 48 pruebas superadas.
- `swift build -c release --target UniversalConverterModule --jobs 1`: superado; valida en configuración release el módulo modificado y sus dependencias.
- Sintaxis Bash de `verify_project.sh`, `prepare_engines_macos.sh`, `sign_embedded_engines.sh`, `verify_engines_macos.sh` y `verify_packaged_engines_macos.sh`: superada.
- Lectura JSON de `Resources/Engines/engines.json`: superada.
- Comprobación de ausencia física de Calibre, Ghostscript, sus constructores y licencias: superada.
- Comprobación de que Pandoc permanece registrado: superada.
- Protección del ZIP original mediante SHA-256: comprobada.

## Incidencia detectada y resuelta

La primera ejecución de la suite encontró archivos ocultos `._*.swift` procedentes del empaquetado en macOS. Una prueba general intentaba leerlos como texto y falló porque son metadatos AppleDouble. Se eliminaron esos residuos del proyecto de entrega, sin modificar archivos funcionales, y la suite completa pasó después.

## Pruebas no completadas

La compilación release de todos los módulos mediante `swift build -c release --jobs 1` fue interrumpida por el límite temporal del entorno Linux en cuatro intentos de 5, 5, 10 y 5 minutos. No mostró errores de código antes de cada interrupción. El objetivo release específicamente modificado, `UniversalConverterModule`, sí compiló completamente.

Por la misma razón no se ejecutó hasta el final `Scripts/verify_project.sh`, porque incluye obligatoriamente esa compilación release global. Sus comprobaciones relacionadas con esta modificación se ejecutaron de forma separada mediante la suite, las pruebas Python, la validación de scripts, el manifiesto y la compilación release del objetivo afectado.

## Validación pendiente en plataforma objetivo

Este entorno es Linux x86_64, no macOS Apple Silicon. Quedan pendientes:

- compilación Xcode ARM64 completa;
- firma y verificación de Hardened Runtime;
- apertura real de la aplicación;
- prueba manual de la interfaz;
- ejecución real de Pandoc incluido en la aplicación;
- comprobación del rechazo visual de ebooks y EPS;
- inspección del paquete `.app` para confirmar la ausencia de Calibre y Ghostscript.

No se afirma que esas validaciones específicas de macOS hayan sido realizadas.

## Validación local adicional — 21 de agosto de 2026

- Suite `YouTubeDownloaderModuleTests`: 69 pruebas superadas, 0 fallos.
- Regresiones nuevas: sesión de navegador explícita, prioridad de `cookies.txt`, ocultamiento de argumentos privados, clasificación de `HTTP 403` y errores de permiso del navegador.
- Compilación Xcode Release ARM64 mediante `Scripts/build_macos.sh Release`: superada.
- Firma local con Hardened Runtime: verificada mediante `codesign --verify --deep --strict`.
- Motores empaquetados `yt-dlp`, Deno, FFmpeg y FFprobe: verificados dentro de `ZEUVE.app`.
- La prueba real con cookies de Brave desde Terminal no se ejecutó porque la protección del entorno bloqueó el acceso externo a credenciales del navegador. La comprobación funcional final debe realizarse desde el control explícito de la interfaz de ZEUVE.
