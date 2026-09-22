# Resultados de pruebas — ZEUVE 0.15.1.0

Fecha: 9 de septiembre de 2026.

## Suite automática completa

`./Scripts/run_tests.sh` terminó con exit code 0 sobre el árbol final:

- XCTest: **215 tests**, 0 fallos, **1 omitido** por requisito de macOS Apple Silicon.
- Swift Testing: **117 tests**, 0 fallos.
- Python ScriptTests: **83 tests**, 0 fallos.
- Total contabilizado: **415 tests**, **0 fallos**.

La suite del Inspector contiene **62 tests** y añade una regresión que verifica el cambio exacto de `-map 0:1` a `-map 0:4` conservando el mismo `-ss`.

## Verificadores portables

Ejecutados correctamente de forma independiente sobre el mismo árbol:

- integración de aplicación;
- estructura del proyecto;
- motores;
- documentación/reglas;
- regresiones de rendimiento;
- Conversor universal;
- Descargador universal;
- Analizador de chats;
- Comparador de seguidores de Instagram;
- Inspector multimedia;
- manifiestos;
- sintaxis Bash de scripts críticos;
- `compileall` de Scripts/ScriptTests;
- validación de documentación de módulos;
- parseo de `ZEUVEApp`: **70 archivos Swift**;
- regeneración Xcode;
- coherencia SwiftPM/Xcode: **10 productos**.

El verificador del Inspector exige además la presencia de `previewOperationID`, sincronización de selección de pista, snapshots versionados y seek optimista antes de liberar el estado local de drag.

## Build

`swift build` Debug terminó correctamente en Linux.

`swift build -c release --jobs 4` avanzó repetidamente hasta compilar `MultimediaInspectorModule` y módulos posteriores, pero el entorno cortó el proceso por límite temporal antes de emitir `Build complete!`. No apareció error de compilación antes del corte y por ello el Release portable **no se marca como PASS**.

`./Scripts/build_macos.sh Release` requiere macOS Apple Silicon con Xcode y no puede validarse en este entorno.

## Validación macOS requerida

Comprobar especialmente con el MKV multiaudio real:

- A → B → C entre varias pistas: cada cambio debe alterar el audio realmente escuchado;
- conservar el mismo instante temporal al cambiar;
- pulsar/arrastrar la waveform: el playhead debe saltar inmediatamente sin rebote a la posición anterior;
- cambios rápidos consecutivos: solo la última pista solicitada debe quedar activa;
- pausa/reanudación y stop después de un cambio de pista;
- Espectrograma y Pistas deben reflejar la misma pista seleccionada;
- build Xcode Swift 6/AVFoundation y Hardened Runtime.
