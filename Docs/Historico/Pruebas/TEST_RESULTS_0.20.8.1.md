# Resultados de pruebas — ZEUVE 0.20.8.1

11/10/2026 · ZEUVE 0.20.8.1, marketing 0.20.8/build 75 · Descargador 0.7.5 · instaloader-zeuve 4.15.3-zeuve.4 sobre upstream 4.15.3. Base remota `ff89299275d437657437452f4e3c12a4efa5b2ce`.

Las cinco regresiones focalizadas pasan: clasificación de audio a través del servicio, normalización real con FFmpeg/FFprobe preservando bytes/rechazando imagen y conflicto, identidad X entre motores Tumblr limitado al post solicitado y límite de validación de sesión sin activar otro motor. Tests del adaptador Python pasan, incluida la petición con una sola sessionid y exclusión de dominios ajenos.

`run_tests.sh` y `verify_project.sh` pasan: suite completa Swift, 122 tests del Descargador, 121 tests Python al cierre, build SwiftPM Release, verificadores estructurales/documentales y Xcode Debug real. Build Xcode Release y verificación de motores empaquetados/firma completados. Los avisos preexistentes no se presentan como fallos nuevos.

Se detectó antes de abrir la app que Xcode no materializaba la clave personalizada de revisión. Se incorpora `Resources/ZEUVE-Info.plist` como entrada y `build_macos.sh` compara el bundle real con VERSION antes de aceptarlo. La reconstrucción confirma marketing 0.20.8, revisión 1/build 75; una regresión documental protege esa entrada.

La [QA nativa real](DOWNLOADER_QA_0.20.8.1_20261011.md) cierra D-13/D-15/D-21/D-22/D-50 y revalida D-51. Catorce salidas con FFprobe/decodificación íntegra, cero errores; privacidad frente a siete cookies reales/nueve variantes, cero coincidencias. Checklist: 626 OK, 2 fallidas, 6 parciales y 5 pendientes de 639; 634 ejecutadas.

Threads y el catálogo/acceso remoto de Instagram continúan sin aceptación; Reddit online aplazado y destacadas no verificadas. No se certifica descarga privada ni distribución notarizada. Los tests sintéticos no reclasifican estos casos.
