# Entrega — ZEUVE 0.15.8.0

Fecha: 20 de septiembre de 2026.

## Estado

Mejora implementada y validada en el entorno portable disponible.

- ZEUVE `0.15.8.0`.
- Build `59`.
- Inspector multimedia `0.3.8`.
- Sin dependencias nuevas.
- Sin cambios de red, privacidad, motores ni protección de archivos originales.

## Cambio entregado

Waveform y espectrograma comparten ahora una única ventana temporal. Los controles de zoom, desplazamiento y **Vista completa** actúan sobre el mismo intervalo y conservan el playhead del reproductor compartido. Cuando existe una sesión de preview, el zoom se centra en la posición vigente.

La waveform amplía su envolvente máxima a 65.536 buckets y recorta/reduce en memoria únicamente la región visible. Navegar no vuelve a ejecutar FFmpeg ni conserva PCM completo. Los capítulos válidos del archivo original aparecen como marcadores de solo lectura y muestran título/tiempo al inspeccionarlos.

Se preservan el reproductor y sus correcciones 0.15.2–0.15.6, el análisis automático mono-pista de 0.15.7.0, la edición/remux y todos los controles manuales existentes.

## QA

- Inspector: 73/73 Swift Testing.
- Suite Swift global: 128/128 Swift Testing.
- Scripts: 89/89 tests Python.
- `run_tests.sh`: PASS.
- `verify_project.sh`: PASS, incluida build SwiftPM Release.
- ZEUVEApp: 70 fuentes parseadas.
- Integración SwiftPM/Xcode: 10 productos coherentes.
- Verificadores estructurales/documentales de todos los módulos: PASS.
- Build macOS/Xcode y validación real de la app: pendientes porque este entorno no es macOS Apple Silicon con Xcode.

Ver `Docs/TEST_RESULTS_0.15.8.0.md` para el detalle y la validación manual requerida.
