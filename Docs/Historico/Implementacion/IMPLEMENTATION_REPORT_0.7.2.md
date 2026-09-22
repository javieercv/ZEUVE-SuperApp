# Informe de implementación — ZEUVE 0.7.2

## Alcance

Corrección localizada de `Scripts/prepare_engines_macos.sh` tras reproducirse en un Mac Apple Silicon un fallo al terminar la compilación estática de x264 r3222.

## Causa

El script ejecutaba `make install-lib-static install-headers`. La revisión fijada de x264 no define un objetivo `install-headers`. El primer objetivo sí terminaba: instalaba `libx264.a`, `x264.h`, `x264_config.h` y `x264.pc`; después GNU Make detenía la preparación al no encontrar la segunda regla.

## Solución

- Se conserva únicamente `make install-lib-static`.
- No se copian cabeceras manualmente: `install-lib-static` depende de `install-lib-dev`, que realiza esa instalación de forma oficial.
- Se añade una prueba Python que exige el objetivo compatible y prohíbe `install-headers`.
- `verify_project.sh` aplica la misma comprobación estática.

## Archivos afectados

- `Scripts/prepare_engines_macos.sh`
- `Scripts/verify_project.sh`
- `Tests/ScriptTests/test_engine_preparation_policy.py`
- archivos de versión, proyecto Xcode, changelog y documentación de 0.7.2

No cambia la lógica funcional del Conversor, sus modelos ni el contenido de los motores ya preparados.
