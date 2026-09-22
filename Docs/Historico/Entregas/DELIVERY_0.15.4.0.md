# Entrega — ZEUVE 0.15.4.0

Fecha: 19 de septiembre de 2026.

## Versiones

- ZEUVE: `0.15.4.0`.
- Build: `55`.
- Inspector multimedia: `0.3.4`.

## Estado de implementación

La corrección mantiene el único reproductor compartido existente y elimina la última decisión duplicada entre los botones de Pistas y Espectrograma.

Ambas vistas consumen ahora la misma resolución de identidad/estado del `MultimediaInspectorViewModel`. Durante una transición gana la fuente solicitada, después la fuente confirmada y solo como respaldo se usa la fuente activa interna. La acción de Espectrograma ya no decide localmente si debe llamar a Pausa o a inicio; el ViewModel resuelve esa semántica igual que en Pistas.

No se ha modificado el servicio de audio. Se mantienen posición, continuidad Play/Pausa, cambio de pista, seek, waveform, barra inferior y layout adaptable de 0.15.3.0.

## QA disponible

- Inspector multimedia: **67 tests**, 0 fallos.
- Target `MultimediaInspectorModuleTests`: compilación PASS.
- Tests Python: **83 tests**, 0 fallos.
- Verificadores directos de integración/versionado/documentación/módulos/manifiestos: PASS.
- ZEUVEApp: 70 fuentes parseadas correctamente.
- SwiftPM/Xcode: 10 productos coherentes.
- `verify_project.sh` global: intentado, pero no completó dentro del límite del entorno; no se marca como PASS.
- Build final macOS y validación manual de AVFoundation/SwiftUI: pendientes porque este entorno no es macOS Apple Silicon con Xcode.

## Límites preservados

Sin cambios en dependencias, motores, red, telemetría, privacidad, permisos, originales, publicación, DSP, edición estructural ni otros módulos.
