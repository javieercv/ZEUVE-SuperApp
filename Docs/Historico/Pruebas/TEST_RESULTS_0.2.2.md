# Resultados de pruebas — ZEUVE 0.2.2

## Objetivo

Validar la corrección que evita que la firma de macOS invalide en ejecución los motores incluidos por diferencias de tamaño o SHA-256, manteniendo las comprobaciones restantes del diagnóstico.

## Pruebas automáticas ejecutadas

Se ejecutó:

```bash
bash Scripts/run_tests.sh
```

Resultados:

- 60 pruebas Swift superadas sin fallos.
- 8 pruebas Python de `static_pkg_config.py` superadas sin fallos.
- Compilación SwiftPM Debug completada durante la suite.
- La regresión `testMissingEngineIsDetectedAndRuntimeHashMismatchDoesNotBlockDiagnostics` confirmó que un ejecutable cuyo tamaño y hash difieren del manifiesto ya no termina en `hashMismatch`.
- Las pruebas existentes de rutas seguras, manifiestos, ejecución sin shell, cancelación, temporales, publicación, privacidad, playlists, formatos, historial y Organizador continuaron superándose.

## Comprobaciones específicas de la corrección

- `EngineDiagnosticService` ya no lee `descriptor.size` ni calcula el SHA-256 del ejecutable durante el diagnóstico en ejecución.
- Se mantienen las comprobaciones de existencia, licencia, permiso de ejecución, arquitectura, dependencias dinámicas, lanzamiento y versión.
- `Scripts/verify_engines_macos.sh` conserva la comprobación previa de tamaño y SHA-256 durante la preparación y antes del empaquetado.
- El proyecto Xcode se regeneró con ZEUVE 0.2.2 y build 8.
- `Scripts/verify_project.sh` finalizó correctamente.
- Compilación SwiftPM Release superada.
- Sintaxis de shell y Python validada.
- Documentación modular y manifiestos JSON validados.

## Entorno

Las pruebas se ejecutaron en Linux x86_64 con Swift 6.2.1. El ZIP original se conservó sin modificaciones. SHA-256 del original: `95e816d43fa50ed03de72ebabfe8262ec6e3e1a20c1b9dc2a88eabe4d53dfa50`.

## Pruebas no realizadas

Este entorno no permite ejecutar:

- compilación de `ZEUVE.app` mediante Xcode;
- firma real de los motores con `codesign`;
- apertura de la aplicación en macOS Apple Silicon;
- comprobación visual del diálogo de diagnóstico;
- análisis o descarga real de YouTube.

La regresión lógica está cubierta por pruebas automáticas, pero la comprobación final del flujo firmado debe realizarse en un Mac Apple Silicon.
