# Resultados de pruebas — ZEUVE 0.16.0.0

Fecha: 20 de septiembre de 2026.  
Entorno: macOS con Xcode, build Debug ARM64 desde el proyecto `ZEUVE.xcodeproj`.

## PASS

- `BuildProject` de Xcode: PASS.
- El build directo compila y enlaza la aplicación.
- La fase **Firmar motores incluidos** completa tras restaurar permisos ejecutables de scripts y motores.
- La verificación de motores empaquetados ejecutada por `sign_embedded_engines.sh` completa dentro del build Xcode.

## Incidencias corregidas

- `Scripts/sign_embedded_engines.sh`: `Permission denied` al ejecutarse desde Xcode porque los scripts de `Scripts/*.sh` no conservaban permiso de ejecución.
- `yt-dlp/yt-dlp_macos`: fallo de validación en build incremental porque el archivo existía dentro de `ZEUVE.app`, pero no tenía permiso ejecutable y el script abortaba antes de restaurarlo desde la fuente.

## No ejecutado en esta corrección

- `./Scripts/run_tests.sh`.
- `./Scripts/verify_project.sh`.
- `./Scripts/build_macos.sh Release`.
- Pruebas funcionales manuales de módulos.

La validación realizada cubre el problema solicitado de build directo desde Xcode. Las suites completas siguen siendo necesarias antes de una entrega formal.
