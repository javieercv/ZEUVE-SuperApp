# Pruebas y verificación — ZEUVE 0.20.8.3

12/10/2026. Base remota sincronizada `b2c4fa7fc3b5347b6e28bb136ad5ff886865190d`. Marketing 0.20.8/revisión 3/build 77; Descargador 0.7.7; adaptador propio 4.15.3-zeuve.6.

## Pruebas automáticas

`Scripts/run_tests.sh`: **283 XCTest + 203 Swift Testing = 486 pruebas Swift**, todas correctas; **130 pruebas Python**, todas correctas. Descargador: 128 XCTest. Suite de seguimiento: ocho pruebas correctas; helper Instagram: 22.

Tres nuevas regresiones Swift cubren sesión opcional/requerida, mantenimiento de recursos y biografía, muestra parcial y ausencia de otro intento de feed. Cinco nuevas pruebas Python cubren identidad/propietario/canonical/privacidad, respuesta malformada, carruseles con vídeos omitidos, formato/resolución, sesión bloqueada para el endpoint anónimo, paginación finita y recuperación tras feed fallido sin nueva consulta de Reels. Los tests usan datos sintéticos y ejecutables fixture propios; no sustituyen aceptación remota.

`Scripts/verify_project.sh` ejecutado con éxito: pruebas Swift/Python, compilación SwiftPM Release, verificadores de integración/estructura/motores/documentación/módulos/rendimiento, sintaxis shell/Python, 80 fuentes de app, 11 productos SwiftPM/Xcode y compilación real Debug. Verificación final repetida tras el ajuste de composición de UI.

`Scripts/build_macos.sh Release`: build real macOS ARM64, bundle 0.20.8.3/build 77, seis motores requeridos incluidos y firma ad hoc/validación profunda correctas. El helper se reconstruye con el entorno de dependencias ya preparado y se actualizan hash/tamaño/versiones. Upstream Instaloader 4.15.3 y dependencias sin cambios. El payload Python del helper empaquetado coincide con el ejecutable actualizado; SHA-256 del payload `5549d40f2ce30d7117de2e56056c20670439a773ea103aaf099a32275790df75`, con el límite de un intento presente. Sin ZIP, DMG ni notarización/distribución nueva.

## Aceptación nativa

[QA de Release](DOWNLOADER_QA_0.20.8.3_20261012.md): sesión pública plegada/opcional; 24→35 recursos de muestra con IDs únicos, orden y ordinales comprobados; dos JPEG 1080×1440 descargados y decodificados; panel requerido de contenido protegido. Bloqueo de composición detectado, corregido y recorrido repetido con éxito. Datos aislados, sin importar sesión, Llavero ausente y cierre limpio.

D-40 pasa. D-39/D-11 continúan parciales y D-41 pendiente; Reddit D-17 aplazado. Checklist: 639 pruebas, 635 OK, cero fallidas, tres parciales, un pendiente; 638 ejecutadas. No se certifica el catálogo completo ni vídeos/Reels sin URL ni Story activa descargable.
