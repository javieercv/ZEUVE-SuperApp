# Resultados de pruebas — ZEUVE 0.2.4

Fecha: 2 de julio de 2026.

## Entorno utilizado

- Linux x86_64 con toolchain Swift 6 y Python 3.
- Sin macOS, Xcode, `codesign`, `otool` ni posibilidad de abrir una aplicación `.app`.
- Sin análisis o descargas reales desde YouTube.

## Pruebas Swift

Comando ejecutado con un directorio de compilación externo al proyecto:

```bash
swift test --scratch-path /tmp/zeuve-swift-024 --jobs 2
```

Resultado: **65 pruebas ejecutadas, 65 superadas y 0 fallos**. La compilación Debug de SwiftPM terminó correctamente.

Las pruebas nuevas comprueban:

- creación estable de la caché local de yt-dlp;
- uso de `--cache-dir` en análisis y descarga;
- fallback seguro a `--no-cache-dir` si no puede prepararse la carpeta;
- conservación del diagnóstico en memoria durante la sesión;
- invalidación automática del diagnóstico cuando cambia o desaparece un ejecutable;
- actualización del manifiesto del módulo a 0.2.4.

## Pruebas de scripts

Resultado: **11 pruebas Python ejecutadas, 11 superadas y 0 fallos**. Se verificaron la política de firma, la ruta del nuevo ejecutable descomprimido y el `pkg-config` estático utilizado para FFmpeg.

También se validaron:

- sintaxis de los scripts shell;
- sintaxis de los archivos Swift modificados;
- documentación modular y manifiestos JSON;
- SHA-256 y tamaño del ejecutable raíz de yt-dlp;
- existencia de `Resources/Engines/yt-dlp/_internal`;
- regeneración del proyecto Xcode con versión 0.2.4 y build 10;
- compilación SwiftPM Release terminada correctamente;
- ejecución por separado de todas las validaciones no exclusivas de macOS incluidas en `verify_project.sh`;
- los 109 archivos Mach-O detectados dentro del paquete de yt-dlp son universales `arm64` + `x86_64`.

## Integridad y originales

El ZIP 0.2.3 recibido no se modificó. El trabajo se realizó en una carpeta extraída independiente. Deno, FFmpeg y FFprobe se conservaron; solo se sustituyó yt-dlp por la distribución oficial descomprimida de la misma versión 2026.06.09.

## Pruebas no realizadas

Quedan pendientes en un Mac Apple Silicon:

- `verify_engines_macos.sh`;
- validación real de firmas con `codesign`;
- ejecución de `yt-dlp --version` dentro de `ZEUVE.app`;
- compilación mediante Xcode y apertura de la aplicación;
- comparación de tiempos reales entre la versión 0.2.3 y 0.2.4;
- análisis y descarga real de vídeos y playlists;
- cancelación y limpieza durante una descarga real;
- Gatekeeper y notarización.

Por ello, la mejora está compilada y probada a nivel SwiftPM y scripts, pero su ganancia exacta de rendimiento y el paquete macOS final deben confirmarse en el equipo objetivo.

La integridad de la distribución descomprimida se verifica como un árbol completo mediante `bundleSHA256`, `bundleSize` y `bundleFileCount`, además de la huella individual del ejecutable raíz.
