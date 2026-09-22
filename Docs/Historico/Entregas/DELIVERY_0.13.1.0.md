# Entrega — ZEUVE 0.13.1.0

Fecha: 8 de septiembre de 2026.

## Versiones

- ZEUVE canónica: **0.13.1.0**.
- `MARKETING_VERSION` Apple: **0.13.1**.
- `ZEUVEReleaseRevision`: **0**.
- Build interno: **48**.
- Inspector multimedia: **0.1.1**.

## Alcance

La Fase 1 sanea el espectrograma sin añadir una nueva superficie funcional. Corrige la exportación lineal/logarítmica, reduce movimientos de memoria, acota las columnas con duración conocida, reutiliza el plan FFT, mejora la representación multicanal mediante potencia espectral y trata la cancelación como estado normal.

El resto del Inspector conserva el flujo aprobado: apertura solo lectura, draft explícito, Undo/Redo, stream copy de vídeo/audio, conversiones auxiliares de subtítulos autorizadas, fingerprints, workspace temporal, validación FFprobe y publicación segura de un archivo nuevo.

## Versionado

Desde esta entrega la aplicación usa `MAJOR.MINOR.PATCH.REVISION`. El cuarto componente no se escribe dentro de `MARKETING_VERSION`, porque el bundle de Apple mantiene tres componentes. ZEUVE guarda la revisión en metadata propia y muestra la versión canónica completa. El build interno continúa separado.

Los manifests de módulos no cambian de contrato: siguen usando `MAJOR.MINOR.PATCH`.

## QA

`run_tests.sh` pasa con **382 tests contabilizados y 0 fallos**. `swift build -c release --jobs 4` pasa con exit code 0. Los verificadores portables de integración, estructura, engines, documentación, módulos, manifests, `ZEUVEApp` y coherencia Xcode/SwiftPM pasan individualmente sobre el árbol final.

El wrapper `verify_project.sh` fue interrumpido por el límite externo de duración del entorno web después de completar tests, Release y los verificadores de dominio; no se presenta como PASS del orquestador. Sus gates portables fueron ejecutados y aprobados separadamente.

`./Scripts/build_macos.sh Release` se ejecutó y rechazó correctamente este host por no ser macOS Apple Silicon con Xcode. La validación nativa final debe repetirse en el Mac de desarrollo, especialmente para SwiftUI/AppKit, Accelerate/vDSP, ImageIO, firma y app empaquetada.

Los resultados detallados están en `Docs/TEST_RESULTS_0.13.1.0.md`.

## Dependencias y privacidad

No se añaden dependencias externas, motores, red, APIs, telemetría ni permisos. No cambia la política de archivos originales, temporales, historial o publicación.
