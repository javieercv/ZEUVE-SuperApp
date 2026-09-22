# Resultados de pruebas — ZEUVE 0.13.1.0

Fecha: 8 de septiembre de 2026.

## Suite automática

Comando ejecutado desde la raíz del proyecto:

```bash
ZEUVE_SWIFT_JOBS=2 ./Scripts/run_tests.sh
```

Resultado: **PASS, exit code 0**.

- XCTest: **214 ejecutados**, 0 fallos, 1 omitido porque requiere macOS Apple Silicon.
- Swift Testing: **85 tests**, 0 fallos.
- Python ScriptTests: **83 tests**, 0 fallos.
- Total contabilizado: **382 tests**, 0 fallos.

## Cobertura nueva de Fase 1

`MultimediaInspectorModuleTests` alcanza 30 tests y añade regresiones para:

- equivalencia matemática del eje lineal/logarítmico compartido;
- raster distinto y coherente al cambiar de escala;
- mezcla estéreo antífasa sin cancelación artificial;
- límite estricto de `maximumColumns` cuando la duración es conocida;
- conservación de las pruebas previas de tonos, silencio, ventanas, FFT sizes, sample rates, multicanal, bloques incompletos y cancelación real del decoder PCM.

`Tests/ScriptTests/test_versioning_policy.py` añade tres pruebas para:

- `VERSION` con cuatro componentes;
- coherencia entre `MARKETING_VERSION`, `ZEUVEReleaseRevision` y el proyecto Xcode generado;
- conservación de SemVer de tres componentes en manifests de módulos.

## Compilación Release portable

Comando ejecutado:

```bash
swift build -c release --jobs 4
```

Resultado: **PASS, exit code 0**. La compilación final de `MultimediaInspectorModule` también se ejecutó de forma aislada en configuración Release y terminó correctamente.

## Verificación de proyecto

Los verificadores portables que componen `verify_project.sh` se ejecutaron también de forma individual sobre el árbol final y terminaron correctamente:

- integración de aplicación;
- estructura del proyecto;
- engines;
- documentación;
- rendimiento;
- Conversor universal;
- Descargador universal;
- Analizador de chats;
- Comparador de seguidores de Instagram;
- Inspector multimedia;
- manifests;
- parseo sintáctico de **63 archivos Swift** de `ZEUVEApp`;
- coherencia SwiftPM/Xcode de **10 productos**;
- documentación modular;
- sintaxis de scripts shell;
- compilación Python de `Scripts` y `Tests/ScriptTests`.

El orquestador `./Scripts/verify_project.sh` se intentó ejecutar de extremo a extremo. En este entorno web fue interrumpido por el límite externo de duración mientras ya había completado tests, Release y los verificadores de dominio; no produjo un fallo del proyecto. Por ello no se registra como PASS del wrapper. Sus componentes portables sí quedaron ejecutados y validados separadamente.

## Build macOS

Se ejecutó literalmente:

```bash
./Scripts/build_macos.sh Release
```

Resultado en este entorno: **no ejecutable por plataforma** (`exit code 1`), con el mensaje previsto `Esta compilación requiere macOS Apple Silicon con Xcode.`. No se considera un fallo funcional de ZEUVE ni se afirma una build nativa de 0.13.1.0.

## Limitación de plataforma

Estos resultados no sustituyen una build real de `ZEUVE.app`. SwiftUI, AppKit, CoreGraphics/ImageIO y la ruta Accelerate/vDSP ARM64 deben validarse nuevamente en macOS Apple Silicon con Xcode antes de considerar la entrega nativa completamente certificada.
