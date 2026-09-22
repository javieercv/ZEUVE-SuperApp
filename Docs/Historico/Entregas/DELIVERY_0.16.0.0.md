# Entrega — ZEUVE 0.16.0.0

Fecha: 20 de septiembre de 2026.

## Estado

Build directo desde Xcode corregido en la carpeta activa.

- ZEUVE `0.16.0.0`.
- Build `61`.
- Sin dependencias nuevas.
- Sin cambios de red, privacidad, UI, módulos ni comportamiento visible.

## Cambio entregado

Se restauraron permisos ejecutables en scripts y motores incluidos. La fase de firma de motores es ahora resistente a copias incrementales del bundle que conserven un ejecutable sin permiso `+x`: restaura la copia empaquetada desde la fuente o ajusta permisos antes de validar y firmar.

## QA

Ver `Docs/TEST_RESULTS_0.16.0.0.md`. El build Xcode Debug ARM64 termina correctamente. Las suites completas y la validación funcional siguen pendientes de ejecución cuando se prepare una entrega formal.
