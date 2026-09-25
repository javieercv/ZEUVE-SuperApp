# Resultados de pruebas — ZEUVE 0.20.5.0

## Evidencia automatizada

- `swift test --filter MultimediaBatchPreflight`: 5/5 PASS. Cubre `.busy`, liberación antes del retorno, resultado `.noChanges`, cancelación global y cancelación de la tarea.
- `swift test --filter CleanerModuleTests`: 34/34 PASS. Incluye warning de historial tras restauración, filas malformadas de inventario/Undo/«Conservar» y las regresiones existentes de Undo parcial, rollback, Papelera, borrado permanente, revalidación y decisiones conservadas.
- `OperationCoordinatorTests`: 2/2 PASS dentro de la suite completa.
- `./Scripts/run_tests.sh`: PASS; suite Swift completa y 112 tests Python.
- Parseo de `ZEUVEApp`: 80 archivos Swift, PASS.
- `./Scripts/verify_project.sh`: PASS; repite suite Swift, build SwiftPM Release, 112 tests Python, verificadores de dominios/documentación/manifests, parseo, coherencia SwiftPM/Xcode y build Xcode Debug.
- `./Scripts/build_macos.sh Debug`: `BUILD SUCCEEDED`; motores empaquetados y firma ad hoc verificados.
- `./Scripts/build_macos.sh Release`: `BUILD SUCCEEDED`; motores empaquetados y firma verificados.
- `./Scripts/verify_app_macos.sh`: PASS con build Xcode Debug arm64 y validación de motores.

## Plataforma y límites

La rama portable de Spotlight queda protegida por el test contractual existente, pero el `#else` no se ejecuta en este host macOS. No se realizó un recorrido manual de UI; esta entrega no afirma validación visual. Las pruebas destructivas usan temporales controlados y no operan sobre archivos reales del usuario.

Los builds Debug y Release son compilaciones reales de `ZEUVE.app`, no solo parseo o SwiftPM. La app no se abrió para un recorrido manual de interfaz, por lo que esa capa permanece expresamente no validada.
