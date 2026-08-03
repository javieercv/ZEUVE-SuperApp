# Informe de implementación — ZEUVE 0.7.1

## Alcance

Corrección localizada del script `Scripts/prepare_engines_macos.sh` después de reproducirse en un Mac Apple Silicon un error HTTP 404 al obtener la licencia de Calibre 9.11.0.

## Causa

Cuando `Calibre.app` no contenía un archivo de licencia localizable, el script utilizaba como respaldo el archivo `COPYING` del tag oficial. Ese nombre no existe en el tag fijado y detenía la preparación después de descargar y validar LibreOffice, Pandoc y Calibre.

## Solución

- Se utiliza el archivo oficial `LICENSE` del tag `v9.11.0`.
- Se descarga como `downloads/licenses/calibre/LICENSE`.
- Se publica como `Resources/Engines/licenses/calibre/LICENSE` dentro del staging.
- `CALIBRE_LICENSE_REL` registra `licenses/calibre/LICENSE` en el manifiesto generado.
- Se añade una prueba de regresión que prohíbe la antigua URL `COPYING`.

## Archivos afectados

- `Scripts/prepare_engines_macos.sh`
- `Scripts/verify_project.sh`
- `Tests/ScriptTests/test_engine_preparation_policy.py`
- archivos de versión, changelog y documentación de entrega

No se modifica la lógica funcional del Conversor ni el contenido de los motores ya incluidos en el ZIP base.
