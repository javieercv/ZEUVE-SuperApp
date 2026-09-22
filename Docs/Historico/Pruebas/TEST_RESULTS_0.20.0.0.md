# Resultados de pruebas — ZEUVE 0.20.0.0

## Entorno disponible

La validación portable histórica se ejecutó en Linux x86_64 con Swift 6.2.1. El 22 de septiembre de 2026 se añade validación de compilación desde Xcode en macOS mediante `BuildProject`. Esta comprobación confirma que la app compila, pero no sustituye la apertura manual ni la QA funcional de Security.framework, Spotlight, Full Disk Access, Papelera real, firma, Hardened Runtime o notarización.

## Resultado automatizado

- `BuildProject` desde Xcode en macOS: **PASS** el 22 de septiembre de 2026 tras corregir errores de compilación Swift 6 en `CleanerModule`, `ZEUVEApp.swift` y `CleanerView.swift`.
- `swift test --disable-sandbox --jobs 1`: **PASS (RC=0)** en esta sesión; se usó `--disable-sandbox` porque el sandbox interno de SwiftPM falla dentro del contenedor de ejecución con `sandbox-exec: Operation not permitted`.
- XCTest/Swift Testing de esta sesión: **PASS**, con **1 test omitido** cuando `ScopedBookmarksAgent` no estuvo disponible para crear un bookmark real de macOS.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: **PASS**, **108 tests**.
- `./Scripts/run_tests.sh`: **PASS (RC=0)** en la validación portable histórica. En esta sesión, el script literal no llegó a ejecutar tests porque `swift test` sin `--disable-sandbox` chocó con el contenedor (`sandbox-exec: Operation not permitted`); se ejecutó la secuencia equivalente descrita arriba.
- `./Scripts/verify_project.sh`: **PASS (RC=0)** en la validación portable histórica; la validación real de `ZEUVE.app` se omite explícitamente fuera de macOS Apple Silicon/Xcode.
- XCTest: **234 tests ejecutados**, 0 fallos, **1 omitido** intencionadamente por requerir macOS/ARM64.
- Swift Testing: **164 tests**, 0 fallos.
- `CleanerModuleTests`: **15/15**, 0 fallos.
- `NavigationPreferencesTests`: **4/4**, 0 fallos.
- Tests Python/estructurales: **108 tests**, 0 fallos, **1 omitido** por requerir Combine/macOS.
- Verificadores de integración de app, estructura, documentación, manifests, módulos, Limpiador y coherencia SwiftPM/Xcode: **PASS**.
- Parseo portable de `Sources/ZEUVEApp`: **79 archivos Swift**, PASS.
- `swift build -c release --target CleanerModule --jobs 1`: **PASS**.
- `swift build -c release --jobs 1`: **PASS (RC=0)**; paquete portable completo compilado en modo optimizado.
- `Scripts/verify_app_macos.sh`: omitido explícitamente por no ejecutarse en macOS Apple Silicon con Xcode.

El build `swift build -c release --jobs 1` del paquete completo terminó correctamente con **RC=0**. `verify_project.sh` terminó correctamente con **RC=0**, validando de forma encadenada tests, Release portable, verificadores, generación Xcode y el skip explícito de `verify_app_macos.sh` fuera de macOS Apple Silicon.

## Cobertura nueva 0.20.0.0

- navegación: codificación/decodificación, `Sin atajo`, normalización de orden, módulos nuevos/eliminados/faltantes/duplicados, conflictos, combinaciones reservadas y restauración;
- Limpiador: manifest/permisos, SQLite schema 3, selección segura, datos persistentes, symlinks, inventario con raíces de test, múltiples copias, volumen externo ausente, App Groups compartidos, `Conservar`, LaunchItems rotos, instaladores antiguos, Xcode sin Archives ni planes solapados, revalidación, resultados parciales, bloqueo de datos asociados si falla la retirada de la app, Papelera/Undo y conflicto de restauración;
- tests del Limpiador no escanean ni limpian ubicaciones reales: usan directorios temporales, providers y raíces inyectables.

## QA pendiente de macOS

El build Xcode de la app ya compila en esta copia. Sigue pendiente confirmar en macOS 14+ Apple Silicon: apertura real de la app, recorder nativo, drag/drop `.app`, NSWorkspace, Security.framework, Spotlight en uso real, Full Disk Access sí/no, rutas protegidas, Papelera real, Undo real, desinstaladores externos, firma/Hardened Runtime y funcionamiento visual completo de SwiftUI/AppKit.
