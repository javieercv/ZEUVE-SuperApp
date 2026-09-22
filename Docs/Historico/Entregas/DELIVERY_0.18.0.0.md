# Entrega — ZEUVE 0.18.0.0

Fecha: 21 de septiembre de 2026.

## Estado

Tercer macro-bloque del Inspector multimedia implementado y validado en el entorno portable disponible.

- ZEUVE `0.18.0.0`.
- Build `63`.
- Inspector multimedia `0.6.0`.
- Sin dependencias nuevas.
- Sin red, APIs, telemetría ni motores nuevos.
- Sin edición estructural masiva por lotes.

## Cambio entregado

El Inspector incorpora selección múltiple y modo de lote para inspección, análisis y exportación secuencial. Puede combinar FFprobe, señal, sonoridad, espectrograma PNG e informes por archivo. Los archivos multiaudio mantienen la inspección pero no reciben selección automática de pista.

Se añaden presets de lote persistentes y versionados, administrados desde Ajustes. La misma entrega completa una auditoría de configurabilidad y expone en los Ajustes centralizados los comportamientos razonablemente personalizables del Inspector, manteniendo fuera de la personalización todas las garantías de seguridad y privacidad.

La cola protege todos los originales seleccionados, comprueba fingerprints, rechaza symlinks, conserva resultados ya publicados tras cancelación, continúa tras fallos individuales, libera resultados pesados por elemento y guarda una sola entrada agregada de historial sin nombres ni rutas.

## QA

- Inspector: 99/99 Swift Testing.
- Suite Swift global: 154/154 Swift Testing.
- XCTest portable: 215 tests, 0 fallos, 1 omitido por requisito macOS Apple Silicon.
- Python: 102/102.
- Verificadores de integración, estructura, motores, rendimiento, módulos, manifiestos, documentación, parseo ZEUVEApp y coherencia Xcode: PASS.
- Build Xcode local tras corregir la inicialización de `MultimediaBatchViewModel`: PASS.
- Build SwiftPM Release completa: no finalizada por límite temporal del entorno; no apareció error antes del corte.
- Ejecución real de la app, Hardened Runtime y motores ARM64: pendiente de validación manual.

Ver `Docs/TEST_RESULTS_0.18.0.0.md` para el detalle y la lista de pruebas manuales.
