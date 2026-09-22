# Resultados de pruebas — ZEUVE 0.2.1

Fecha: 1 de julio de 2026.

## Entorno disponible

- Sistema: Linux x86_64.
- Swift: 6.2.1.
- Python: disponible para las pruebas de scripts.
- Sin macOS, Xcode, SDK de macOS ni capacidad para generar ejecutables ARM64 de FFmpeg.

## Resultado general

- **60 pruebas Swift ejecutadas y superadas**.
- **8 pruebas Python ejecutadas y superadas**.
- **68 pruebas automáticas superadas en total**.
- Compilación SwiftPM Debug: superada durante `swift test`.
- Compilación SwiftPM Release: superada.
- Sintaxis de scripts shell: superada.
- Compilación sintáctica de scripts Python: superada.
- Regeneración de `ZEUVE.xcodeproj`: superada.
- `Scripts/verify_project.sh`: superado completamente en el entorno disponible.

## Pruebas nuevas de `static_pkg_config.py`

Se comprobaron de forma aislada:

1. respuesta válida a `--version` sin indicar un paquete;
2. comprobación de `--atleast-pkgconfig-version`;
3. requisito agrupado `"opus >= 1.3.1"`;
4. rechazo de una versión mínima no satisfecha;
5. consulta `--variable=includedir opus` sin confundir la opción con un paquete;
6. inclusión de `Libs.private` con `--static --libs`;
7. salida de `--cflags` y `--modversion`;
8. error claro cuando falta un archivo `.pc`.

Todas las pruebas se ejecutaron contra archivos `.pc` temporales controlados y finalizaron sin fallos.

## Comprobaciones de la preparación de motores

Se revisó y validó estáticamente que:

- `BUILD_ROOT` se calcula automáticamente mediante un identificador de la ruta del proyecto;
- la ruta temporal no incorpora el nombre visible ni la versión de la carpeta;
- los ejecutables se escriben primero en un staging externo;
- `Resources/Engines` no se elimina al iniciar la preparación;
- existe verificación previa del staging;
- existe restauración del conjunto anterior si falla la publicación o la verificación final;
- se genera `libmp3lame.pc` antes de configurar FFmpeg;
- se prueban las consultas críticas de `pkg-config` antes de invocar `configure` de FFmpeg.

## Pruebas no realizadas

No se han podido ejecutar en este entorno:

- descarga real de los artefactos fijados;
- compilación de Opus, LAME, FFmpeg y FFprobe para macOS ARM64;
- ejecución de `verify_engines_macos.sh` sobre los binarios finales;
- compilación Debug o Release mediante Xcode;
- firma de los ejecutables anidados;
- apertura de `ZEUVE.app`;
- prueba real del análisis o descarga de YouTube.

Por tanto, el código de preparación está corregido y probado de forma estática y unitaria, pero la validación final del proceso completo debe realizarse en un Mac Apple Silicon.
